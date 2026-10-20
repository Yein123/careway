import { HttpsError } from 'firebase-functions/v2/https';
import { requestBookingLogic } from '../src/booking/request';
import { requestDeliveryLogic } from '../src/delivery/request';
import { requireAdmin } from '../src/errors';
import {
  adminAdvanceDeliveryLogic,
  adminAdvanceStepLogic,
  adminLockGroupLogic,
  adminNotFoundLogic,
  adminRespondOfferLogic,
  adminSubmitSummaryLogic,
} from '../src/admin/admin';
import { APPT, bookingOf, clearDb, describeEmu, ELMINA, NOW, offersFor, seedCaregiver, seedFamily, seedGroup, testDb } from './helpers';

const db = testDb();
const code = (c: string) => expect.objectContaining({ details: expect.objectContaining({ code: c }) });

describe('requireAdmin', () => {
  test('rejects a missing or false claim', () => {
    expect(() => requireAdmin(undefined)).toThrow(expect.objectContaining({ code: 'unauthenticated' }));
    expect(() => requireAdmin({ uid: 'u' })).toThrow(expect.objectContaining({ code: 'permission-denied' }));
    expect(() => requireAdmin({ uid: 'u', token: { admin: false } })).toThrow(HttpsError);
    expect(requireAdmin({ uid: 'u', token: { admin: true } })).toBe('u');
    expect(requireAdmin({ uid: 'u', token: { email: 'admin@gmail.com' } })).toBe('u');
    expect(() => requireAdmin({ uid: 'u', token: { email: 'user@gmail.com' } })).toThrow(HttpsError);
  });
});

const personal = () =>
  requestBookingLogic(
    db,
    'g1',
    { patientId: 'p1', level: 2, pickup: ELMINA, hospitalId: 'hsb', clinic: 'Orthopaedic specialist clinic', apptAt: APPT.toISOString() },
    NOW,
  );

const notifs = async (uid: string) => (await db.collection(`users/${uid}/notifications`).get()).docs.map((d) => d.data());

