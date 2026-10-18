// Demo reset: wipes the data belonging to the demo accounts, then reseeds it for "now".
import { Auth } from 'firebase-admin/auth';
import { Firestore } from 'firebase-admin/firestore';
import { DEMO_ACCOUNTS, DEMO_FAMILY_IDS, seedDemoLogic, SeedResult } from '../seed';

const IN_LIMIT = 30;

async function demoUids(auth: Auth): Promise<string[]> {
  const uids: string[] = [];
  for (const a of Object.values(DEMO_ACCOUNTS)) {
    try {
      uids.push((await auth.getUserByEmail(a.email)).uid);
    } catch {
      // Not created yet: nothing to wipe.
    }
  }
  return uids;
}

export async function resetDemoLogic(db: Firestore, auth: Auth, now: Date): Promise<{ deleted: number; seeded: SeedResult }> {
  const refs: FirebaseFirestore.DocumentReference[] = [];
  const bookingIds: string[] = [];
  const deliveryIds: string[] = [];

  for (const col of ['bookings', 'deliveries', 'receipts']) {
    const snap = await db.collection(col).where('familyId', 'in', DEMO_FAMILY_IDS).get();
    for (const d of snap.docs) {
      refs.push(d.ref);
      if (col === 'bookings') bookingIds.push(d.id);
      if (col === 'deliveries') deliveryIds.push(d.id);
    }
  }

  const offerRefs = new Map<string, FirebaseFirestore.DocumentReference>();
  for (const [field, ids] of [['bookingId', bookingIds], ['deliveryId', deliveryIds]] as const) {
    for (let i = 0; i < ids.length; i += IN_LIMIT) {
      const snap = await db.collection('offers').where(field, 'in', ids.slice(i, i + IN_LIMIT)).get();
      for (const d of snap.docs) offerRefs.set(d.id, d.ref);
    }
  }
  refs.push(...offerRefs.values());

  for (const uid of await demoUids(auth)) {
    refs.push(...(await db.collection(`users/${uid}/notifications`).get()).docs.map((d) => d.ref));
  }
  // `demo-` groups, plus the legacy `seed-` ones from the old seed that the deployed database still holds.
  for (const prefix of ['demo', 'seed']) {
    const groups = await db.collection('groups')
      .where('__name__', '>=', db.doc(`groups/${prefix}-`)).where('__name__', '<', db.doc(`groups/${prefix}.`)).get();
    refs.push(...groups.docs.map((d) => d.ref));
  }

  const writer = db.bulkWriter();
  for (const r of refs) void writer.delete(r);
  await writer.close();

  return { deleted: refs.length, seeded: await seedDemoLogic(db, auth, now) };
}
