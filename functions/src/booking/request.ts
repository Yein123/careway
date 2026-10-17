// requestBooking: validate, derive needs, hold a group seat if joining, start matching.
import { Firestore } from 'firebase-admin/firestore';
import { HOUR, MINUTE, toDate, ts } from '../db';
import { fail } from '../errors';
import { filterCandidates, qualifies, rankCandidates } from '../domain/matching';
import { deriveRequirements, level1Allowed, Mobility, needLabels, Requirements } from '../domain/needs';
import { ESCORT_HOURLY_SEN, DEFAULT_ESCORT_HOURS, GROUP_CAPACITY, groupShareSen } from '../domain/pricing';
import { mytDate, mytTime, placeById } from '../places';
import { jobWindow, loadCaregivers, loadCommitments, loadPatientHistory, caregiverFromDoc } from './load';
import { offerNext, OFFER_TTL_MS } from './offers';

export interface RequestInput {
  patientId: string;
  level: number;
  pickup: { label: string; lat: number; lng: number };
  hospitalId: string;
  clinic: string;
  apptAt: string;
  groupId?: string;
  newGroup?: { pickupPointId: string; pickupTime: string };
  /** Preferred language (ranking bonus). */
  language?: string;
  waitlist?: boolean;
}

export const MIN_LEAD_MS = 24 * HOUR;

function parseInput(raw: any): RequestInput {
  const ok =
    raw &&
    typeof raw.patientId === 'string' &&
    (raw.level === 1 || raw.level === 2) &&
    typeof raw.hospitalId === 'string' &&
    typeof raw.clinic === 'string' &&
    typeof raw.apptAt === 'string' &&
    raw.pickup &&
    typeof raw.pickup.lat === 'number' &&
    typeof raw.pickup.lng === 'number';
  if (!ok) fail('bad-request', 'Some booking details are missing.');
  return raw as RequestInput;
}

export async function requestBookingLogic(
  db: Firestore,
  uid: string,
  raw: unknown,
  now: Date,
): Promise<{ bookingId: string; status: string }> {
  const input = parseInput(raw);
  const user = (await db.doc(`users/${uid}`).get()).data();
  const familyId: string | undefined = user?.familyId;
  if (!familyId) fail('no-patient', 'Set up your family first.');
  const patientSnap = await db.doc(`families/${familyId}/patients/${input.patientId}`).get();
  if (!patientSnap.exists) fail('no-patient', 'Add who is going first.');
  const patient = patientSnap.data()!;

  const apptAt = new Date(input.apptAt);
  if (isNaN(apptAt.getTime())) fail('bad-request', 'Invalid appointment time.');
  if (apptAt.getTime() - now.getTime() < MIN_LEAD_MS) fail('too-soon', 'Book at least 24 hours ahead.');
  const hospital = placeById(input.hospitalId);
  if (!hospital) fail('bad-request', 'Unknown hospital.');

  const mobility = (patient.mobility ?? 'independent') as Mobility;
  const age = Number(patient.age ?? 0);
  if (input.level === 1 && !level1Allowed(mobility, age)) {
    fail('level1-not-allowed', age < 18 ? 'Children under 18 always get Level 2.' : 'Lifting and transfer help needs Level 2.');
  }
  const req = deriveRequirements({ level: input.level, mobility, patientAge: age, addons: [] });

  const bookingRef = db.collection('bookings').doc();
  const base = {
    familyId,
    guardianUid: uid,
    guardianName: user?.name ?? '',
    patientId: input.patientId,
    patientSnapshot: {
      name: patient.name ?? '',
      age,
      mobility,
      allergy: patient.allergy ?? '',
      talkNotes: patient.talkNotes ?? '',
    },
    level: input.level,
    hospitalId: hospital.id,
    clinic: input.clinic,
    placeName: `${hospital.name} · ${input.clinic}`,
    apptAt: ts(apptAt),
    language: input.language ?? null,
    addons: [],
    package: null,
    requiredSkills: req.skills,
    requiredCerts: req.certs,
    needs: needLabels(req, mobility),
    price: { lines: [], paidSen: 0, refundSen: 0, creditSen: 0 },
    steps: [],
    waitlist: false,
    rankedUids: [],
    offeredUids: [],
    currentOfferId: null,
    createdAt: ts(now),
  };

  if (input.level === 1 && input.groupId) {
    return joinGroup(db, bookingRef, base, input, req, apptAt, now);
  }

  let pickup = input.pickup;
  let pickupAt: Date | null = null;
  let groupId: string | null = null;
  let offerKind: 'personal' | 'groupNew' = 'personal';
  let estimateSen = ESCORT_HOURLY_SEN * DEFAULT_ESCORT_HOURS;

  if (input.level === 1) {
    if (!input.newGroup) fail('bad-request', 'Pick a group or start a new one.');
    const point = placeById(input.newGroup.pickupPointId);
    pickupAt = new Date(input.newGroup.pickupTime);
    if (!point || isNaN(pickupAt.getTime()) || pickupAt >= apptAt) fail('bad-request', 'Pick a pickup point and a time before the appointment.');
    pickup = { label: point.name, lat: point.lat, lng: point.lng };
    const lockAt = new Date(pickupAt.getTime() - 24 * HOUR);
    const groupRef = db.collection('groups').doc();
    groupId = groupRef.id;
    await groupRef.set({
      hospitalId: hospital.id,
      clinic: input.clinic,
      date: mytDate(apptAt),
      pickupPointId: point.id,
      pickupAt: ts(pickupAt),
      apptWindow: `${mytTime(apptAt)}–${mytTime(new Date(apptAt.getTime() + 45 * MINUTE))}`,
      status: 'open',
      lockAt: ts(lockAt),
      caregiverId: null,
      caregiverName: null,
      caregiverRating: null,
      riderBookingIds: [],
      riderInitials: [],
      // The founder's seat is held until the group locks.
      heldSeats: [{ bookingId: bookingRef.id, until: ts(lockAt) }],
      capacity: GROUP_CAPACITY,
      createdAt: ts(now),
    });
    offerKind = 'groupNew';
    estimateSen = groupShareSen('saver', 1);
  }

  const window = jobWindow(apptAt, pickupAt);
  const ranked = await rankFor(db, req, { apptAt, pickup, window, familyId, patientId: input.patientId, language: input.language });
  await bookingRef.set({
    ...base,
    pickup,
    pickupAt: pickupAt ? ts(pickupAt) : null,
    groupId,
    lockAt: pickupAt ? ts(new Date(pickupAt.getTime() - 24 * HOUR)) : null,
    status: 'pending_caregiver',
    offerKind,
    estimateSen,
    windowStart: ts(window.start),
    windowEnd: ts(window.end),
    rankedUids: ranked,
  });
  await offerNext(db, 'bookings', bookingRef.id, now, null);
  return { bookingId: bookingRef.id, status: (await bookingRef.get()).data()!.status };
}

