// payDelivery: simulated payment after the helper accepted.
import { Firestore } from 'firebase-admin/firestore';
import { ts } from '../db';
import { fail } from '../errors';
import { notifyTx } from '../notify';
import { assertFamilyMember, METHOD_LABEL, PAYMENT_METHODS } from '../booking/pay';

export async function payDeliveryLogic(db: Firestore, uid: string, raw: unknown, now: Date): Promise<{ status: string; paidSen: number }> {
  const input = raw as { deliveryId?: unknown; method?: unknown };
  if (typeof input?.deliveryId !== 'string' || !PAYMENT_METHODS.includes(input.method as never)) fail('bad-request', 'Choose a payment method.');
  const ref = db.doc(`deliveries/${input.deliveryId}`);
  return db.runTransaction(async (tx) => {
    const d = (await tx.get(ref)).data();
    if (!d) fail('not-payable', 'Delivery not found.');
    await assertFamilyMember(db, tx, uid, d.familyId);
    if (d.payment?.status === 'paid') return { status: d.status, paidSen: d.fee.totalSen };
    if (d.status !== 'awaiting_payment') fail('not-payable', 'This delivery is not waiting for payment.');
    tx.update(ref, {
      status: 'booked',
      payment: { method: input.method, status: 'paid', paidAt: ts(now) },
      steps: [{ key: 'booked', at: ts(now) }],
    });
    tx.set(db.doc(`receipts/pay-del-${ref.id}`), {
      uid,
      familyId: d.familyId,
      bookingId: null,
      deliveryId: ref.id,
      amountSen: d.fee.totalSen,
      kind: 'payment',
      label: `Medicine delivery · ${d.patientName}`,
      method: METHOD_LABEL[input.method as string],
      createdAt: ts(now),
    });
    notifyTx(tx, db, d.caregiverId, {
      type: 'confirmed',
      title: 'Medicine run confirmed',
      body: `Collect documents from ${d.deliverTo} · ${d.window}.`,
      link: '/cg/schedule',
    }, now);
    return { status: 'booked', paidSen: d.fee.totalSen };
  });
}
