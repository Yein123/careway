// The sequential offer cascade (spec §4), shared by bookings and deliveries.
import { FieldValue, Firestore } from 'firebase-admin/firestore';
import { MINUTE, toDate, ts } from '../db';
import { notifyTx } from '../notify';

export const OFFER_TTL_MS = 18 * MINUTE;
export const PAY_TTL_MS = 30 * MINUTE;

export type TargetCol = 'bookings' | 'deliveries';
export type OfferKind = 'personal' | 'groupJoin' | 'groupNew' | 'delivery';

/** Where the guardian goes after a caregiver accepts. */
export function payLink(col: TargetCol, id: string, level?: number): string {
  if (col === 'deliveries') return `/delivery/${id}`;
  return level === 1 ? `/booking/${id}/package` : `/booking/${id}/pay`;
}

export function statusLink(col: TargetCol, id: string): string {
  return col === 'deliveries' ? `/delivery/${id}` : `/booking/${id}/pending`;
}

/** Removes a booking's seat hold from a group's heldSeats array. */
export function withoutHold(group: FirebaseFirestore.DocumentData, bookingId: string): unknown[] {
  return (group.heldSeats ?? []).filter((h: any) => h.bookingId !== bookingId);
}

/**
 * Offers the target to the next ranked caregiver not yet offered, or marks it
 * not_matched when the list is exhausted. [prevOfferId] guards against two
 * advances racing (decline and expiry): the cascade only moves if the target's
 * current offer is still [prevOfferId].
 */
export async function offerNext(db: Firestore, col: TargetCol, id: string, now: Date, prevOfferId: string | null): Promise<void> {
  await db.runTransaction(async (tx) => {
    const ref = db.doc(`${col}/${id}`);
    const snap = await tx.get(ref);
    const t = snap.data();
    if (!t || t.status !== 'pending_caregiver') return;
    if ((t.currentOfferId ?? null) !== prevOfferId) return;

    const offered: string[] = t.offeredUids ?? [];
    const next = (t.rankedUids ?? []).find((u: string) => !offered.includes(u)) as string | undefined;
    const groupRef = col === 'bookings' && t.groupId ? db.doc(`groups/${t.groupId}`) : null;
    const group = groupRef ? (await tx.get(groupRef)).data() : undefined;
    const cg = next ? (await tx.get(db.doc(`caregivers/${next}`))).data() : undefined;

    if (next && cg) {
      const offerRef = db.collection('offers').doc();
      const expiresAt = new Date(now.getTime() + OFFER_TTL_MS);
      tx.set(offerRef, {
        caregiverId: next,
        kind: t.offerKind,
        status: 'offered',
        expiresAt: ts(expiresAt),
        bookingId: col === 'bookings' ? id : null,
        deliveryId: col === 'deliveries' ? id : null,
        groupId: t.groupId ?? null,
        patientName: t.patientSnapshot?.name ?? t.patientName ?? '',
        patientAge: t.patientSnapshot?.age ?? 0,
        placeName: t.placeName ?? '',
        apptAt: t.apptAt ?? t.date ?? null,
        level: t.level ?? 1,
        estimateSen: t.estimateSen ?? 0,
        needs: t.needs ?? [],
        windowStart: t.windowStart ?? null,
        windowEnd: t.windowEnd ?? null,
        createdAt: ts(now),
      });
      tx.update(ref, {
        offeredUids: FieldValue.arrayUnion(next),
        currentOfferId: offerRef.id,
        offerCaregiverName: cg.displayName ?? next,
        offerExpiresAt: ts(expiresAt),
      });
      if (groupRef && group && t.offerKind === 'groupJoin') {
        // Keep the seat held for as long as the helper's offer is open.
        const held = (group.heldSeats ?? []).map((h: any) => (h.bookingId === id ? { ...h, until: ts(expiresAt) } : h));
        tx.update(groupRef, { heldSeats: held });
      }
      notifyTx(tx, db, next, {
        type: 'job-request',
        title: 'New job request',
        body: `${t.patientSnapshot?.name ?? t.patientName ?? 'A patient'} · ${t.placeName ?? ''}. Answer within 18 minutes.`,
        link: '/cg',
      }, now);
      return;
    }

    const reason = t.offerKind === 'groupJoin' ? 'helper-declined' : 'no-caregiver';
    tx.update(ref, {
      status: 'not_matched',
      notMatchedReason: reason,
      currentOfferId: null,
      offerCaregiverName: null,
      offerExpiresAt: null,
    });
    if (groupRef && group) {
      const update: Record<string, unknown> = { heldSeats: withoutHold(group, id) };
      if (t.offerKind === 'groupNew') update.status = 'cancelled';
      tx.update(groupRef, update);
    }
    notifyTx(tx, db, t.guardianUid, {
      type: 'not-matched',
      title: reason === 'helper-declined' ? 'The group could not take this request' : 'No caregiver available',
      body: 'Nothing has been charged. Open the request to see your options.',
      link: col === 'deliveries' ? `/delivery/${id}` : `/booking/${id}/not-found`,
    }, now);
  });
}

export function isExpired(expiresAt: unknown, now: Date): boolean {
  const d = toDate(expiresAt);
  return !d || d.getTime() <= now.getTime();
}
