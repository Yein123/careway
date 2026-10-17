import { getApps, initializeApp } from 'firebase-admin/app';
import { Firestore, getFirestore, Timestamp } from 'firebase-admin/firestore';

export const PROJECT = 'careway-tehwoq';
export const emulatorOn = !!process.env.FIRESTORE_EMULATOR_HOST;
/** Use for suites that need the Firestore emulator (npm run test:emu). */
export const describeEmu = emulatorOn ? describe : describe.skip;

export function testDb(): Firestore {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT });
  return getFirestore();
}

export async function clearDb(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(`http://${host}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
}

export const NOW = new Date('2026-10-17T08:00:00Z');
export const MIN = 60_000;
export const HOUR = 60 * MIN;
export const APPT = new Date(NOW.getTime() + 9 * 24 * HOUR); // Mon 26 Oct 08:00Z (4 PM local)
export const FAR = new Date('2028-01-01T00:00:00Z');

export const ELMINA = { lat: 3.187, lng: 101.518, label: 'Elmina Lakeside pickup bay' };

const allCerts = ['firstAid', 'patientHandling', 'trainedEscort'];

export async function seedCaregiver(
  db: Firestore,
  uid: string,
  o: { rating?: number; skills?: string[]; certs?: string[]; languages?: string[]; onDuty?: boolean; home?: { lat: number; lng: number } } = {},
): Promise<void> {
  await db.doc(`caregivers/${uid}`).set({
    displayName: uid[0].toUpperCase() + uid.slice(1),
    agency: 'Partner agency',
    zone: 'Elmina',
    phone: '011-0000 0000',
    onDuty: o.onDuty ?? true,
    rating: o.rating ?? 4.8,
    ratingCount: 10,
    languages: o.languages ?? ['Malay', 'English'],
    skills: o.skills ?? ['wheelchair', 'transfer', 'consultSitIn', 'medicineCollection'],
    certificates: (o.certs ?? allCerts).map((type) => ({ type, verified: true, expiresAt: Timestamp.fromDate(FAR) })),
    home: o.home ?? { lat: 3.18, lng: 101.51 },
  });
  await db.doc(`users/${uid}`).set({ name: uid, email: `${uid}@careway.demo`, role: 'caregiver' });
}

/** Guardian g1 in family f1 with patients p1 (72, stick), p2 (80, transfer), p3 (9). */
export async function seedFamily(db: Firestore, guardian = 'g1', fid = 'f1'): Promise<void> {
  await db.doc(`users/${guardian}`).set({ name: 'Aisyah binti Hassan', email: `${guardian}@x.com`, role: 'guardian', familyId: fid, savedPlaces: [] });
  await db.doc(`families/${fid}`).set({ name: 'Ahmad family', adminUid: guardian, memberUids: [guardian], memberNames: { [guardian]: 'Aisyah' } });
  const p = (name: string, age: number, mobility: string) => ({ name, age, mobility, allergy: '', talkNotes: '', contacts: [] });
  await db.doc(`families/${fid}/patients/p1`).set(p('Zainab binti Ahmad', 72, 'stick'));
  await db.doc(`families/${fid}/patients/p2`).set(p('Lim Ah Kow', 80, 'transfer'));
  await db.doc(`families/${fid}/patients/p3`).set(p('Adam bin Imran', 9, 'independent'));
  await db.doc(`families/${fid}/patients/p4`).set(p('Siti Aminah', 70, 'independent'));
}

/** Open Level 1 group with [riders] confirmed placeholder riders and helper [helper]. */
export async function seedGroup(db: Firestore, id: string, riders: number, helper = 'farid', apptAt = APPT): Promise<void> {
  const pickupAt = new Date(apptAt.getTime() - 75 * MIN);
  await db.doc(`groups/${id}`).set({
    hospitalId: 'hsb',
    clinic: 'Orthopaedic specialist clinic',
    date: '2026-10-26',
    pickupPointId: 'elmina-lakeside',
    pickupAt: Timestamp.fromDate(pickupAt),
    apptWindow: '8:45–9:30',
    status: riders >= 3 ? 'full' : 'open',
    lockAt: Timestamp.fromDate(new Date(pickupAt.getTime() - 24 * HOUR)),
    caregiverId: helper,
    caregiverName: 'Farid A.',
    caregiverRating: 4.9,
    riderBookingIds: Array.from({ length: riders }, (_, i) => `${id}-r${i}`),
    riderInitials: ['SL', 'RK', 'NH'].slice(0, riders),
    heldSeats: [],
    capacity: 3,
  });
}

export async function offersFor(db: Firestore, bookingId: string) {
  const q = await db.collection('offers').where('bookingId', '==', bookingId).get();
  return q.docs.map((d) => ({ id: d.id, ...(d.data() as Record<string, unknown>) })) as Array<Record<string, any>>;
}

export async function bookingOf(db: Firestore, id: string) {
  return (await db.doc(`bookings/${id}`).get()).data() as Record<string, any>;
}
