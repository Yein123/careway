import { requestBookingLogic, RequestInput } from '../src/booking/request';
import { respondToOfferLogic } from '../src/booking/respond';
import { payBookingLogic } from '../src/booking/pay';
import { cancelBookingLogic } from '../src/booking/cancel';
import { lockGroupsLogic, lockGroupTx } from '../src/booking/lock';
import { toDate } from '../src/db';
import {
  APPT, bookingOf, clearDb, describeEmu, ELMINA, HOUR, MIN, NOW, offersFor, seedCaregiver, seedFamily, seedGroup, testDb,
} from './helpers';

const db = testDb();
const code = (c: string) => expect.objectContaining({ details: expect.objectContaining({ code: c }) });

const base = (patientId: string, level = 1): RequestInput => ({
  patientId,
  level,
  pickup: ELMINA,
  hospitalId: 'hsb',
  clinic: 'Orthopaedic specialist clinic',
  apptAt: APPT.toISOString(),
});

async function acceptLatest(bookingId: string): Promise<string> {
  const offers = await offersFor(db, bookingId);
  const o = offers.find((x) => x.status === 'offered')!;
  await respondToOfferLogic(db, o.caregiverId, { offerId: o.id, accept: true }, NOW);
  return o.caregiverId;
}

async function joinAndAccept(guardian: string, patientId: string, groupId: string): Promise<string> {
  const r = await requestBookingLogic(db, guardian, { ...base(patientId), groupId }, NOW);
  await acceptLatest(r.bookingId);
  return r.bookingId;
}

async function startGroupAndPay(guardian: string, patientId: string, pkg: 'saver' | 'flex' = 'saver') {
  const r = await requestBookingLogic(
    db,
    guardian,
    { ...base(patientId), newGroup: { pickupPointId: 'elmina-lakeside', pickupTime: new Date(APPT.getTime() - 75 * MIN).toISOString() } },
    NOW,
  );
  await acceptLatest(r.bookingId);
  await payBookingLogic(db, guardian, { bookingId: r.bookingId, method: 'fpx', package: pkg, addons: [] }, NOW);
  return { bookingId: r.bookingId, groupId: (await bookingOf(db, r.bookingId)).groupId as string };
}

async function receiptsFor(bookingId: string) {
  const q = await db.collection('receipts').where('bookingId', '==', bookingId).get();
  return q.docs.map((d) => d.data());
}

