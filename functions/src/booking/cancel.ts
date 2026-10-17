// cancelBooking: cancellation and refund rules (spec §5).
import { Firestore } from 'firebase-admin/firestore';
import { HOUR, toDate, ts } from '../db';
import { fail } from '../errors';
import { notify, notifyTx } from '../notify';
import { cancelOutcome, GroupPackage } from '../domain/pricing';
import { assertFamilyMember } from './pay';

const CANCELLABLE = ['draft', 'pending_caregiver', 'awaiting_payment', 'confirmed', 'not_matched'];

export async function cancelBookingLogic(
  db: Firestore,
  uid: string,
  raw: unknown,
  now: Date,
): Promise<{ status: string; refundSen: number; creditSen: number }> {
  const input = raw as { bookingId?: unknown };
  if (typeof input?.bookingId !== 'string') fail('bad-request', 'Missing booking.');
  const ref = db.doc(`bookings/${input.bookingId}`);

  const result = await db.runTransaction(async (tx) => {
    const b = (await tx.get(ref)).data();
    if (!b) fail('not-cancellable', 'Booking not found.');
    await assertFamilyMember(db, tx, uid, b.familyId);
    if (b.status === 'cancelled') return { status: 'cancelled', refundSen: 0, creditSen: 0, freedGroup: null as string | null };
    if (!CANCELLABLE.includes(b.status)) fail('not-cancellable', 'This visit has already started.');

    const groupRef = b.groupId ? db.doc(`groups/${b.groupId}`) : null;
    const group = groupRef ? (await tx.get(groupRef)).data() : undefined;
    const offerRef = b.currentOfferId ? db.doc(`offers/${b.currentOfferId}`) : null;
    const offer = offerRef ? (await tx.get(offerRef)).data() : undefined;

    let refundSen = 0;
    let creditSen = 0;
    if (b.status === 'confirmed') {
      const lockAt = toDate(b.lockAt) ?? new Date(toDate(b.apptAt)!.getTime() - 24 * HOUR);
      const afterLock = (group?.status === 'locked') || now.getTime() >= lockAt.getTime();
      const net = (b.price?.paidSen ?? 0) - (b.price?.refundSen ?? 0);
      const o = cancelOutcome({ pkg: (b.package ?? null) as GroupPackage | null, level: b.level, paidSen: net, afterLock });
      refundSen = o.refundSen;
      creditSen = o.creditSen;
    }

    tx.update(ref, {
      status: 'cancelled',
      cancelledAt: ts(now),
      currentOfferId: null,
      offerExpiresAt: null,
      'price.refundSen': (b.price?.refundSen ?? 0) + refundSen,
      'price.creditSen': (b.price?.creditSen ?? 0) + creditSen,
    });
    if (offerRef && offer?.status === 'offered') tx.update(offerRef, { status: 'cancelled' });

    let freedGroup: string | null = null;
    if (groupRef && group) {
      const riders: string[] = group.riderBookingIds ?? [];
      const idx = riders.indexOf(ref.id);
      const update: Record<string, unknown> = {
        heldSeats: (group.heldSeats ?? []).filter((h: any) => h.bookingId !== ref.id),
      };
      if (idx >= 0) {
        update.riderBookingIds = riders.filter((_, i) => i !== idx);
        update.riderInitials = (group.riderInitials ?? []).filter((_: unknown, i: number) => i !== idx);
      }
      if (group.status === 'full') update.status = 'open';
      if (b.offerKind === 'groupNew' && riders.filter((r) => r !== ref.id).length === 0 && group.status !== 'locked') {
        update.status = 'cancelled';
      } else if (group.status !== 'locked') {
        freedGroup = groupRef.id;
      }
      tx.update(groupRef, update);
    }

    for (const [kind, amount] of [['refund', refundSen], ['credit', creditSen]] as const) {
      if (amount > 0) {
        tx.set(db.collection('receipts').doc(), {
          uid,
          familyId: b.familyId,
          bookingId: ref.id,
          deliveryId: null,
          amountSen: amount,
          kind,
          label: kind === 'refund' ? `Refund · cancelled visit for ${b.patientSnapshot?.name ?? ''}` : `CareWay credit · cancelled visit`,
          method: kind === 'refund' ? (b.payment?.method ?? '') : 'CareWay credit',
          createdAt: ts(now),
        });
      }
    }
    if (b.caregiverId) {
      notifyTx(tx, db, b.caregiverId, {
        type: 'cancelled',
        title: 'Visit cancelled',
        body: `${b.patientSnapshot?.name ?? 'The patient'}'s visit was cancelled by the family.`,
        link: '/cg/schedule',
      }, now);
    }
    return { status: 'cancelled', refundSen, creditSen, freedGroup };
  });

  if (result.freedGroup) {
    const waiting = await db
      .collection('bookings')
      .where('groupId', '==', result.freedGroup)
      .where('waitlist', '==', true)
      .where('status', '==', 'draft')
      .get();
    const first = waiting.docs.sort((a, b) => toDate(a.data().createdAt)!.getTime() - toDate(b.data().createdAt)!.getTime())[0];
    if (first) {
      await notify(db, first.data().guardianUid, {
        type: 'waitlist-seat-open',
        title: 'A seat opened up',
        body: `There's now a seat in the group for ${first.data().patientSnapshot?.name ?? 'your family'}. Request to join before someone else does.`,
        link: `/booking/${first.id}`,
      }, now);
    }
  }
  return { status: result.status, refundSen: result.refundSen, creditSen: result.creditSen };
}
