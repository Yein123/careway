import { getAuth } from 'firebase-admin/auth';
import { requestBookingLogic } from '../src/booking/request';
import { respondToOfferLogic } from '../src/booking/respond';
import { payBookingLogic } from '../src/booking/pay';
import { advanceStepLogic, submitSummaryLogic } from '../src/booking/steps';
import { requestDeliveryLogic } from '../src/delivery/request';
import { advanceDeliveryTx, progressDeliveriesLogic } from '../src/delivery/progress';
import { seedDemoLogic } from '../src/seed';
import { deliveryFee, routeKm } from '../src/domain/pricing';
import { placeById } from '../src/places';
import { APPT, bookingOf, clearDb, describeEmu, ELMINA, HOUR, MIN, NOW, offersFor, seedCaregiver, seedFamily, testDb } from './helpers';

const db = testDb();
const code = (c: string) => expect.objectContaining({ details: expect.objectContaining({ code: c }) });

async function confirmedLevel2(): Promise<string> {
  const r = await requestBookingLogic(
    db,
    'g1',
    { patientId: 'p1', level: 2, pickup: ELMINA, hospitalId: 'hsb', clinic: 'Orthopaedic specialist clinic', apptAt: APPT.toISOString() },
    NOW,
  );
  const [o] = await offersFor(db, r.bookingId);
  await respondToOfferLogic(db, o.caregiverId, { offerId: o.id, accept: true }, NOW);
  await payBookingLogic(db, 'g1', { bookingId: r.bookingId, method: 'fpx' }, NOW);
  return r.bookingId;
}

const summary = { seenBy: 'Dr Lee', diagnosis: 'Knee osteoarthritis, stable', instructions: ['Continue physio twice a week'], nextAppt: '26 Jan 2027' };

describeEmu('visit steps and summary', () => {
  beforeEach(async () => {
    await clearDb();
    await seedFamily(db);
    await seedCaregiver(db, 'nurul');
  });

  test('steps advance in order and the first sets in_progress', async () => {
    const id = await confirmedLevel2();
    const t = new Date(APPT.getTime() - HOUR);
    expect((await advanceStepLogic(db, 'nurul', { bookingId: id }, t)).step).toBe('picked_up');
    let b = await bookingOf(db, id);
    expect(b.status).toBe('in_progress');
    expect((await advanceStepLogic(db, 'nurul', { bookingId: id }, t)).step).toBe('registered');
    b = await bookingOf(db, id);
    expect(b.steps.map((s: any) => s.key)).toEqual(['picked_up', 'registered']);
  });

  test('non-assigned caregiver is denied', async () => {
    const id = await confirmedLevel2();
    await seedCaregiver(db, 'amir');
    await expect(advanceStepLogic(db, 'amir', { bookingId: id }, NOW)).rejects.toEqual(expect.objectContaining({ code: 'permission-denied' }));
  });

  test('final step needs the summary on level 2, then completes', async () => {
    const id = await confirmedLevel2();
    const t0 = new Date(APPT.getTime() - HOUR);
    for (let i = 0; i < 6; i++) await advanceStepLogic(db, 'nurul', { bookingId: id }, t0);
    await expect(advanceStepLogic(db, 'nurul', { bookingId: id }, t0)).rejects.toEqual(code('summary-required'));
    await submitSummaryLogic(db, 'nurul', { bookingId: id, summary }, t0);
    await advanceStepLogic(db, 'nurul', { bookingId: id }, new Date(t0.getTime() + 3 * HOUR));
    const b = await bookingOf(db, id);
    expect(b.status).toBe('completed');
    expect(b.summary.writtenBy).toBe('Nurul');
    expect((await db.doc('families/f1/patients/p1/access/nurul').get()).exists).toBe(false);
  });

  test('a shorter level 2 visit is refunded at completion', async () => {
    const id = await confirmedLevel2();
    const t0 = new Date(APPT.getTime() - HOUR);
    await advanceStepLogic(db, 'nurul', { bookingId: id }, t0);
    for (let i = 0; i < 5; i++) await advanceStepLogic(db, 'nurul', { bookingId: id }, new Date(t0.getTime() + HOUR));
    await submitSummaryLogic(db, 'nurul', { bookingId: id, summary }, t0);
    await advanceStepLogic(db, 'nurul', { bookingId: id }, new Date(t0.getTime() + 3 * HOUR));
    const b = await bookingOf(db, id);
    // 3 hours: 6 × RM 15 + RM 24 ride = RM 114 vs RM 144 paid.
    expect(b.price.refundSen).toBe(3000);
  });

  test('guardian is notified at each step', async () => {
    const id = await confirmedLevel2();
    const before = (await db.collection('users/g1/notifications').get()).size;
    await advanceStepLogic(db, 'nurul', { bookingId: id }, NOW);
    await advanceStepLogic(db, 'nurul', { bookingId: id }, NOW);
    const after = await db.collection('users/g1/notifications').where('type', '==', 'visit-step').get();
    expect(after.size).toBe(2);
    expect((await db.collection('users/g1/notifications').get()).size).toBe(before + 2);
  });
});

