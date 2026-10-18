import { getAuth } from 'firebase-admin/auth';
import { Timestamp } from 'firebase-admin/firestore';
import { DEMO_ACCOUNTS, seedDemoLogic } from '../src/seed';
import { resetDemoLogic } from '../src/demo/reset';
import { clearDb, describeEmu, testDb } from './helpers';

const db = testDb();
const NOW = new Date('2026-10-17T02:00:00Z'); // 10:00 MYT
const MIN = 60_000;

async function counts() {
  const out: Record<string, number> = {};
  for (const c of ['bookings', 'deliveries', 'offers', 'receipts', 'groups', 'families', 'caregivers', 'users']) {
    out[c] = (await db.collection(c).get()).size;
  }
  return out;
}

describeEmu('demo seed', () => {
  beforeEach(clearDb);

  test('seed creates the four demo accounts with their patients', async () => {
    const r = await seedDemoLogic(db, getAuth(), NOW);
    for (const a of Object.values(DEMO_ACCOUNTS)) {
      expect((await getAuth().getUserByEmail(a.email)).email).toBe(a.email);
    }
    const self = (await db.doc(`users/${r.uids.self}`).get()).data()!;
    const patients = await db.collection(`families/${self.familyId}/patients`).get();
    expect(patients.size).toBe(1);
    expect(patients.docs[0].data().relationship).toBe('Myself');
    const parent = (await db.doc(`users/${r.uids.parent}`).get()).data()!;
    expect((await db.doc(`families/${parent.familyId}/patients/adam`).get()).data()!.age).toBe(9);
    const user = (await db.doc(`users/${r.uids.user}`).get()).data()!;
    expect((await db.collection(`families/${user.familyId}/patients`).get()).size).toBe(2);
  });

  test("seed creates today's groups with lockAt null and pickups at least 30 min ahead", async () => {
    await seedDemoLogic(db, getAuth(), NOW);
    const today = (await db.collection('groups').where('date', '==', '2026-10-17').get()).docs;
    expect(today.length).toBe(3);
    for (const g of today) {
      expect(g.id.startsWith('demo-2026-10-17-')).toBe(true);
      expect(g.data().lockAt).toBeNull();
      const pickup = (g.data().pickupAt as Timestamp).toDate().getTime();
      expect(pickup - NOW.getTime()).toBeGreaterThanOrEqual(30 * MIN);
    }
    const later = await db.collection('groups').where('date', '==', '2026-10-19').get();
    expect(later.docs[0].data().lockAt).not.toBeNull();
  });

  test('seed creates demo-s3-visit confirmed for caregiver@gmail.com, appt 1h ahead', async () => {
    const r = await seedDemoLogic(db, getAuth(), NOW);
    expect(r.s3BookingId).toBe('demo-s3-visit');
    const b = (await db.doc('bookings/demo-s3-visit').get()).data()!;
    expect(b.status).toBe('confirmed');
    expect(b.level).toBe(2);
    expect(b.caregiverId).toBe(r.uids.caregiver);
    expect(b.guardianUid).toBe(r.uids.user);
    expect((b.apptAt as Timestamp).toDate().getTime()).toBe(NOW.getTime() + 60 * MIN);
    expect(b.payment.status).toBe('paid');
    expect(b.price.paidSen).toBe(12000);
    expect((await db.doc('receipts/pay-demo-s3-visit').get()).exists).toBe(true);
    expect((await db.doc(`families/${b.familyId}/patients/zainab/access/${r.uids.caregiver}`).get()).exists).toBe(true);
    const n = await db.collection(`users/${r.uids.user}/notifications`).get();
    expect(n.docs.some((d) => d.data().title === 'Visit confirmed')).toBe(true);
  });

  test('reset deletes demo bookings, deliveries, offers, receipts, notifications and demo- groups, keeps other docs', async () => {
    const r = await seedDemoLogic(db, getAuth(), NOW);
    const fam = (await db.doc(`users/${r.uids.parent}`).get()).data()!.familyId;
    await db.doc('bookings/demo-b1').set({ familyId: fam, status: 'pending_caregiver' });
    await db.doc('offers/o1').set({ bookingId: 'demo-b1', caregiverId: 'nurul', status: 'offered' });
    await db.doc('deliveries/d1').set({ familyId: fam, status: 'paid' });
    await db.doc('offers/o2').set({ deliveryId: 'd1', caregiverId: 'nurul', status: 'offered' });
    await db.doc('groups/other').set({ date: '2026-10-20' });
    await db.doc('bookings/other').set({ familyId: 'someone-else' });
    await db.doc('offers/o3').set({ bookingId: 'other', status: 'offered' });

    const res = await resetDemoLogic(db, getAuth(), NOW);
    expect(res.deleted).toBeGreaterThan(0);
    expect((await db.doc('bookings/demo-b1').get()).exists).toBe(false);
    expect((await db.doc('offers/o1').get()).exists).toBe(false);
    expect((await db.doc('deliveries/d1').get()).exists).toBe(false);
    expect((await db.doc('offers/o2').get()).exists).toBe(false);
    expect((await db.doc('groups/other').get()).exists).toBe(true);
    expect((await db.doc('bookings/other').get()).exists).toBe(true);
    expect((await db.doc('offers/o3').get()).exists).toBe(true);
    expect((await db.doc('bookings/demo-s3-visit').get()).exists).toBe(true);
    expect(res.seeded.s3BookingId).toBe('demo-s3-visit');
  });

  test('reset is idempotent', async () => {
    await resetDemoLogic(db, getAuth(), NOW);
    const a = await counts();
    await resetDemoLogic(db, getAuth(), NOW);
    expect(await counts()).toEqual(a);
    const user = await getAuth().getUserByEmail(DEMO_ACCOUNTS.user.email);
    expect((await db.collection(`users/${user.uid}/notifications`).get()).size).toBe(1);
  });
});
