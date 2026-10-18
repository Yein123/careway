// Demo data (emulator or admin only): four demo accounts (parent, user, self,
// caregiver), three more caregivers, open Level 1 groups for today and the next
// week, and the scenario 3 visit. Safe to run repeatedly.
import { Auth } from 'firebase-admin/auth';
import { Firestore } from 'firebase-admin/firestore';
import { HOUR, MINUTE, ts } from './db';
import { accessRef } from './booking/offers';
import { groupLockAt } from './booking/request';
import { DEFAULT_ESCORT_HOURS, ESCORT_HOURLY_SEN } from './domain/pricing';
import { mytDate, mytTime } from './places';

export const DEMO_PASSWORD = 'careway123';
const CERT_EXPIRY = new Date('2028-01-01T00:00:00Z');
const ELMINA_HOME = { lat: 3.1885, lng: 101.5165 };

export type DemoRole = 'parent' | 'user' | 'self' | 'caregiver';
export const DEMO_ACCOUNTS: Record<DemoRole, { email: string; name: string }> = {
  parent: { email: 'parent@gmail.com', name: 'Siti binti Yusof' },
  user: { email: 'user@gmail.com', name: 'Aisyah binti Hassan' },
  self: { email: 'self@gmail.com', name: 'Hafiz bin Osman' },
  caregiver: { email: 'caregiver@gmail.com', name: 'Ravi S.' },
};
export const DEMO_FAMILY_IDS = ['demo-parent-family', 'demo-user-family', 'demo-self-family'];
export const S3_BOOKING_ID = 'demo-s3-visit';
export type SeedResult = { uids: Record<string, string>; groups: number; s3BookingId: string };

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
    vehicle: { model: 'White Toyota Hiace', plate: 'WXY 2841', driver: 'Kumar' },
  },
  {
    email: 'nurul@careway.demo', name: 'Nurul H.', agency: 'Partner agency · trained caregiver', rating: 4.9, phone: '011-2345 8870',
    languages: ['Malay', 'English'], skills: ['wheelchair', 'transfer', 'consultSitIn', 'dementia'], certs: ['firstAid', 'patientHandling', 'trainedEscort'],
    vehicle: { model: 'Silver Perodua Alza', plate: 'VDK 5532', driver: '' },
  },
  {
    email: 'meiling@careway.demo', name: 'Mei Ling T.', agency: 'Partner agency · paediatric', rating: 4.8, phone: '016-330 2291',
    languages: ['Mandarin', 'Cantonese', 'English'], skills: ['paediatric', 'consultSitIn', 'wheelchair', 'medicineCollection'], certs: ['firstAid', 'paediatric', 'trainedEscort'],
    vehicle: { model: 'Blue Proton Exora', plate: 'BLM 7120', driver: '' },
  },
  {
    email: DEMO_ACCOUNTS.caregiver.email, name: 'Ravi S.', agency: 'CareWay helpers', rating: 4.9, phone: '017-551 0923',
    languages: ['Tamil', 'English', 'Malay'], skills: ['wheelchair', 'transfer', 'consultSitIn', 'medicineCollection'],
    certs: ['firstAid', 'patientHandling', 'trainedEscort'],
    vehicle: { model: 'White Nissan Urvan', plate: 'WTA 6195', driver: 'Kumar' },
  },
];

/** Pickup point → [local pickup time (h, m), placeholder riders, helper email]. */
const GROUP_PLAN: Array<[string, number, number, string[], string]> = [
  ['elmina-lakeside', 7, 45, ['SL', 'RK'], 'farid@careway.demo'],
  ['elmina-west', 7, 30, ['NH'], 'meiling@careway.demo'],
  ['denai-alam', 8, 0, [], DEMO_ACCOUNTS.caregiver.email],
];

const SETTINGS = { language: 'English', textScale: 1, notif: { visitUpdates: true, reminders: true, promos: false } };

async function seedGuardian(
  db: Firestore, auth: Auth, role: DemoRole,
  o: { familyId: string; familyName: string; memberName: string; phone: string },
): Promise<string> {
  const acct = DEMO_ACCOUNTS[role];
  const uid = await ensureUser(auth, acct.email, acct.name);
  const userRef = db.doc(`users/${uid}`);
  const existing = (await userRef.get()).data();
  await userRef.set({
    name: acct.name,
    email: acct.email,
    phone: o.phone,
    area: 'Elmina, Shah Alam',
    role: 'guardian',
    familyId: o.familyId,
    settings: existing?.settings ?? SETTINGS,
    savedPlaces: [{ label: 'Home', address: '12, Jalan Elmina Lakeside', ...ELMINA_HOME }],
    paymentMethods: [{ type: 'fpx', label: 'FPX · Maybank ••••2215' }],
  }, { merge: true });
  await db.doc(`families/${o.familyId}`).set({
    name: o.familyName, adminUid: uid, memberUids: [uid], memberNames: { [uid]: o.memberName },
  }, { merge: true });
  return uid;
}

