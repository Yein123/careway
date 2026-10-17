// Scheduled every 5 minutes: lock groups 24h before pickup and settle (spec §5).
import { Firestore } from 'firebase-admin/firestore';
import { ts } from '../db';
import { notifyTx } from '../notify';
import { GroupPackage, groupShareSen } from '../domain/pricing';

function rm(sen: number): string {
  return `RM ${(sen / 100).toFixed(2)}`;
}

/**
 * Each rider ends at the share for the final group size on their own package,
 * capped at what they paid; the difference is refunded.
 */
export async function lockGroupsLogic(db: Firestore, now: Date): Promise<number> {
  const due = await db.collection('groups').where('status', 'in', ['open', 'full']).where('lockAt', '<=', ts(now)).get();
  let locked = 0;
  for (const g of due.docs) {
    await db.runTransaction(async (tx) => {
      const group = (await tx.get(g.ref)).data();
      if (!group || !['open', 'full'].includes(group.status)) return;
      const riderIds: string[] = group.riderBookingIds ?? [];
      const snaps = await Promise.all(riderIds.map((id) => tx.get(db.doc(`bookings/${id}`))));
      const riders = snaps.filter((s) => s.exists && s.data()!.status === 'confirmed');
      const n = riders.length;
      if (n === 0) {
        tx.update(g.ref, { status: 'cancelled', heldSeats: [] });
        return;
      }
      tx.update(g.ref, { status: 'locked', heldSeats: [], lockedAt: ts(now) });
      for (const s of riders) {
        const b = s.data()!;
        const pkg = (b.package ?? 'saver') as GroupPackage;
        const paidShare: number = b.price?.shareSen ?? groupShareSen(pkg, n);
        const finalShare = Math.min(paidShare, groupShareSen(pkg, n));
        const refund = paidShare - finalShare;
        tx.update(s.ref, {
          'price.finalShareSen': finalShare,
          'price.refundSen': (b.price?.refundSen ?? 0) + refund,
        });
        if (refund > 0) {
          tx.set(db.collection('receipts').doc(), {
            uid: b.guardianUid,
            familyId: b.familyId,
            bookingId: s.id,
            deliveryId: null,
            amountSen: refund,
            kind: 'refund',
            label: `Group price drop · ${n} riders`,
            method: b.payment?.method ?? '',
            createdAt: ts(now),
          });
        }
        notifyTx(tx, db, b.guardianUid, {
          type: 'group-locked',
          title: refund > 0 ? `Your group is set: ${rm(refund)} back` : 'Your group is set',
          body: refund > 0
            ? `${n} riders are going, so your price dropped to ${rm(finalShare)}. The difference is on its way back to you.`
            : `${n === 1 ? 'You are riding on your own' : `${n} riders are going`}. Your price stays ${rm(finalShare)}.`,
          link: `/booking/${s.id}`,
        }, now);
      }
      locked++;
    });
  }
  return locked;
}
