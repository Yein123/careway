// Caregiver visit progress (spec §6): advanceStep and submitSummary.
import { Firestore } from 'firebase-admin/firestore';
import { toDate, ts } from '../db';
import { denied, fail } from '../errors';
import { notifyTx } from '../notify';
import { escortFinalSen, PRIVATE_RIDE_SEN } from '../domain/pricing';
import { accessRef } from './offers';

export const GROUP_STEPS = ['picked_up', 'registered', 'with_doctor', 'pharmacy', 'ride_home', 'home'];
export const PERSONAL_STEPS = ['picked_up', 'registered', 'waiting_doctor', 'with_doctor', 'pharmacy', 'ride_home', 'home'];
export const STEP_LABEL: Record<string, string> = {
  picked_up: 'Picked up',
  registered: 'Arrived and registered',
  waiting_doctor: 'Waiting for the doctor',
  with_doctor: 'With the doctor',
  pharmacy: 'At the pharmacy',
  ride_home: 'On the ride home',
  home: 'Home safely',
};

export async function advanceStepLogic(db: Firestore, uid: string, raw: unknown, now: Date): Promise<{ step: string; status: string }> {
  const input = raw as { bookingId?: unknown };
  if (typeof input?.bookingId !== 'string') fail('bad-request', 'Missing booking.');
  const ref = db.doc(`bookings/${input.bookingId}`);
  return db.runTransaction(async (tx) => {
    const b = (await tx.get(ref)).data();
    if (!b) fail('bad-request', 'Booking not found.');
    if (b.caregiverId !== uid) denied('This visit is assigned to another caregiver.');
    if (!['confirmed', 'in_progress'].includes(b.status)) fail('not-active', 'This visit is not active.');
    const keys = b.level === 1 ? GROUP_STEPS : PERSONAL_STEPS;
    const steps: { key: string; at: unknown }[] = b.steps ?? [];
    const next = keys[steps.length];
    if (!next) fail('not-active', 'All steps are done.');
    const last = steps.length === keys.length - 1;
    const needsSummary = b.level === 2 || (b.addons ?? []).includes('visitSummary');
    if (last && needsSummary && !b.summary) fail('summary-required', 'Write the visit summary before finishing.');

    const update: Record<string, unknown> = { steps: [...steps, { key: next, at: ts(now) }] };
    if (steps.length === 0) update.status = 'in_progress';
    if (last) {
      update.status = 'completed';
      update.completedAt = ts(now);
      tx.delete(accessRef(db, b.familyId, b.patientId, uid));
      if (b.level === 2 && steps.length > 0) {
        // Charged by actual time: refund the difference when shorter than the estimate.
        const started = toDate(steps[0].at)!;
        const minutes = Math.max(30, Math.round((now.getTime() - started.getTime()) / 60_000));
        const final = escortFinalSen(minutes);
        const refund = Math.max(0, (b.price?.paidSen ?? 0) - final);
        if (refund > 0) {
          update['price.refundSen'] = (b.price?.refundSen ?? 0) + refund;
          tx.set(db.collection('receipts').doc(), {
            uid: b.guardianUid,
            familyId: b.familyId,
            bookingId: ref.id,
            deliveryId: null,
            amountSen: refund,
            kind: 'refund',
            label: `Shorter visit · ${Math.ceil(minutes / 30) / 2} h escort + ride RM ${(PRIVATE_RIDE_SEN / 100).toFixed(2)}`,
            method: b.payment?.method ?? '',
            createdAt: ts(now),
          });
        }
      }
    }
    tx.update(ref, update);
    const name = b.patientSnapshot?.name ?? 'Your family member';
    notifyTx(tx, db, b.guardianUid, last
      ? { type: 'visit-step', title: `${name} is home safely`, body: 'The visit is complete. Tap to read the summary and rate the visit.', link: '/visits' }
      : { type: 'visit-step', title: `${STEP_LABEL[next]} · ${name}`, body: `Update from ${b.caregiverName ?? 'your caregiver'}.`, link: `/booking/${ref.id}/live` },
      now);
    return { step: next, status: (update.status as string) ?? b.status };
  });
}

export async function submitSummaryLogic(db: Firestore, uid: string, raw: unknown, now: Date): Promise<{ ok: true }> {
  const input = raw as { bookingId?: unknown; summary?: any };
  const s = input?.summary;
  if (typeof input?.bookingId !== 'string' || !s || typeof s.seenBy !== 'string' || typeof s.diagnosis !== 'string') {
    fail('bad-request', 'Fill in who you saw and what the doctor said.');
  }
  const ref = db.doc(`bookings/${input.bookingId}`);
  await db.runTransaction(async (tx) => {
    const b = (await tx.get(ref)).data();
    if (!b) fail('bad-request', 'Booking not found.');
    if (b.caregiverId !== uid) denied('This visit is assigned to another caregiver.');
    if (!['confirmed', 'in_progress', 'completed'].includes(b.status)) fail('not-active', 'This visit is not active.');
    const cg = (await tx.get(db.doc(`caregivers/${uid}`))).data();
    tx.update(ref, {
      summary: {
        seenBy: s.seenBy.trim(),
        diagnosis: s.diagnosis.trim(),
        instructions: Array.isArray(s.instructions) ? s.instructions.map(String).filter((x: string) => x.trim()) : [],
        nextAppt: String(s.nextAppt ?? ''),
        medicines: String(s.medicines ?? ''),
        notes: String(s.notes ?? ''),
        writtenBy: cg?.displayName ?? uid,
        writtenAt: ts(now),
      },
    });
  });
  return { ok: true };
}
