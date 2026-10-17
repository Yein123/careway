// Demo data (emulator or admin only): a guardian family, 4 caregivers, and
// open Level 1 groups for the next 7 bookable days. Safe to run repeatedly.
import { Auth } from 'firebase-admin/auth';
import { Firestore } from 'firebase-admin/firestore';
import { HOUR, MINUTE, ts } from './db';
import { mytDate, mytTime } from './places';

export const DEMO_PASSWORD = 'careway123';
const CERT_EXPIRY = new Date('2028-01-01T00:00:00Z');
const ELMINA_HOME = { lat: 3.1885, lng: 101.5165 };

async function ensureUser(auth: Auth, email: string, displayName: string): Promise<string> {
  try {
    return (await auth.getUserByEmail(email)).uid;
  } catch {
    return (await auth.createUser({ email, password: DEMO_PASSWORD, displayName })).uid;
  }
}

const cert = (type: string) => ({ type, verified: true, expiresAt: ts(CERT_EXPIRY) });

const CAREGIVERS = [
  {
    email: 'farid@careway.demo', name: 'Farid A.', agency: 'CareWay helpers', rating: 4.9, phone: '012-778 4410',
    languages: ['Malay', 'English'], skills: ['wheelchair', 'medicineCollection'], certs: ['firstAid'],
  },
  {
    email: 'nurul@careway.demo', name: 'Nurul H.', agency: 'Partner agency · trained caregiver', rating: 4.9, phone: '011-2345 8870',
    languages: ['Malay', 'English'], skills: ['wheelchair', 'transfer', 'consultSitIn', 'dementia'], certs: ['firstAid', 'patientHandling', 'trainedEscort'],
  },
  {
    email: 'meiling@careway.demo', name: 'Mei Ling T.', agency: 'Partner agency · paediatric', rating: 4.8, phone: '016-330 2291',
    languages: ['Mandarin', 'Cantonese', 'English'], skills: ['paediatric', 'consultSitIn', 'wheelchair', 'medicineCollection'], certs: ['firstAid', 'paediatric', 'trainedEscort'],
  },
  {
    email: 'ravi@careway.demo', name: 'Ravi S.', agency: 'CareWay helpers', rating: 4.9, phone: '017-551 0923',
    languages: ['Tamil', 'English', 'Malay'], skills: ['wheelchair', 'medicineCollection'], certs: ['firstAid'],
  },
];

/** Pickup point → [local pickup time (h, m), placeholder riders, helper email]. */
const GROUP_PLAN: Array<[string, number, number, string[], string]> = [
  ['elmina-lakeside', 7, 45, ['SL', 'RK'], 'farid@careway.demo'],
  ['elmina-west', 7, 30, ['NH'], 'meiling@careway.demo'],
  ['denai-alam', 8, 0, [], 'ravi@careway.demo'],
];