describeEmu('admin demo callables', () => {
  beforeEach(async () => {
    await clearDb();
    await seedFamily(db);
    await seedCaregiver(db, 'nurul', { rating: 4.9 });
  });

  test('adminRespondOffer accept makes the booking awaiting_payment and notifies the guardian', async () => {
    const r = await personal();
    const res = await adminRespondOfferLogic(db, { col: 'bookings', id: r.bookingId, accept: true }, NOW);
    expect(res.status).toBe('accepted');
    const b = await bookingOf(db, r.bookingId);
    expect(b.status).toBe('awaiting_payment');
    expect(b.caregiverId).toBe('nurul');
    expect((await notifs('g1')).length).toBeGreaterThan(0);
  });

  test('adminRespondOffer reject cascades to the next caregiver', async () => {
    await seedCaregiver(db, 'amir', { rating: 4.5 });
    const r = await personal();
    const first = (await bookingOf(db, r.bookingId)).currentOfferId;
    await adminRespondOfferLogic(db, { col: 'bookings', id: r.bookingId, accept: false }, NOW);
    const b = await bookingOf(db, r.bookingId);
    expect(b.status).toBe('pending_caregiver');
    expect(b.currentOfferId).toBeTruthy();
    expect(b.currentOfferId).not.toBe(first);
    const offers = await offersFor(db, r.bookingId);
    expect(offers.find((o) => o.id === b.currentOfferId)!.caregiverId).not.toBe(offers.find((o) => o.id === first)!.caregiverId);
  });

  test('adminRespondOffer twice: second call fails no-offer', async () => {
    const r = await personal();
    await adminRespondOfferLogic(db, { col: 'bookings', id: r.bookingId, accept: true }, NOW);
    await expect(adminRespondOfferLogic(db, { col: 'bookings', id: r.bookingId, accept: true }, NOW)).rejects.toEqual(code('no-offer'));
  });

  test('adminNotFound ends as not_matched with the not-matched notification', async () => {
    await seedCaregiver(db, 'amir', { rating: 4.5 });
    const r = await personal();
    const res = await adminNotFoundLogic(db, { col: 'bookings', id: r.bookingId }, NOW);
    expect(res.status).toBe('not_matched');
    const b = await bookingOf(db, r.bookingId);
    expect(b.status).toBe('not_matched');
    expect(b.currentOfferId).toBeNull();
    expect((await notifs('g1')).some((n) => n.type === 'not-matched')).toBe(true);
  });

  test('adminLockGroup locks a lockAt-null group, and a second call fails not-lockable', async () => {
    await seedGroup(db, 'grp', 1);
    await db.doc('groups/grp').update({ lockAt: null });
    await db.doc('bookings/grp-r0').set({ familyId: 'f1', guardianUid: 'g1', status: 'confirmed', groupId: 'grp', package: 'saver', price: { shareSen: 2200 } });
    expect(await adminLockGroupLogic(db, { groupId: 'grp' }, NOW)).toEqual({ locked: true, status: 'locked' });
    await expect(adminLockGroupLogic(db, { groupId: 'grp' }, NOW)).rejects.toEqual(code('not-lockable'));
  });

  test('adminAdvanceDelivery toEnd reaches delivered', async () => {
    await seedCaregiver(db, 'farid', { certs: ['firstAid'], skills: ['wheelchair', 'medicineCollection'] });
    const r = await requestDeliveryLogic(db, 'g1', {
      patientId: 'p1', pharmacyId: 'hsb', window: '8:00 – 10:00 AM', windowStart: APPT.toISOString(), method: 'fpx',
      docs: { card: true, ic: true, letter: true },
    }, NOW);
    const one = await adminAdvanceDeliveryLogic(db, { id: r.deliveryId }, NOW);
    expect(one.stage).toBe('collecting');
    const end = await adminAdvanceDeliveryLogic(db, { id: r.deliveryId, toEnd: true }, NOW);
    expect(end.stage).toBe('delivered');
    expect((await db.doc(`deliveries/${r.deliveryId}`).get()).data()!.status).toBe('delivered');
    await expect(adminAdvanceDeliveryLogic(db, { id: r.deliveryId }, NOW)).rejects.toEqual(code('not-active'));
  });

  test('adminAdvanceStep records picked_up as the assigned caregiver', async () => {
    const r = await personal();
    await adminRespondOfferLogic(db, { col: 'bookings', id: r.bookingId, accept: true }, NOW);
    await db.doc(`bookings/${r.bookingId}`).update({ status: 'confirmed' });
    const res = await adminAdvanceStepLogic(db, { bookingId: r.bookingId }, NOW);
    expect(res.step).toBe('picked_up');
    expect((await bookingOf(db, r.bookingId)).steps[0].key).toBe('picked_up');
  });

  test('adminSubmitSummary writes the summary as the caregiver, letting the visit finish', async () => {
    const r = await personal();
    await adminRespondOfferLogic(db, { col: 'bookings', id: r.bookingId, accept: true }, NOW);
    await db.doc(`bookings/${r.bookingId}`).update({ status: 'confirmed' });
    for (let i = 0; i < 6; i++) await adminAdvanceStepLogic(db, { bookingId: r.bookingId }, NOW);
    await expect(adminAdvanceStepLogic(db, { bookingId: r.bookingId }, NOW)).rejects.toEqual(code('summary-required'));
    const summary = { seenBy: 'Dr Lee', diagnosis: 'Stable', instructions: ['Rest'], nextAppt: '', medicines: '', notes: '' };
    expect(await adminSubmitSummaryLogic(db, { bookingId: r.bookingId, summary }, NOW)).toEqual({ ok: true });
    const res = await adminAdvanceStepLogic(db, { bookingId: r.bookingId }, NOW);
    expect(res.step).toBe('home');
    const b = await bookingOf(db, r.bookingId);
    expect(b.status).toBe('completed');
    expect(b.summary.diagnosis).toBe('Stable');
  });

  test('adminSubmitSummary on an unassigned booking fails not-active', async () => {
    const r = await personal();
    await expect(adminSubmitSummaryLogic(db, { bookingId: r.bookingId, summary: { seenBy: '', diagnosis: 'x' } }, NOW))
      .rejects.toEqual(code('not-active'));
  });
});
