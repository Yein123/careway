// Demo-control callables (admin claim only; gated in index.ts). Each wraps existing logic.
import { Auth } from 'firebase-admin/auth';
import { Firestore } from 'firebase-admin/firestore';
import { fail } from '../errors';
import { advanceStepLogic } from '../booking/steps';
import { lockGroupTx } from '../booking/lock';
import { offerNext, TargetCol } from '../booking/offers';
import { respondToOfferLogic } from '../booking/respond';
import { advanceDeliveryTx } from '../delivery/progress';
import { resetDemoLogic } from '../demo/reset';

function colOf(v: unknown): TargetCol {
  if (v !== 'bookings' && v !== 'deliveries') fail('bad-request', 'Unknown request type.');
  return v;
}

function strOf(v: unknown, what: string): string {
  if (typeof v !== 'string' || !v) fail('bad-request', `Missing ${what}.`);
  return v;
}

export async function adminResetLogic(db: Firestore, auth: Auth, now: Date): Promise<{ deleted: number }> {
  const { deleted } = await resetDemoLogic(db, auth, now);
  return { deleted };
}

export async function adminRespondOfferLogic(db: Firestore, raw: unknown, now: Date): Promise<{ status: string }> {
  const input = raw as { col?: unknown; id?: unknown; accept?: unknown };
  const col = colOf(input?.col);
  const id = strOf(input.id, 'id');
  if (typeof input.accept !== 'boolean') fail('bad-request', 'Missing accept.');
  const target = (await db.doc(`${col}/${id}`).get()).data();
  const offerId: string | null = target?.currentOfferId ?? null;
  const offer = offerId ? (await db.doc(`offers/${offerId}`).get()).data() : undefined;
  if (!offerId || !offer) fail('no-offer', 'No open offer for this request.');
  return respondToOfferLogic(db, offer.caregiverId, { offerId, accept: input.accept }, now);
}

export async function adminNotFoundLogic(db: Firestore, raw: unknown, now: Date): Promise<{ status: string }> {
  const input = raw as { col?: unknown; id?: unknown };
  const col = colOf(input?.col);
  const id = strOf(input.id, 'id');
  const ref = db.doc(`${col}/${id}`);
  const prev = await db.runTransaction(async (tx) => {
    const t = (await tx.get(ref)).data();
    if (!t || t.status !== 'pending_caregiver') fail('no-offer', 'No open offer for this request.');
    const offerId: string | null = t.currentOfferId ?? null;
    if (offerId) tx.update(db.doc(`offers/${offerId}`), { status: 'expired' });
    const all = Array.from(new Set<string>([...(t.offeredUids ?? []), ...(t.rankedUids ?? [])]));
    tx.update(ref, { offeredUids: all });
    return offerId;
  });
  await offerNext(db, col, id, now, prev);
  return { status: 'not_matched' };
}

export async function adminLockGroupLogic(db: Firestore, raw: unknown, now: Date): Promise<{ locked: boolean; status: string }> {
  const groupId = strOf((raw as { groupId?: unknown })?.groupId, 'group');
  const locked = await lockGroupTx(db, groupId, now);
  if (!locked) fail('not-lockable', 'This group cannot be locked.');
  const status: string = (await db.doc(`groups/${groupId}`).get()).data()?.status ?? '';
  return { locked, status };
}

export async function adminAdvanceDeliveryLogic(db: Firestore, raw: unknown, now: Date): Promise<{ stage: string }> {
  const input = raw as { id?: unknown; toEnd?: unknown };
  const id = strOf(input?.id, 'id');
  let stage = await advanceDeliveryTx(db, id, now, { force: true });
  if (stage === null) fail('not-active', 'This delivery is not active.');
  while (input.toEnd === true) {
    const next = await advanceDeliveryTx(db, id, now, { force: true });
    if (next === null) break;
    stage = next;
  }
  return { stage };
}

export async function adminAdvanceStepLogic(db: Firestore, raw: unknown, now: Date): Promise<{ step: string }> {
  const bookingId = strOf((raw as { bookingId?: unknown })?.bookingId, 'booking');
  const b = (await db.doc(`bookings/${bookingId}`).get()).data();
  if (!b?.caregiverId) fail('not-active', 'This visit is not active.');
  const { step } = await advanceStepLogic(db, b.caregiverId, { bookingId }, now);
  return { step };
}