describeEmu('payment, cancellation and settlement', () => {
  beforeEach(async () => {
    await clearDb();
    await seedFamily(db, 'g1', 'f1');
    await seedFamily(db, 'g2', 'f2');
    await seedCaregiver(db, 'farid', { rating: 4.9, certs: ['firstAid'], skills: ['wheelchair', 'medicineCollection'] });
  });

  test('pay confirms and joins group', async () => {
    await seedGroup(db, 'grp', 1);
    const id = await joinAndAccept('g1', 'p1', 'grp');
    const r = await payBookingLogic(db, 'g1', { bookingId: id, method: 'fpx', package: 'saver', addons: ['visitSummary'] }, NOW);
    expect(r).toEqual({ status: 'confirmed', paidSen: 3500 });
    const b = await bookingOf(db, id);
    expect(b.status).toBe('confirmed');
    expect(b.price.shareSen).toBe(3000);
    expect(b.price.lines.map((l: any) => l.sen)).toEqual([3000, 500]);
    const g = (await db.doc('groups/grp').get()).data()!;
    expect(g.riderBookingIds).toHaveLength(2);
    expect(g.riderInitials[1]).toBe('ZA');
    expect(g.heldSeats).toHaveLength(0);
  });

  test('payBooking is idempotent', async () => {
    await seedGroup(db, 'grp', 1);
    const id = await joinAndAccept('g1', 'p1', 'grp');
    const input = { bookingId: id, method: 'fpx', package: 'saver', addons: [] };
    await payBookingLogic(db, 'g1', input, NOW);
    const again = await payBookingLogic(db, 'g1', input, NOW);
    expect(again.status).toBe('confirmed');
    expect(await receiptsFor(id)).toHaveLength(1);
    expect((await db.doc('groups/grp').get()).data()!.riderBookingIds).toHaveLength(2);
  });

  test('pay rejected unless awaiting_payment', async () => {
    await seedGroup(db, 'grp', 1);
    const r = await requestBookingLogic(db, 'g1', { ...base('p1'), groupId: 'grp' }, NOW);
    await expect(payBookingLogic(db, 'g1', { bookingId: r.bookingId, method: 'fpx', package: 'saver' }, NOW)).rejects.toEqual(
      code('not-payable'),
    );
  });

  test('another family cannot pay or cancel the booking', async () => {
    await seedGroup(db, 'grp', 1);
    const id = await joinAndAccept('g1', 'p1', 'grp');
    await expect(payBookingLogic(db, 'g2', { bookingId: id, method: 'fpx', package: 'saver' }, NOW)).rejects.toEqual(
      expect.objectContaining({ code: 'permission-denied' }),
    );
    await expect(cancelBookingLogic(db, 'g2', { bookingId: id }, NOW)).rejects.toEqual(
      expect.objectContaining({ code: 'permission-denied' }),
    );
  });

  test('addon outside helper skills rejected', async () => {
    await seedGroup(db, 'grp', 1);
    const id = await joinAndAccept('g1', 'p1', 'grp');
    await expect(
      payBookingLogic(db, 'g1', { bookingId: id, method: 'fpx', package: 'saver', addons: ['language'], language: 'Tamil' }, NOW),
    ).rejects.toEqual(code('addon-unavailable'));
    await expect(
      payBookingLogic(db, 'g1', { bookingId: id, method: 'fpx', package: 'saver', addons: ['consultSitIn'] }, NOW),
    ).rejects.toEqual(code('addon-unavailable'));
  });

  test('level 2 pays the escort estimate', async () => {
    await seedCaregiver(db, 'nurul');
    const r = await requestBookingLogic(db, 'g1', base('p1', 2), NOW);
    await acceptLatest(r.bookingId);
    const paid = await payBookingLogic(db, 'g1', { bookingId: r.bookingId, method: 'tng' }, NOW);
    expect(paid.paidSen).toBe(14400);
  });

  test('lock settles worked example: 40/30/22 -> refunds 18/8/0', async () => {
    const a = await startGroupAndPay('g1', 'p1');
    const bId = await joinAndAccept('g2', 'p1', a.groupId);
    await payBookingLogic(db, 'g2', { bookingId: bId, method: 'fpx', package: 'saver' }, NOW);
    const cId = await joinAndAccept('g1', 'p4', a.groupId);
    await payBookingLogic(db, 'g1', { bookingId: cId, method: 'fpx', package: 'saver' }, NOW);
    expect([(await bookingOf(db, a.bookingId)).price.paidSen, (await bookingOf(db, bId)).price.paidSen, (await bookingOf(db, cId)).price.paidSen]).toEqual([4000, 3000, 2200]);

    const g0 = (await db.doc(`groups/${a.groupId}`).get()).data()!;
    await lockGroupsLogic(db, new Date(toDate(g0.lockAt)!.getTime() + MIN));
    const g = (await db.doc(`groups/${a.groupId}`).get()).data()!;
    expect(g.status).toBe('locked');
    const refunds = await Promise.all([a.bookingId, bId, cId].map(async (id) => (await bookingOf(db, id)).price.refundSen));
    expect(refunds).toEqual([1800, 800, 0]);
    expect((await bookingOf(db, a.bookingId)).price.finalShareSen).toBe(2200);
    expect((await receiptsFor(a.bookingId)).filter((r) => r.kind === 'refund').map((r) => r.amountSen)).toEqual([1800]);
    expect((await receiptsFor(cId)).filter((r) => r.kind === 'refund')).toHaveLength(0);
  });

  test('lockGroupTx locks a same-day group with lockAt null and refunds the price drop', async () => {
    const a = await startGroupAndPay('g1', 'p1');
    const bId = await joinAndAccept('g2', 'p1', a.groupId);
    await payBookingLogic(db, 'g2', { bookingId: bId, method: 'fpx', package: 'saver' }, NOW);
    await db.doc(`groups/${a.groupId}`).update({ lockAt: null });
    expect(await lockGroupTx(db, a.groupId, NOW)).toBe(true);
    expect((await db.doc(`groups/${a.groupId}`).get()).data()!.status).toBe('locked');
    expect((await receiptsFor(a.bookingId)).filter((r) => r.kind === 'refund')).toHaveLength(1);
  });

  test('lockGroupTx on a locked group returns false and writes nothing', async () => {
    const a = await startGroupAndPay('g1', 'p1');
    expect(await lockGroupTx(db, a.groupId, NOW)).toBe(true);
    const receipts = (await db.collection('receipts').get()).size;
    const notes = (await db.collection('users/g1/notifications').get()).size;
    expect(await lockGroupTx(db, a.groupId, NOW)).toBe(false);
    expect((await db.collection('receipts').get()).size).toBe(receipts);
    expect((await db.collection('users/g1/notifications').get()).size).toBe(notes);
  });

  test('lock after cancel: nobody pays more than they paid', async () => {
    const a = await startGroupAndPay('g1', 'p1');
    const bId = await joinAndAccept('g2', 'p1', a.groupId);
    await payBookingLogic(db, 'g2', { bookingId: bId, method: 'fpx', package: 'saver' }, NOW);
    const cId = await joinAndAccept('g1', 'p4', a.groupId);
    await payBookingLogic(db, 'g1', { bookingId: cId, method: 'fpx', package: 'saver' }, NOW);
    const cancel = await cancelBookingLogic(db, 'g1', { bookingId: cId }, NOW);
    expect(cancel).toEqual({ status: 'cancelled', refundSen: 2200, creditSen: 0 });
    expect((await db.doc('families/f1/patients/p4/access/farid').get()).exists).toBe(false);
    expect((await db.doc('families/f1/patients/p1/access/farid').get()).exists).toBe(true);
    const g0 = (await db.doc(`groups/${a.groupId}`).get()).data()!;
    expect(g0.riderBookingIds).toHaveLength(2);
    await lockGroupsLogic(db, new Date(toDate(g0.lockAt)!.getTime() + MIN));
    expect((await bookingOf(db, a.bookingId)).price.refundSen).toBe(1000);
    expect((await bookingOf(db, bId)).price.refundSen).toBe(0);
  });

  test('cancel after lock: saver gives credit, flex refunds 50%', async () => {
    const a = await startGroupAndPay('g1', 'p1', 'saver');
    const bId = await joinAndAccept('g2', 'p1', a.groupId);
    await payBookingLogic(db, 'g2', { bookingId: bId, method: 'fpx', package: 'flex' }, NOW);
    const g0 = (await db.doc(`groups/${a.groupId}`).get()).data()!;
    const afterLock = new Date(toDate(g0.lockAt)!.getTime() + MIN);
    await lockGroupsLogic(db, afterLock);
    // Saver: paid 4000, refunded 1000 at lock → 3000 net becomes credit.
    expect(await cancelBookingLogic(db, 'g1', { bookingId: a.bookingId }, afterLock)).toEqual({ status: 'cancelled', refundSen: 0, creditSen: 3000 });
    // Flex: paid 4500 at 2 riders, final 4500 → 50% back.
    expect(await cancelBookingLogic(db, 'g2', { bookingId: bId }, afterLock)).toEqual({ status: 'cancelled', refundSen: 2250, creditSen: 0 });
  });

  test('cancel frees seat and notifies the waitlist', async () => {
    await seedGroup(db, 'grp', 2);
    const id = await joinAndAccept('g1', 'p1', 'grp');
    await payBookingLogic(db, 'g1', { bookingId: id, method: 'fpx', package: 'saver' }, NOW);
    const w = await requestBookingLogic(db, 'g2', { ...base('p1'), groupId: 'grp', waitlist: true }, NOW);
    expect((await bookingOf(db, w.bookingId)).status).toBe('draft');
    await cancelBookingLogic(db, 'g1', { bookingId: id }, NOW);
    const g = (await db.doc('groups/grp').get()).data()!;
    expect([g.status, g.riderBookingIds.length]).toEqual(['open', 2]);
    const notes = await db.collection('users/g2/notifications').where('type', '==', 'waitlist-seat-open').get();
    expect(notes.size).toBe(1);
  });

  test('cancelling a pending request cancels its open offer', async () => {
    await seedGroup(db, 'grp', 1);
    const r = await requestBookingLogic(db, 'g1', { ...base('p1'), groupId: 'grp' }, NOW);
    expect(await cancelBookingLogic(db, 'g1', { bookingId: r.bookingId }, NOW)).toEqual({ status: 'cancelled', refundSen: 0, creditSen: 0 });
    const [o] = await offersFor(db, r.bookingId);
    expect(o.status).toBe('cancelled');
    expect((await db.doc('groups/grp').get()).data()!.heldSeats).toHaveLength(0);
  });

  test('in-progress visits cannot be cancelled', async () => {
    await seedGroup(db, 'grp', 1);
    const id = await joinAndAccept('g1', 'p1', 'grp');
    await payBookingLogic(db, 'g1', { bookingId: id, method: 'fpx', package: 'saver' }, NOW);
    await db.doc(`bookings/${id}`).update({ status: 'in_progress' });
    await expect(cancelBookingLogic(db, 'g1', { bookingId: id }, new Date(APPT.getTime() - HOUR))).rejects.toEqual(code('not-cancellable'));
  });
});
