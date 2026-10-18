// requestRideHome: a Level 1 guardian tells the helper the patient is ready at the pharmacy.
import { Firestore } from 'firebase-admin/firestore';
import { ts } from '../db';
import { fail } from '../errors';
import { notifyTx } from '../notify';
import { assertFamilyMember } from './pay';

export async function requestRideHomeLogic(db: Firestore, uid: string, raw: unknown, now: Date): Promise<{ ok: true }> {
  const input = raw as { bookingId?: unknown };
  if (typeof input?.bookingId !== 'string') fail('bad-request', 'Missing booking.');
  const ref = db.doc(`bookings/${input.bookingId}`);
  return db.runTransaction(async (tx) => {
    const b = (await tx.get(ref)).data();
    if (!b) fail('bad-request', 'Booking not found.');
    await assertFamilyMember(db, tx, uid, b.familyId);
    if (b.level !== 1 || b.status !== 'in_progress') fail('not-active', 'This visit is not waiting for a ride home.');
    const steps: { key: string }[] = b.steps ?? [];
    if (steps.some((s) => s.key === 'ride_home' || s.key === 'home')) fail('not-active', 'The ride home is already on its way.');
    if (b.rideRequestedAt) return { ok: true as const };
    tx.update(ref, { rideRequestedAt: ts(now) });
    if (b.caregiverId) {
      const name = b.patientSnapshot?.name ?? 'Your patient';
      notifyTx(tx, db, b.caregiverId, {
        type: 'ride-ready',
        title: `${name} is ready for pickup`,
        body: 'Meet them at the pharmacy and walk them to the van.',
        link: `/cg/job/${ref.id}/steps`,
      }, now);
    }
    return { ok: true as const };
  });
}