export async function seedDemoLogic(db: Firestore, auth: Auth, now: Date): Promise<{ guardian: string; caregivers: number; groups: number }> {
  const aisyah = await ensureUser(auth, 'aisyah@careway.demo', 'Aisyah binti Hassan');
  const userRef = db.doc(`users/${aisyah}`);
  const existing = (await userRef.get()).data();
  const familyId = existing?.familyId ?? 'demo-ahmad-family';

  await userRef.set({
    name: 'Aisyah binti Hassan',
    email: 'aisyah@careway.demo',
    phone: '017-882 4410',
    area: 'Elmina, Shah Alam',
    role: 'guardian',
    familyId,
    settings: existing?.settings ?? { language: 'English', textScale: 1, notif: { visitUpdates: true, reminders: true, promos: false } },
    savedPlaces: [{ label: 'Home', address: '12, Jalan Elmina Lakeside', ...ELMINA_HOME }],
    paymentMethods: [{ type: 'fpx', label: 'FPX · Maybank ••••2215' }],
  }, { merge: true });
  await db.doc(`families/${familyId}`).set({
    name: 'Ahmad family',
    adminUid: aisyah,
    memberUids: [aisyah],
    memberNames: { [aisyah]: 'Aisyah (daughter)' },
  }, { merge: true });

  const contacts = [
    { name: 'Zainab', role: 'Patient', phone: '012-345 6789' },
    { name: 'Aisyah (daughter)', role: 'Main guardian', phone: '017-882 4410' },
    { name: 'Imran (son)', role: 'Backup guardian', phone: '019-221 7305' },
  ];
  await db.doc(`families/${familyId}/patients/zainab`).set({
    name: 'Zainab binti Ahmad', age: 72, relationship: 'Parent', phone: '012-345 6789', mobility: 'stick',
    extraHelp: ['Hard of hearing (left)'],
    conditions: 'Type 2 diabetes, high blood pressure, knee osteoarthritis', surgery: 'Cataract, right eye (2023)',
    allergy: 'Penicillin', medicines: 'Metformin, Amlodipine', clinics: 'Orthopaedic, Hospital Sungai Buloh',
    talkNotes: 'Speaks Malay, some English. Hard of hearing in the left ear: face her and speak slowly.',
    contacts, privacy: { helperOnly: true, sendUpdates: true }, updatedAt: ts(now), updatedBy: aisyah,
  }, { merge: true });
  await db.doc(`families/${familyId}/patients/limahkow`).set({
    name: 'Lim Ah Kow', age: 80, relationship: 'Relative', phone: '012-998 1200', mobility: 'wheelchair',
    extraHelp: [], conditions: 'Chronic kidney disease', surgery: '', allergy: 'None known', medicines: 'Erythropoietin',
    clinics: 'Dialysis, Klinik Kesihatan Elmina', talkNotes: 'Speaks Hokkien and Malay.',
    contacts: [{ name: 'Aisyah', role: 'Main guardian', phone: '017-882 4410' }],
    privacy: { helperOnly: true, sendUpdates: true }, updatedAt: ts(now), updatedBy: aisyah,
  }, { merge: true });

  const cgUid: Record<string, string> = {};
  for (const c of CAREGIVERS) {
    const uid = await ensureUser(auth, c.email, c.name);
    cgUid[c.email] = uid;
    await db.doc(`users/${uid}`).set({ name: c.name, email: c.email, phone: c.phone, area: 'Elmina', role: 'caregiver' }, { merge: true });
    const prev = (await db.doc(`caregivers/${uid}`).get()).data();
    await db.doc(`caregivers/${uid}`).set({
      displayName: c.name, agency: c.agency, zone: 'Elmina', phone: c.phone,
      onDuty: prev?.onDuty ?? true, rating: c.rating, ratingCount: prev?.ratingCount ?? 120,
      languages: c.languages, skills: c.skills, certificates: c.certs.map(cert), home: ELMINA_HOME,
    });
  }

  let groups = 0;
  for (let day = 2; day <= 8; day++) {
    // Local midnight of the trip day (UTC+8).
    const localMidnight = new Date(Date.parse(`${mytDate(new Date(now.getTime() + day * 24 * HOUR))}T00:00:00+08:00`));
    for (const [pointId, h, m, riders, helperEmail] of GROUP_PLAN) {
      const id = `seed-${mytDate(localMidnight)}-${pointId}`;
      const ref = db.doc(`groups/${id}`);
      groups++;
      if ((await ref.get()).exists) continue;
      const pickupAt = new Date(localMidnight.getTime() + (h * 60 + m) * MINUTE);
      const apptStart = new Date(pickupAt.getTime() + 60 * MINUTE);
      const helper = CAREGIVERS.find((c) => c.email === helperEmail)!;
      await ref.set({
        hospitalId: 'hsb',
        clinic: 'Orthopaedic specialist clinic',
        date: mytDate(localMidnight),
        pickupPointId: pointId,
        pickupAt: ts(pickupAt),
        apptWindow: `${mytTime(apptStart)}–${mytTime(new Date(apptStart.getTime() + 45 * MINUTE))}`,
        status: 'open',
        lockAt: ts(new Date(pickupAt.getTime() - 24 * HOUR)),
        caregiverId: cgUid[helperEmail],
        caregiverName: helper.name,
        caregiverRating: helper.rating,
        riderBookingIds: riders.map((_, i) => `${id}-r${i}`),
        riderInitials: riders,
        heldSeats: [],
        capacity: 3,
        createdAt: ts(now),
      });
    }
  }
  return { guardian: aisyah, caregivers: CAREGIVERS.length, groups };
}