/** Next :00/:30 (MYT is a whole-hour offset) at least 30 minutes after now. */
function nextHalfHour(now: Date): Date {
  const step = 30 * MINUTE;
  return new Date(Math.ceil((now.getTime() + 30 * MINUTE) / step) * step);
}

export async function seedDemoLogic(db: Firestore, auth: Auth, now: Date): Promise<SeedResult> {
  const user = await seedGuardian(db, auth, 'user', {
    familyId: 'demo-user-family', familyName: 'Ahmad family', memberName: 'Aisyah (daughter)', phone: '017-882 4410',
  });
  const parent = await seedGuardian(db, auth, 'parent', {
    familyId: 'demo-parent-family', familyName: 'Yusof family', memberName: 'Siti (mother)', phone: '013-884 2201',
  });
  const self = await seedGuardian(db, auth, 'self', {
    familyId: 'demo-self-family', familyName: 'Hafiz', memberName: 'Hafiz', phone: '014-770 3318',
  });

  const contacts = [
    { name: 'Zainab', role: 'Patient', phone: '012-345 6789' },
    { name: 'Aisyah (daughter)', role: 'Main guardian', phone: '017-882 4410' },
    { name: 'Imran (son)', role: 'Backup guardian', phone: '019-221 7305' },
  ];
  await db.doc('families/demo-user-family/patients/zainab').set({
    name: 'Zainab binti Ahmad', age: 72, relationship: 'Parent', phone: '012-345 6789', mobility: 'stick',
    extraHelp: ['Hard of hearing (left)'],
    conditions: 'Type 2 diabetes, high blood pressure, knee osteoarthritis', surgery: 'Cataract, right eye (2023)',
    allergy: 'Penicillin', medicines: 'Metformin, Amlodipine', clinics: 'Orthopaedic, Hospital Sungai Buloh',
    talkNotes: 'Speaks Malay, some English. Hard of hearing in the left ear: face her and speak slowly.',
    contacts, privacy: { helperOnly: true, sendUpdates: true }, updatedAt: ts(now), updatedBy: user,
  }, { merge: true });
  await db.doc('families/demo-user-family/patients/limahkow').set({
    name: 'Lim Ah Kow', age: 80, relationship: 'Relative', phone: '012-998 1200', mobility: 'wheelchair',
    extraHelp: [], conditions: 'Chronic kidney disease', surgery: '', allergy: 'None known', medicines: 'Erythropoietin',
    clinics: 'Dialysis, Klinik Kesihatan Elmina', talkNotes: 'Speaks Hokkien and Malay.',
    contacts: [{ name: 'Aisyah', role: 'Main guardian', phone: '017-882 4410' }],
    privacy: { helperOnly: true, sendUpdates: true }, updatedAt: ts(now), updatedBy: user,
  }, { merge: true });
  await db.doc('families/demo-parent-family/patients/adam').set({
    name: 'Adam bin Yusof', age: 9, relationship: 'Child', phone: '', mobility: 'independent',
    extraHelp: [], conditions: 'Asthma', surgery: '', allergy: 'None known', medicines: 'Ventolin inhaler',
    clinics: 'Paediatric, Hospital Sungai Buloh', talkNotes: 'Shy with strangers. Likes dinosaurs.',
    contacts: [
      { name: 'Adam', role: 'Patient', phone: '' },
      { name: 'Siti (mother)', role: 'Main guardian', phone: '013-884 2201' },
    ],
    privacy: { helperOnly: true, sendUpdates: true }, updatedAt: ts(now), updatedBy: parent,
  }, { merge: true });
  await db.doc('families/demo-self-family/patients/hafiz').set({
    name: 'Hafiz bin Osman', age: 58, relationship: 'Myself', phone: '014-770 3318', mobility: 'independent',
    extraHelp: [], conditions: 'High blood pressure', surgery: '', allergy: 'None known', medicines: 'Amlodipine',
    clinics: 'Cardiology, Hospital Sungai Buloh', talkNotes: '',
    contacts: [{ name: 'Hafiz', role: 'Patient' }],
    privacy: { helperOnly: true, sendUpdates: true }, updatedAt: ts(now), updatedBy: self,
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
      languages: c.languages, skills: c.skills, certificates: c.certs.map(cert), home: ELMINA_HOME, vehicle: c.vehicle,
    });
  }

  let groups = 0;
  const todayMidnight = new Date(Date.parse(`${mytDate(now)}T00:00:00+08:00`));
  const cutoff = new Date(todayMidnight.getTime() + 21 * HOUR);
  const firstToday = nextHalfHour(now);
  // Today, then the next eight days.
  for (let day = 0; day <= 8; day++) {
    // Local midnight of the trip day (UTC+8).
    const localMidnight = new Date(Date.parse(`${mytDate(new Date(now.getTime() + day * 24 * HOUR))}T00:00:00+08:00`));
    for (const [i, [pointId, h, m, riders, helperEmail]] of GROUP_PLAN.entries()) {
      const pickupAt = day === 0
        ? new Date(firstToday.getTime() + i * 30 * MINUTE)
        : new Date(localMidnight.getTime() + (h * 60 + m) * MINUTE);
      if (day === 0 && pickupAt.getTime() > cutoff.getTime()) continue;
      const date = mytDate(localMidnight);
      const id = `demo-${date}-${pointId}`;
      const ref = db.doc(`groups/${id}`);
      groups++;
      if ((await ref.get()).exists) continue;
      const apptStart = new Date(pickupAt.getTime() + 60 * MINUTE);
      const helper = CAREGIVERS.find((c) => c.email === helperEmail)!;
      const lockAt = groupLockAt(pickupAt, now);
      await ref.set({
        hospitalId: 'hsb',
        clinic: 'Orthopaedic specialist clinic',
        date,
        pickupPointId: pointId,
        pickupAt: ts(pickupAt),
        apptWindow: `${mytTime(apptStart)}–${mytTime(new Date(apptStart.getTime() + 45 * MINUTE))}`,
        status: 'open',
        lockAt: lockAt ? ts(lockAt) : null,
        caregiverId: cgUid[helperEmail],
        caregiverName: helper.name,
        caregiverRating: helper.rating,
        riderBookingIds: riders.map((_, r) => `${id}-r${r}`),
        riderInitials: riders,
        heldSeats: [],
        capacity: 3,
        createdAt: ts(now),
      });
    }
  }

  // Scenario 3: a paid, confirmed Level 2 visit for Zainab with caregiver@gmail.com, about an hour away.
  const cgId = cgUid[DEMO_ACCOUNTS.caregiver.email];
  const cg = CAREGIVERS.find((c) => c.email === DEMO_ACCOUNTS.caregiver.email)!;
  const apptAt = new Date(now.getTime() + 60 * MINUTE);
  const paidSen = ESCORT_HOURLY_SEN * DEFAULT_ESCORT_HOURS;
  await db.doc(`bookings/${S3_BOOKING_ID}`).set({
    familyId: 'demo-user-family',
    guardianUid: user,
    guardianName: DEMO_ACCOUNTS.user.name,
    patientId: 'zainab',
    patientSnapshot: {
      name: 'Zainab binti Ahmad', age: 72, mobility: 'stick', allergy: 'Penicillin',
      talkNotes: 'Speaks Malay, some English. Hard of hearing in the left ear: face her and speak slowly.',
    },
    level: 2,
    hospitalId: 'hsb',
    clinic: 'Orthopaedic specialist clinic',
    placeName: 'Hospital Sungai Buloh · Orthopaedic specialist clinic',
    apptAt: ts(apptAt),
    language: null,
    addons: [],
    package: null,
    requiredSkills: [],
    requiredCerts: [],
    needs: [],
    steps: [],
    waitlist: false,
    pickup: { label: '12, Jalan Elmina Lakeside', ...ELMINA_HOME },
    pickupAt: null,
    groupId: null,
    lockAt: null,
    offerKind: 'personal',
    estimateSen: paidSen,
    windowStart: ts(new Date(apptAt.getTime() - HOUR)),
    windowEnd: ts(new Date(apptAt.getTime() + 4 * HOUR)),
    rankedUids: [cgId],
    offeredUids: [cgId],
    currentOfferId: null,
    offerExpiresAt: null,
    status: 'confirmed',
    caregiverId: cgId,
    caregiverName: cg.name,
    caregiverPhone: cg.phone,
    caregiverVehicle: cg.vehicle,
    caregiverSkills: cg.skills,
    caregiverLanguages: cg.languages,
    acceptedAt: ts(now),
    confirmedAt: ts(now),
    price: {
      lines: [{ label: `Escort · RM 30 × est. ${DEFAULT_ESCORT_HOURS} hours`, sen: paidSen }],
      paidSen, shareSen: null, finalShareSen: null, refundSen: 0, creditSen: 0,
    },
    payment: { method: 'fpx', status: 'paid', paidAt: ts(now) },
    createdAt: ts(now),
  });
  await accessRef(db, 'demo-user-family', 'zainab', cgId).set({ bookingId: S3_BOOKING_ID, createdAt: ts(now) });
  await db.doc(`receipts/pay-${S3_BOOKING_ID}`).set({
    uid: user, familyId: 'demo-user-family', bookingId: S3_BOOKING_ID, deliveryId: null,
    amountSen: paidSen, kind: 'payment', label: 'Escort · Zainab binti Ahmad', method: 'FPX online banking', createdAt: ts(now),
  });
  // Fixed id so re-seeding without a reset doesn't stack duplicates (notify() would add a new doc each time).
  await db.doc(`users/${user}/notifications/${S3_BOOKING_ID}`).set({
    type: 'confirmed',
    title: 'Visit confirmed',
    body: `${cg.name} will escort Zainab to her appointment. It's on your schedule.`,
    link: `/booking/${S3_BOOKING_ID}`,
    read: false,
    createdAt: ts(now),
  });

  return { uids: { parent, user, self, caregiver: cgId }, groups, s3BookingId: S3_BOOKING_ID };
}
