import { Timestamp } from 'firebase-admin/firestore';
import { requestBookingLogic, RequestInput } from '../src/booking/request';
import { respondToOfferLogic } from '../src/booking/respond';
import { expireOffersLogic } from '../src/booking/expire';
import {
  APPT, bookingOf, clearDb, describeEmu, ELMINA, HOUR, MIN, NOW, offersFor, seedCaregiver, seedFamily, seedGroup, testDb,
} from './helpers';

const db = testDb();

const personal = (o: Partial<RequestInput> = {}): RequestInput => ({
  patientId: 'p1',
  level: 2,
  pickup: ELMINA,
  hospitalId: 'hsb',
  clinic: 'Orthopaedic specialist clinic',
  apptAt: APPT.toISOString(),
  ...o,
});

const code = (c: string) => expect.objectContaining({ details: expect.objectContaining({ code: c }) });

describeEmu('booking request and offers', () => {
  beforeEach(async () => {
    await clearDb();
    await seedFamily(db);
    await seedCaregiver(db, 'nurul', { rating: 4.9 });
    await seedCaregiver(db, 'amir', { rating: 4.5 });
  });

  test('personal booking offers to best caregiver', async () => {
    const r = await requestBookingLogic(db, 'g1', personal(), NOW);
    expect(r.status).toBe('pending_caregiver');
    const offers = await offersFor(db, r.bookingId);
    expect(offers).toHaveLength(1);
    expect(offers[0].caregiverId).toBe('nurul');
    expect(offers[0].status).toBe('offered');
    expect((offers[0].expiresAt as Timestamp).toMillis()).toBe(NOW.getTime() + 18 * MIN);
    const b = await bookingOf(db, r.bookingId);
    expect(b.offerCaregiverName).toBe('Nurul');
    expect(b.patientSnapshot.name).toBe('Zainab binti Ahmad');
  });

  test('decline cascades, then not_matched when list exhausted', async () => {
    const r = await requestBookingLogic(db, 'g1', personal(), NOW);
    const [first] = await offersFor(db, r.bookingId);
    await respondToOfferLogic(db, 'nurul', { offerId: first.id, accept: false }, NOW);
    let offers = await offersFor(db, r.bookingId);
    const second = offers.find((o) => o.caregiverId === 'amir')!;
    expect(second.status).toBe('offered');
    await respondToOfferLogic(db, 'amir', { offerId: second.id, accept: false }, NOW);
    const b = await bookingOf(db, r.bookingId);
    expect(b.status).toBe('not_matched');
    expect(b.notMatchedReason).toBe('no-caregiver');
    const notes = await db.collection('users/g1/notifications').get();
    expect(notes.size).toBeGreaterThanOrEqual(1);
    offers = await offersFor(db, r.bookingId);
    expect(offers.map((o) => o.status).sort()).toEqual(['declined', 'declined']);
  });

  test('expiry cascades to the next caregiver', async () => {
    const r = await requestBookingLogic(db, 'g1', personal(), NOW);
    await expireOffersLogic(db, new Date(NOW.getTime() + 19 * MIN));
    const offers = await offersFor(db, r.bookingId);
    expect(offers.find((o) => o.caregiverId === 'nurul')!.status).toBe('expired');
    expect(offers.find((o) => o.caregiverId === 'amir')!.status).toBe('offered');
  });

  test('accept after expiry fails', async () => {
    const r = await requestBookingLogic(db, 'g1', personal(), NOW);
    const [first] = await offersFor(db, r.bookingId);
    await expect(
      respondToOfferLogic(db, 'nurul', { offerId: first.id, accept: true }, new Date(NOW.getTime() + 19 * MIN)),
    ).rejects.toEqual(code('offer-expired'));
    await expireOffersLogic(db, new Date(NOW.getTime() + 19 * MIN));
    await expect(
      respondToOfferLogic(db, 'nurul', { offerId: first.id, accept: true }, new Date(NOW.getTime() + 20 * MIN)),
    ).rejects.toEqual(code('offer-expired'));
  });

  test('accept moves to awaiting_payment', async () => {
    const r = await requestBookingLogic(db, 'g1', personal(), NOW);
    const [first] = await offersFor(db, r.bookingId);
    await respondToOfferLogic(db, 'nurul', { offerId: first.id, accept: true }, NOW);
    const b = await bookingOf(db, r.bookingId);
    expect(b.status).toBe('awaiting_payment');
    expect(b.caregiverId).toBe('nurul');
    expect(b.caregiverName).toBe('Nurul');
    expect((await db.doc('families/f1/patients/p1/access/nurul').get()).exists).toBe(true);
    const notes = await db.collection('users/g1/notifications').get();
    expect(notes.docs.some((d) => String(d.data().title).includes('Nurul'))).toBe(true);
  });

  test('another caregiver cannot answer the offer', async () => {
    const r = await requestBookingLogic(db, 'g1', personal(), NOW);
    const [first] = await offersFor(db, r.bookingId);
    await expect(respondToOfferLogic(db, 'amir', { offerId: first.id, accept: true }, NOW)).rejects.toEqual(
      expect.objectContaining({ code: 'permission-denied' }),
    );
  });

  test('too soon and level 1 not allowed', async () => {
    await expect(
      requestBookingLogic(db, 'g1', personal({ apptAt: new Date(NOW.getTime() + 23 * HOUR).toISOString() }), NOW),
    ).rejects.toEqual(code('too-soon'));
    await seedGroup(db, 'g1grp', 1);
    await expect(requestBookingLogic(db, 'g1', personal({ patientId: 'p2', level: 1, groupId: 'g1grp' }), NOW)).rejects.toEqual(
      code('level1-not-allowed'),
    );
  });

  test('missing patient', async () => {
    await expect(requestBookingLogic(db, 'g1', personal({ patientId: 'nope' }), NOW)).rejects.toEqual(code('no-patient'));
  });

  test('unpaid booking expires after 30 minutes', async () => {
    const r = await requestBookingLogic(db, 'g1', personal(), NOW);
    const [first] = await offersFor(db, r.bookingId);
    await respondToOfferLogic(db, 'nurul', { offerId: first.id, accept: true }, NOW);
    await expireOffersLogic(db, new Date(NOW.getTime() + 31 * MIN));
    expect((await bookingOf(db, r.bookingId)).status).toBe('expired');
    expect((await db.doc('families/f1/patients/p1/access/nurul').get()).exists).toBe(false);
  });
});

