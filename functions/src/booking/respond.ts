// respondToOffer: a caregiver accepts or declines a job request.
import { Firestore } from 'firebase-admin/firestore';
import { ts } from '../db';
import { denied, fail } from '../errors';
import { notifyTx } from '../notify';
import { accessRef, isExpired, offerNext, payLink, PAY_TTL_MS, TargetCol } from './offers';

export async function respondToOfferLogic(
  db: Firestore,
  uid: string,
  raw: unknown,
  now: Date,
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

    if (!cg?.onDuty) fail('off-duty', 'Go on duty to accept requests.');
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
    return { status: 'accepted', col, targetId, advance: false };
  });

  if (outcome.advance) await offerNext(db, outcome.col, outcome.targetId, now, offerRef.id);
  return { status: outcome.status };
}