describeEmu('medicine delivery', () => {
  beforeEach(async () => {
    await clearDb();
    await seedFamily(db);
    await seedCaregiver(db, 'farid', { certs: ['firstAid'], skills: ['wheelchair', 'medicineCollection'] });
  });

  const delivery = (docs = { card: true, ic: true, letter: true }) => ({
    patientId: 'p1',
    pharmacyId: 'hsb',
    window: '8:00 – 10:00 AM',
    windowStart: APPT.toISOString(),
    method: 'fpx',
    docs,
  });

  test('a missing document blocks the request', async () => {
    await expect(requestDeliveryLogic(db, 'g1', delivery({ card: true, ic: false, letter: true }), NOW)).rejects.toEqual(code('docs-missing'));
  });

  test('fee is the distance formula from home to the pharmacy', async () => {
    const r = await requestDeliveryLogic(db, 'g1', delivery(), NOW);
    const d = (await db.doc(`deliveries/${r.deliveryId}`).get()).data()!;
    const pharm = placeById('hsb')!;
    // No saved place → Elmina Lakeside pickup bay.
    const km = routeKm(3.187, 101.518, pharm.lat, pharm.lng);
    expect(d.routeKm).toBe(km);
    expect(d.fee.totalSen).toBe(deliveryFee(km).totalSen);
    expect(d.status).toBe('booked');
    expect(d.caregiverId).toBe('farid');
    expect(d.payment.status).toBe('paid');
    expect((await db.doc(`receipts/pay-del-${r.deliveryId}`).get()).data()!.amountSen).toBe(deliveryFee(km).totalSen);
  });

  test('no free helper: nothing is created or charged', async () => {
    await db.doc('caregivers/farid').update({ onDuty: false });
    await expect(requestDeliveryLogic(db, 'g1', delivery(), NOW)).rejects.toEqual(code('no-caregiver'));
    expect((await db.collection('deliveries').get()).size).toBe(0);
  });

  test('pay on request, then stages advance one per minute', async () => {
    const r = await requestDeliveryLogic(db, 'g1', delivery(), NOW);
    let d = (await db.doc(`deliveries/${r.deliveryId}`).get()).data()!;
    expect(d.status).toBe('booked');
    await progressDeliveriesLogic(db, new Date(NOW.getTime() + 30_000));
    expect((await db.doc(`deliveries/${r.deliveryId}`).get()).data()!.status).toBe('booked');
    await progressDeliveriesLogic(db, new Date(NOW.getTime() + MIN + 1000));
    d = (await db.doc(`deliveries/${r.deliveryId}`).get()).data()!;
    expect(d.status).toBe('collecting');
  });
});

describeEmu('medicine delivery notifications and forced advance', () => {
  beforeEach(async () => {
    await clearDb();
    await seedFamily(db);
    await seedCaregiver(db, 'farid', { certs: ['firstAid'], skills: ['wheelchair', 'medicineCollection'] });
  });
  const req = () => requestDeliveryLogic(db, 'g1', {
    patientId: 'p1', pharmacyId: 'hsb', window: '8:00 – 10:00 AM', windowStart: APPT.toISOString(), method: 'fpx',
    docs: { card: true, ic: true, letter: true },
  }, NOW);

  test('delivery notifies only at collecting and delivered', async () => {
    const r = await req();
    const before = (await db.collection('users/g1/notifications').where('type', '==', 'delivery-step').get()).size;
    const stages: (string | null)[] = [];
    for (let i = 0; i < 5; i++) stages.push(await advanceDeliveryTx(db, r.deliveryId, new Date(NOW.getTime() + (i + 1) * 1000), { force: true }));
    expect(stages).toEqual(['collecting', 'at_pharmacy', 'collected', 'on_the_way', 'delivered']);
    expect(await advanceDeliveryTx(db, r.deliveryId, NOW, { force: true })).toBeNull();
    const d = (await db.doc(`deliveries/${r.deliveryId}`).get()).data()!;
    expect(d.steps.map((s: { key: string }) => s.key)).toEqual(['booked', 'collecting', 'at_pharmacy', 'collected', 'on_the_way', 'delivered']);
    const notes = await db.collection('users/g1/notifications').where('type', '==', 'delivery-step').get();
    expect(notes.size - before).toBe(2);
    expect(notes.docs.map((n) => n.data().title).sort()).toEqual(
      ['Medicine run: collecting the documents', `${d.patientName}'s medicine was delivered`].sort(),
    );
  });

  test('advanceDeliveryTx without force waits a minute', async () => {
    const r = await req();
    expect(await advanceDeliveryTx(db, r.deliveryId, new Date(NOW.getTime() + 30_000), { force: false })).toBeNull();
    expect(await advanceDeliveryTx(db, r.deliveryId, new Date(NOW.getTime() + MIN + 1000), { force: false })).toBe('collecting');
  });
});

describeEmu('demo seed', () => {
  beforeEach(clearDb);

  test('seed is idempotent', async () => {
    await seedDemoLogic(db, getAuth(), NOW);
    await seedDemoLogic(db, getAuth(), NOW);
    expect((await db.collection('caregivers').get()).size).toBe(4);
    const aisyah = await getAuth().getUserByEmail('user@gmail.com');
    const u = (await db.doc(`users/${aisyah.uid}`).get()).data()!;
    expect(u.role).toBe('guardian');
    expect((await db.collection(`families/${u.familyId}/patients`).get()).size).toBe(2);
    expect((await db.collection('groups').get()).size).toBe(27);
  });
});
