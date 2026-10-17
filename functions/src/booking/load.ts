// Loading caregivers and their commitments for matching.
import { Firestore } from 'firebase-admin/firestore';
import { HOUR, toDate } from '../db';
import { Caregiver, Interval } from '../domain/matching';
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

/** Caregivers who completed a visit for this patient before. */
export async function loadPatientHistory(db: Firestore, familyId: string, patientId: string): Promise<Set<string>> {
  const q = await db
    .collection('bookings')
    .where('familyId', '==', familyId)
    .where('patientId', '==', patientId)
    .where('status', '==', 'completed')
    .get();
  return new Set(q.docs.map((d) => d.data().caregiverId).filter(Boolean));
}