export async function rankFor(
  db: Firestore,
  req: Requirements,
  o: { apptAt: Date; pickup: { lat: number; lng: number }; window: { start: Date; end: Date }; familyId: string; patientId: string; language?: string },
): Promise<string[]> {
  const [cgs, commitments, history] = await Promise.all([
    loadCaregivers(db),
    loadCommitments(db, mytDate(o.apptAt)),
    loadPatientHistory(db, o.familyId, o.patientId),
  ]);
  const eligible = filterCandidates(cgs, req, { apptAt: o.apptAt, pickup: o.pickup, window: o.window, busy: commitments.busy });
  return rankCandidates(eligible, {
    pickup: o.pickup,
    patientHistory: history,
    jobsThatDay: commitments.jobsThatDay,
    language: o.language,
  });
}

async function joinGroup(
  db: Firestore,
  bookingRef: FirebaseFirestore.DocumentReference,
  base: Record<string, unknown>,
  input: RequestInput,
  req: Requirements,
  apptAt: Date,
  now: Date,
): Promise<{ bookingId: string; status: string }> {
  const groupRef = db.doc(`groups/${input.groupId}`);
  const result = await db.runTransaction(async (tx) => {
    const g = (await tx.get(groupRef)).data();
    if (!g) fail('group-full', 'This group is no longer available.');
    const point = placeById(g.pickupPointId)!;
    const pickupAt = toDate(g.pickupAt)!;
    const holds = (g.heldSeats ?? []).filter((h: any) => toDate(h.until)!.getTime() > now.getTime());
    const seatsLeft = (g.capacity ?? GROUP_CAPACITY) - (g.riderBookingIds ?? []).length - holds.length;
    const window = jobWindow(apptAt, pickupAt);
    const doc = {
      ...base,
      pickup: { label: point.name, lat: point.lat, lng: point.lng },
      pickupAt: ts(pickupAt),
      groupId: input.groupId,
      lockAt: g.lockAt,
      offerKind: 'groupJoin',
      estimateSen: groupShareSen('saver', Math.min(GROUP_CAPACITY, (g.riderBookingIds ?? []).length + 1)),
      windowStart: ts(window.start),
      windowEnd: ts(window.end),
    };
    const unavailable = g.status !== 'open' ? 'group-full' : seatsLeft <= 0 ? 'seat-taken' : null;
    if (unavailable) {
      if (input.waitlist) {
        tx.set(bookingRef, { ...doc, status: 'draft', waitlist: true });
        return { status: 'draft', helper: null as string | null };
      }
      fail(unavailable, unavailable === 'group-full' ? 'This group is full.' : 'The last seat was just taken.');
    }
    tx.update(groupRef, {
      heldSeats: [...holds, { bookingId: bookingRef.id, until: ts(new Date(now.getTime() + OFFER_TTL_MS)) }],
    });
    tx.set(bookingRef, { ...doc, status: 'pending_caregiver' });
    return { status: 'pending_caregiver', helper: (g.caregiverId ?? null) as string | null };
  });

  if (result.status === 'draft') return { bookingId: bookingRef.id, status: 'draft' };

  // Only the group's own helper can take this rider, and only if they qualify.
  let ranked: string[] = [];
  if (result.helper) {
    const cgSnap = await db.doc(`caregivers/${result.helper}`).get();
    if (cgSnap.exists) {
      const helper = caregiverFromDoc(cgSnap.id, cgSnap.data()!);
      const commitments = await loadCommitments(db, mytDate(apptAt), input.groupId);
      const b = (await bookingRef.get()).data()!;
      const window = { start: toDate(b.windowStart)!, end: toDate(b.windowEnd)! };
      const free = !(commitments.busy.get(helper.uid) ?? []).some((i) => i.start < window.end && window.start < i.end);
      if (helper.onDuty && free && qualifies(helper, req, apptAt)) ranked = [helper.uid];
    }
  }
  await bookingRef.update({ rankedUids: ranked });
  await offerNext(db, 'bookings', bookingRef.id, now, null);
  return { bookingId: bookingRef.id, status: (await bookingRef.get()).data()!.status };
}
