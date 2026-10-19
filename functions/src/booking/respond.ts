// respondToOffer: a caregiver accepts or declines a job request.
// autoAcceptBooking: a one-to-one escort request is accepted for the offered caregiver after a short wait.
import { Firestore } from 'firebase-admin/firestore';
import { toDate, ts } from '../db';
import { denied, fail } from '../errors';
import { notifyTx } from '../notify';
import { accessRef, isExpired, offerNext, payLink, PAY_TTL_MS, TargetCol } from './offers';

/** How long a one-to-one escort offer waits before it is accepted for the caregiver. */
export const AUTO_ACCEPT_MS = 10_000;

export async function respondToOfferLogic(
  db: Firestore,
  uid: string,
  raw: unknown,
  now: Date,
  opts: { onBehalf?: boolean } = {},
): Promise<{ status: string }> {
  const input = raw as { offerId?: unknown; accept?: unknown };
  if (typeof input?.offerId !== 'string' || typeof input.accept !== 'boolean') fail('bad-request', 'Missing offer.');
  const offerRef = db.doc(`offers/${input.offerId}`);

  const outcome = await db.runTransaction(async (tx) => {
    const offerSnap = await tx.get(offerRef);
    const offer = offerSnap.data();
    if (!offer) fail('offer-expired', 'This request is no longer available.');
    if (offer.caregiverId !== uid) denied('This request was sent to another caregiver.');
    if (offer.status !== 'offered' || isExpired(offer.expiresAt, now)) {
      fail('offer-expired', 'This request expired.');
    }
    const col: TargetCol = offer.deliveryId ? 'deliveries' : 'bookings';
    const targetId: string = offer.deliveryId ?? offer.bookingId;
    const targetRef = db.doc(`${col}/${targetId}`);
    const target = (await tx.get(targetRef)).data();
    const cg = (await tx.get(db.doc(`caregivers/${uid}`))).data();
    const groupRef = col === 'bookings' && target?.groupId ? db.doc(`groups/${target.groupId}`) : null;
    const group = groupRef ? (await tx.get(groupRef)).data() : undefined;

    if (!target || target.status !== 'pending_caregiver' || target.currentOfferId !== offerRef.id) {
      tx.update(offerRef, { status: 'cancelled' });
      return { status: 'cancelled', col, targetId, advance: false };
    }

    if (!input.accept) {
      tx.update(offerRef, { status: 'declined', respondedAt: ts(now) });
      return { status: 'declined', col, targetId, advance: true };
    }

    if (!cg) fail('off-duty', 'Go on duty to accept requests.');
    if (!cg.onDuty && !opts.onBehalf) fail('off-duty', 'Go on duty to accept requests.');
    tx.update(offerRef, { status: 'accepted', respondedAt: ts(now) });
    tx.update(targetRef, {
      status: 'awaiting_payment',
      caregiverId: uid,
      caregiverName: cg.displayName ?? uid,
      caregiverPhone: cg.phone ?? '',
      caregiverVehicle: cg.vehicle ?? null,
      // Guardians can't read caregiver profiles; the package screen needs these to offer add-ons.
      caregiverSkills: cg.skills ?? [],
      caregiverLanguages: cg.languages ?? [],
      acceptedAt: ts(now),
      currentOfferId: null,
      offerExpiresAt: null,
    });
    if (col === 'bookings') {
      tx.set(accessRef(db, target.familyId, target.patientId, uid), { bookingId: targetId, createdAt: ts(now) });
    }
    if (groupRef && group) {
      const payBy = ts(new Date(now.getTime() + PAY_TTL_MS));
      const update: Record<string, unknown> = {};
      if (target.offerKind === 'groupJoin') {
        update.heldSeats = (group.heldSeats ?? []).map((h: any) => (h.bookingId === targetId ? { ...h, until: payBy } : h));
      }
      if (target.offerKind === 'groupNew') {
        update.caregiverId = uid;
        update.caregiverName = cg.displayName ?? uid;
        update.caregiverRating = cg.rating ?? null;
      }
      tx.update(groupRef, update);
    }
    notifyTx(tx, db, target.guardianUid, {
      type: 'accepted',
      title: `${cg.displayName ?? 'Your caregiver'} accepted — pay to confirm`,
      body: 'Pay within 30 minutes to confirm. You are only charged now.',
      link: payLink(col, targetId, target.level),
    }, now);
    // The job request no longer needs an answer.
    notifyTx(tx, db, uid, {
      type: 'accepted',
      title: opts.onBehalf ? 'Job accepted for you' : 'Job accepted',
      body: `${offer.patientName || 'The patient'} · ${offer.placeName ?? ''}. ${opts.onBehalf ? 'CareWay accepted this escort on your behalf. ' : ''}The family pays next.`,
      link: '/cg/schedule',
    }, now, offerRef.id);
    return { status: 'accepted', col, targetId, advance: false };
  });

  if (outcome.advance) await offerNext(db, outcome.col, outcome.targetId, now, offerRef.id);
  return { status: outcome.status };
}

export async function autoAcceptBookingLogic(
  db: Firestore,
  uid: string,
  raw: unknown,
  now: Date,
): Promise<{ status: string }> {
  const input = raw as { bookingId?: unknown };
  if (typeof input?.bookingId !== 'string') fail('bad-request', 'Missing booking.');
  const b = (await db.doc(`bookings/${input.bookingId}`).get()).data();
  if (!b) fail('no-offer', 'Booking not found.');
  const user = (await db.doc(`users/${uid}`).get()).data();
  if (!user || user.familyId !== b.familyId) denied('This booking belongs to another family.');
  if (b.status !== 'pending_caregiver') return { status: b.status };
  if (b.level !== 2 || !b.currentOfferId) fail('no-offer', 'No open offer for this request.');
  const offer = (await db.doc(`offers/${b.currentOfferId}`).get()).data();
  if (!offer || offer.status !== 'offered') fail('no-offer', 'No open offer for this request.');
  const createdAt = toDate(offer.createdAt);
  if (!createdAt || now.getTime() - createdAt.getTime() < AUTO_ACCEPT_MS) fail('too-soon', 'Still waiting for the caregiver.');
  return respondToOfferLogic(db, offer.caregiverId, { offerId: b.currentOfferId, accept: true }, now, { onBehalf: true });
}