describeEmu('level 1 groups', () => {
  beforeEach(async () => {
    await clearDb();
    await seedFamily(db);
    await seedCaregiver(db, 'farid', { rating: 4.9, certs: ['firstAid'], skills: ['wheelchair', 'medicineCollection'] });
    await seedCaregiver(db, 'nurul');
  });

  const join = (patientId: string, groupId: string): RequestInput => ({ ...personal({ patientId, level: 1 }), groupId });

  test('join holds a seat and offers only to the group helper', async () => {
    await seedGroup(db, 'grp', 1);
    const r = await requestBookingLogic(db, 'g1', join('p1', 'grp'), NOW);
    expect(r.status).toBe('pending_caregiver');
    const offers = await offersFor(db, r.bookingId);
    expect(offers.map((o) => [o.caregiverId, o.kind])).toEqual([['farid', 'groupJoin']]);
    const g = (await db.doc('groups/grp').get()).data()!;
    expect(g.heldSeats).toHaveLength(1);
    expect((await bookingOf(db, r.bookingId)).pickup.label).toBe('Elmina Lakeside pickup bay');
  });

  test('helper declines -> not_matched helper-declined, hold released', async () => {
    await seedGroup(db, 'grp', 1);
    const r = await requestBookingLogic(db, 'g1', join('p1', 'grp'), NOW);
    const [o] = await offersFor(db, r.bookingId);
    await respondToOfferLogic(db, 'farid', { offerId: o.id, accept: false }, NOW);
    const b = await bookingOf(db, r.bookingId);
    expect([b.status, b.notMatchedReason]).toEqual(['not_matched', 'helper-declined']);
    expect((await db.doc('groups/grp').get()).data()!.heldSeats).toHaveLength(0);
  });

  test('last seat race: exactly one join wins', async () => {
    await seedGroup(db, 'grp', 2);
    const results = await Promise.allSettled([
      requestBookingLogic(db, 'g1', join('p1', 'grp'), NOW),
      requestBookingLogic(db, 'g1', join('p4', 'grp'), NOW),
    ]);
    const ok = results.filter((r) => r.status === 'fulfilled');
    const bad = results.filter((r) => r.status === 'rejected') as PromiseRejectedResult[];
    expect(ok).toHaveLength(1);
    expect(bad).toHaveLength(1);
    expect(bad[0].reason).toEqual(code('seat-taken'));
  });

  test('full group can be waitlisted without charge', async () => {
    await seedGroup(db, 'grp', 3);
    await expect(requestBookingLogic(db, 'g1', join('p1', 'grp'), NOW)).rejects.toEqual(code('group-full'));
    const r = await requestBookingLogic(db, 'g1', { ...join('p1', 'grp'), waitlist: true }, NOW);
    const b = await bookingOf(db, r.bookingId);
    expect([b.status, b.waitlist]).toEqual(['draft', true]);
    expect(await offersFor(db, r.bookingId)).toHaveLength(0);
  });

  test('new group: offer to a qualified caregiver, accept sets the group helper', async () => {
    const r = await requestBookingLogic(
      db,
      'g1',
      { ...personal({ level: 1 }), newGroup: { pickupPointId: 'elmina-west', pickupTime: new Date(APPT.getTime() - 90 * MIN).toISOString() } },
      NOW,
    );
    const b = await bookingOf(db, r.bookingId);
    expect(b.groupId).toBeTruthy();
    const [o] = await offersFor(db, r.bookingId);
    expect(o.kind).toBe('groupNew');
    await respondToOfferLogic(db, o.caregiverId, { offerId: o.id, accept: true }, NOW);
    const g = (await db.doc(`groups/${b.groupId}`).get()).data()!;
    expect(g.caregiverId).toBe(o.caregiverId);
    expect(g.status).toBe('open');
  });
});
