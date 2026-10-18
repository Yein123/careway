// Demo: moves paid deliveries through their stages, about one per minute.
import { Firestore } from 'firebase-admin/firestore';
import { MINUTE, toDate, ts } from '../db';
import { notifyTx } from '../notify';

export const DELIVERY_STAGES = ['booked', 'collecting', 'at_pharmacy', 'collected', 'on_the_way', 'delivered'];
const LABEL: Record<string, string> = {
  collecting: 'collecting the documents',
  at_pharmacy: 'at the pharmacy',
  collected: 'medicine collected',
  on_the_way: 'on the way to you',
  delivered: 'delivered',
};

export async function progressDeliveriesLogic(db: Firestore, now: Date): Promise<number> {
  const active = await db.collection('deliveries').where('status', 'in', DELIVERY_STAGES.slice(0, -1)).get();
  let moved = 0;
  for (const doc of active.docs) {
    await db.runTransaction(async (tx) => {
      const d = (await tx.get(doc.ref)).data();
      if (!d) return;
      const i = DELIVERY_STAGES.indexOf(d.status);
      if (i < 0 || i === DELIVERY_STAGES.length - 1) return;
      const steps = d.steps ?? [];
      const lastAt = toDate(steps[steps.length - 1]?.at) ?? toDate(d.payment?.paidAt);
      if (!lastAt || now.getTime() - lastAt.getTime() < MINUTE) return;
      const next = DELIVERY_STAGES[i + 1];
      tx.update(doc.ref, { status: next, steps: [...steps, { key: next, at: ts(now) }] });
      notifyTx(tx, db, d.guardianUid, {
        type: 'delivery-step',
        title: next === 'delivered' ? `${d.patientName}'s medicine was delivered` : `Medicine run: ${LABEL[next]}`,
        body: next === 'delivered' ? 'Tap to rate the delivery.' : `${d.caregiverName ?? 'Your helper'} · ${d.pharmacyName}`,
        link: next === 'delivered' ? `/delivery/${doc.id}/done` : `/delivery/${doc.id}/live`,
      }, now);
      moved++;
    });
  }
  return moved;
}
