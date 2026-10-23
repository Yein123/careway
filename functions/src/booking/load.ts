// Loading caregivers and their commitments for matching.
import { Firestore } from 'firebase-admin/firestore';
import { HOUR, toDate } from '../db';
import { Caregiver, Interval, Personalisation } from '../domain/matching';
import { CertType, Skill } from '../domain/needs';
import { mytDate } from '../places';

export const ACTIVE_JOB_STATUSES = ['awaiting_payment', 'confirmed', 'in_progress'];

/** Time a job occupies its caregiver: from pickup (or 1h before) to 4h after the appointment. */
export function jobWindow(apptAt: Date, pickupAt?: Date | null): Interval {
  return { start: pickupAt ?? new Date(apptAt.getTime() - HOUR), end: new Date(apptAt.getTime() + 4 * HOUR) };
}

export function caregiverFromDoc(uid: string, d: FirebaseFirestore.DocumentData): Caregiver {
  return {
    uid,
    displayName: d.displayName ?? uid,
    phone: d.phone ?? '',
    onDuty: !!d.onDuty,
    rating: Number(d.rating ?? 0),
    languages: d.languages ?? [],
    skills: (d.skills ?? []) as Skill[],
    certificates: (d.certificates ?? []).map((c: any) => ({
      type: c.type as CertType,
      verified: !!c.verified,
      expiresAt: toDate(c.expiresAt) ?? new Date(0),
    })),
    home: { lat: Number(d.home?.lat ?? 0), lng: Number(d.home?.lng ?? 0) },
  };
}

/** Demo: every booking and delivery request goes to this caregiver while their profile exists. */
export const DEMO_CAREGIVER_EMAIL = 'ravi@careway.demo';

/** The demo caregiver's uid, or null when they have no user or caregiver profile (normal matching then applies). */
export async function demoCaregiverUid(db: Firestore): Promise<string | null> {
  const q = await db.collection('users').where('email', '==', DEMO_CAREGIVER_EMAIL).limit(1).get();
  const uid = q.docs[0]?.id;
  if (!uid) return null;
  return (await db.doc(`caregivers/${uid}`).get()).exists ? uid : null;
}

export async function loadCaregivers(db: Firestore): Promise<Caregiver[]> {
  const q = await db.collection('caregivers').get();
  return q.docs.map((d) => caregiverFromDoc(d.id, d.data()));
}

export interface Commitments {
  busy: Map<string, Interval[]>;
  jobsThatDay: Map<string, number>;
}

/**
 * Accepted jobs and open offers per caregiver. Bookings in [excludeGroupId]
 * (the helper's own group trip) don't count as clashes.
 */
export async function loadCommitments(db: Firestore, day: string, excludeGroupId?: string): Promise<Commitments> {
  const busy = new Map<string, Interval[]>();
  const jobsThatDay = new Map<string, number>();
  const add = (uid: string, w: Interval) => busy.set(uid, [...(busy.get(uid) ?? []), w]);

  const jobs = await db.collection('bookings').where('status', 'in', ACTIVE_JOB_STATUSES).get();
  for (const d of jobs.docs) {
    const b = d.data();
    if (!b.caregiverId) continue;
    const appt = toDate(b.apptAt)!;
    if (mytDate(appt) === day) jobsThatDay.set(b.caregiverId, (jobsThatDay.get(b.caregiverId) ?? 0) + 1);
    if (excludeGroupId && b.groupId === excludeGroupId) continue;
    add(b.caregiverId, jobWindow(appt, toDate(b.pickupAt)));
  }
  const offers = await db.collection('offers').where('status', '==', 'offered').get();
  for (const d of offers.docs) {
    const o = d.data();
    if (excludeGroupId && o.groupId === excludeGroupId) continue;
    if (o.windowStart && o.windowEnd) add(o.caregiverId, { start: toDate(o.windowStart)!, end: toDate(o.windowEnd)! });
  }
  return { busy, jobsThatDay };
}

export interface FamilyHistory {
  /** Caregivers who completed a visit for this patient before. */
  patientHistory: Set<string>;
  personal: Personalisation;
}

/**
 * This family's past jobs (bookings and medicine runs): completed visits with the
 * patient, the family's average rating per caregiver, and who knows [placeId].
 */
export async function loadFamilyHistory(db: Firestore, familyId: string, patientId: string, placeId?: string): Promise<FamilyHistory> {
  const [bookings, deliveries, atPlace] = await Promise.all([
    db.collection('bookings').where('familyId', '==', familyId).get(),
    db.collection('deliveries').where('familyId', '==', familyId).get(),
    placeId
      ? db.collection('bookings').where('hospitalId', '==', placeId).where('status', '==', 'completed').get()
      : Promise.resolve(null),
  ]);
  const patientVisits = new Map<string, number>();
  const stars = new Map<string, number[]>();
  for (const d of [...bookings.docs, ...deliveries.docs]) {
    const j = d.data();
    if (!j.caregiverId) continue;
    if (j.patientId === patientId && (j.status === 'completed' || j.status === 'delivered')) {
      patientVisits.set(j.caregiverId, (patientVisits.get(j.caregiverId) ?? 0) + 1);
    }
    const n = Number(j.rating?.stars ?? 0);
    if (n >= 1 && n <= 5) stars.set(j.caregiverId, [...(stars.get(j.caregiverId) ?? []), n]);
  }
  const familyRatings = new Map([...stars].map(([u, xs]) => [u, xs.reduce((t, x) => t + x, 0) / xs.length]));
  const placeVisits = new Map<string, number>();
  for (const d of atPlace?.docs ?? []) {
    const u = d.data().caregiverId;
    if (u) placeVisits.set(u, (placeVisits.get(u) ?? 0) + 1);
  }
  return { patientHistory: new Set(patientVisits.keys()), personal: { patientVisits, familyRatings, placeVisits } };
}
