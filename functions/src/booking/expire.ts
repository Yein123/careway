// Scheduled every minute: expire offers (cascade on) and unpaid acceptances.
import { Firestore } from 'firebase-admin/firestore';
import { toDate, ts } from '../db';
import { notifyTx } from '../notify';
import { isExpired, offerNext, PAY_TTL_MS, TargetCol, withoutHold } from './offers';

export async function expireOffersLogic(db: Firestore, now: Date): Promise<{ offers: number; unpaid: number }> {
  let offers = 0;
  const open = await db.collection('offers').where('status', '==', 'offered').where('expiresAt', '<=', ts(now)).get();
  for (const d of open.docs) {
    const expired = await db.runTransaction(async (tx) => {
      const o = (await tx.get(d.ref)).data();
      if (!o || o.status !== 'offered' || !isExpired(o.expiresAt, now)) return false;
      tx.update(d.ref, { status: 'expired' });
      return true;
    });
    if (!expired) continue;
    offers++;
    const o = d.data();
    const col: TargetCol = o.deliveryId ? 'deliveries' : 'bookings';
    await offerNext(db, col, o.deliveryId ?? o.bookingId, now, d.id);
  }

  let unpaid = 0;
  const cutoff = ts(new Date(now.getTime() - PAY_TTL_MS));
  for (const col of ['bookings', 'deliveries'] as TargetCol[]) {
    const late = await db.collection(col).where('status', '==', 'awaiting_payment').where('acceptedAt', '<=', cutoff).get();
    for (const d of late.docs) {
      const done = await db.runTransaction(async (tx) => {
        const t = (await tx.get(d.ref)).data();
        const acceptedAt = toDate(t?.acceptedAt);
        if (!t || t.status !== 'awaiting_payment' || !acceptedAt || now.getTime() - acceptedAt.getTime() < PAY_TTL_MS) return false;
        const groupRef = col === 'bookings' && t.groupId ? db.doc(`groups/${t.groupId}`) : null;
        const group = groupRef ? (await tx.get(groupRef)).data() : undefined;
        tx.update(d.ref, { status: 'expired' });
        if (groupRef && group) {
          const update: Record<string, unknown> = { heldSeats: withoutHold(group, d.id) };
          if (t.offerKind === 'groupNew' && (group.riderBookingIds ?? []).length === 0) update.status = 'cancelled';
          tx.update(groupRef, update);
        }
        notifyTx(tx, db, t.guardianUid, {
          type: 'expired',
          title: 'Request expired',
          body: 'It was not paid within 30 minutes, so the caregiver was released. Nothing was charged.',
          link: col === 'deliveries' ? `/delivery/${d.id}` : `/booking/${d.id}`,
        }, now);
        if (t.caregiverId) {
          notifyTx(tx, db, t.caregiverId, {
            type: 'released',
            title: 'Job released',
            body: `${t.patientSnapshot?.name ?? t.patientName ?? 'The patient'}'s family did not confirm in time.`,
            link: '/cg',
          }, now);
        }
        return true;
      });
      if (done) unpaid++;
    }
  }
  return { offers, unpaid };
}
