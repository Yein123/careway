import { Timestamp } from 'firebase-admin/firestore';
import { requestBookingLogic, RequestInput, groupLockAt } from '../src/booking/request';
import { cancelBookingLogic } from '../src/booking/cancel';
import { cancelOutcome } from '../src/domain/pricing';
import { toDate } from '../src/db';
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
    expect(b.caregiverSkills).toEqual(expect.arrayContaining(['consultSitIn', 'transfer']));
    expect(b.caregiverLanguages).toEqual(['Malay', 'English']);
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
      requestBookingLogic(db, 'g1', personal({ apptAt: new Date(NOW.getTime() - HOUR).toISOString() }), NOW),
    ).rejects.toEqual(code('too-soon'));
    await seedGroup(db, 'g1grp', 1);
    await expect(requestBookingLogic(db, 'g1', personal({ patientId: 'p2', level: 1, groupId: 'g1grp' }), NOW)).rejects.toEqual(
      code('level1-not-allowed'),
    );
  });

  test('same-day personal booking 3h ahead is accepted', async () => {
    const r = await requestBookingLogic(db, 'g1', personal({ apptAt: new Date(NOW.getTime() + 3 * HOUR).toISOString() }), NOW);
    expect(r.status).toBe('pending_caregiver');
  });

  test('appointment in the past is rejected too-soon', async () => {
    await expect(
      requestBookingLogic(db, 'g1', personal({ apptAt: new Date(NOW.getTime() - MIN).toISOString() }), NOW),
    ).rejects.toEqual(
      expect.objectContaining({ details: expect.objectContaining({ code: 'too-soon' }), message: 'That time has already passed.' }),
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

describeEmu('same-day groups', () => {
  beforeEach(async () => {
    await clearDb();
    await seedFamily(db);
    await seedCaregiver(db, 'farid', { rating: 4.9, certs: ['firstAid'], skills: ['wheelchair', 'medicineCollection'] });
  });

  const newGroup = (pickupAt: Date, apptAt: Date): RequestInput => ({
    ...personal({ level: 1, apptAt: apptAt.toISOString() }),
    newGroup: { pickupPointId: 'elmina-west', pickupTime: pickupAt.toISOString() },
  });

  test('groupLockAt is pickup - 24h only when that is still ahead', () => {
    const pickup = new Date(NOW.getTime() + 3 * 24 * HOUR);
    expect(groupLockAt(pickup, NOW)).toEqual(new Date(pickup.getTime() - 24 * HOUR));
    expect(groupLockAt(new Date(NOW.getTime() + 2 * HOUR), NOW)).toBeNull();
    expect(groupLockAt(new Date(NOW.getTime() + 24 * HOUR), NOW)).toBeNull();
  });

  test("new same-day group has lockAt null and the founder's hold lasts until pickup", async () => {
    const pickup = new Date(NOW.getTime() + 2 * HOUR);
    const r = await requestBookingLogic(db, 'g1', newGroup(pickup, new Date(NOW.getTime() + 3 * HOUR)), NOW);
    const b = await bookingOf(db, r.bookingId);
    expect(b.lockAt).toBeNull();
    const g = (await db.doc(`groups/${b.groupId}`).get()).data()!;
    expect(g.lockAt).toBeNull();
    expect(toDate(g.heldSeats[0].until)).toEqual(pickup);
  });

  test('group 3 days out keeps lockAt = pickup - 24h', async () => {
    const appt = new Date(NOW.getTime() + 3 * 24 * HOUR);
    const pickup = new Date(appt.getTime() - 90 * MIN);
    const r = await requestBookingLogic(db, 'g1', newGroup(pickup, appt), NOW);
    const b = await bookingOf(db, r.bookingId);
    const expected = new Date(pickup.getTime() - 24 * HOUR);
    expect(toDate(b.lockAt)).toEqual(expected);
    const g = (await db.doc(`groups/${b.groupId}`).get()).data()!;
    expect(toDate(g.lockAt)).toEqual(expected);
    expect(toDate(g.heldSeats[0].until)).toEqual(expected);
  });

  test('new group with pickup in the past is rejected too-soon', async () => {
    await expect(
      requestBookingLogic(db, 'g1', newGroup(new Date(NOW.getTime() - MIN), new Date(NOW.getTime() + 3 * HOUR)), NOW),
    ).rejects.toEqual(code('too-soon'));
  });

  test('joining a group whose pickup has passed is rejected too-soon', async () => {
    await seedGroup(db, 'grp', 1);
    const late = new Date(APPT.getTime() - 75 * MIN + MIN);
    await expect(
      requestBookingLogic(db, 'g1', { ...personal({ patientId: 'p1', level: 1 }), groupId: 'grp' }, late),
    ).rejects.toEqual(code('too-soon'));
  });

  test('cancelling a confirmed same-day group booking before admin lock uses the before-lock outcome', async () => {
    const appt = new Date(NOW.getTime() + 3 * HOUR);
    await db.doc('groups/sd').set({
      status: 'open', lockAt: null, pickupAt: Timestamp.fromDate(new Date(NOW.getTime() + 2 * HOUR)),
      riderBookingIds: ['b1'], riderInitials: ['ZA'], heldSeats: [], capacity: 3, caregiverId: 'farid',
    });
    await db.doc('bookings/b1').set({
      familyId: 'f1', guardianUid: 'g1', patientId: 'p1', patientSnapshot: { name: 'Zainab' },
      status: 'confirmed', level: 1, package: 'saver', groupId: 'sd', lockAt: null, offerKind: 'groupJoin',
      apptAt: Timestamp.fromDate(appt), price: { paidSen: 4000, refundSen: 0, creditSen: 0 },
    });
    const res = await cancelBookingLogic(db, 'g1', { bookingId: 'b1' }, NOW);
    const expected = cancelOutcome({ pkg: 'saver', level: 1, paidSen: 4000, afterLock: false });
    expect(res).toEqual({ status: 'cancelled', refundSen: expected.refundSen, creditSen: expected.creditSen });
  });
});
