// payBooking: simulated payment after a caregiver accepted (spec §5).
import { Firestore } from 'firebase-admin/firestore';
import { ts } from '../db';
import { denied, fail } from '../errors';
import { notifyTx } from '../notify';
import {
  ADDON_LABEL, ADDON_SEN, AddonId, DEFAULT_ESCORT_HOURS, ESCORT_HOURLY_SEN, GROUP_CAPACITY, GroupPackage,
  groupShareSen, isAddon, PACKAGE_LABEL, PRIVATE_RIDE_SEN,
} from '../domain/pricing';

export const PAYMENT_METHODS = ['fpx', 'tng', 'duitnow', 'card'] as const;
export const METHOD_LABEL: Record<string, string> = {
  fpx: 'FPX online banking',
  tng: "Touch 'n Go eWallet",
  duitnow: 'DuitNow QR',
  card: 'Debit or credit card',
};

interface PayInput {
  bookingId: string;
  method: string;
  package?: GroupPackage;
  addons?: AddonId[];
  language?: string;
}

function initials(name: string): string {
  const skip = new Set(['bin', 'binti', 'a/l', 'a/p']);
  const w = name.trim().split(/\s+/).filter((p) => p && !skip.has(p.toLowerCase()));
  if (w.length === 0) return '?';
  return (w.length === 1 ? w[0][0] : w[0][0] + w[w.length - 1][0]).toUpperCase();
}

export async function assertFamilyMember(db: Firestore, tx: FirebaseFirestore.Transaction, uid: string, familyId: string) {
  const user = (await tx.get(db.doc(`users/${uid}`))).data();
  if (!user || user.familyId !== familyId) denied('This booking belongs to another family.');
  return user;
}

export async function payBookingLogic(db: Firestore, uid: string, raw: unknown, now: Date): Promise<{ status: string; paidSen: number }> {
  const input = raw as PayInput;
  if (typeof input?.bookingId !== 'string' || !PAYMENT_METHODS.includes(input.method as never)) {
    fail('bad-request', 'Choose a payment method.');
  }
  const addons = input.addons ?? [];
  if (!Array.isArray(addons) || !addons.every(isAddon)) fail('bad-request', 'Unknown add-on.');
  const ref = db.doc(`bookings/${input.bookingId}`);

  return db.runTransaction(async (tx) => {
    const b = (await tx.get(ref)).data();
    if (!b) fail('not-payable', 'Booking not found.');
    await assertFamilyMember(db, tx, uid, b.familyId);
    if (b.status === 'confirmed' && b.payment?.status === 'paid') return { status: 'confirmed', paidSen: b.price.paidSen };
    if (b.status !== 'awaiting_payment') fail('not-payable', 'This booking is not waiting for payment.');

    const groupRef = b.groupId ? db.doc(`groups/${b.groupId}`) : null;
    const group = groupRef ? (await tx.get(groupRef)).data() : undefined;

    let lines: { label: string; sen: number }[];
    let shareSen: number | null = null;
    if (b.level === 1) {
      if (input.package !== 'saver' && input.package !== 'flex') fail('bad-request', 'Pick a package.');
      if (!group) fail('not-payable', 'This group is no longer available.');
      if (addons.includes('language')) {
        const lang = typeof input.language === 'string' ? input.language.trim() : '';
        if (!lang || lang.length > 40) fail('bad-request', 'Type the language needed for Language help.');
        input.language = lang;
      }
      const riders: string[] = group.riderBookingIds ?? [];
      const n = Math.min(GROUP_CAPACITY, riders.includes(ref.id) ? riders.length : riders.length + 1);
      shareSen = groupShareSen(input.package, n);
      lines = [
        { label: `${PACKAGE_LABEL[input.package]} (ride + shared helper)`, sen: shareSen },
        ...addons.map((a) => ({ label: a === 'language' ? `Language help (${input.language})` : ADDON_LABEL[a], sen: ADDON_SEN[a] })),
      ];
    } else {
      lines = [
        { label: `Escort · RM 30 × est. ${DEFAULT_ESCORT_HOURS} hours`, sen: ESCORT_HOURLY_SEN * DEFAULT_ESCORT_HOURS },
        { label: 'Private ride, both ways', sen: b.rideSen ?? PRIVATE_RIDE_SEN },
      ];
    }
    const paidSen = lines.reduce((t, l) => t + l.sen, 0);

    tx.update(ref, {
      status: 'confirmed',
      package: b.level === 1 ? input.package : null,
      addons,
      language: addons.includes('language') ? input.language : b.language ?? null,
      price: { lines, paidSen, shareSen, finalShareSen: null, refundSen: 0, creditSen: 0 },
      payment: { method: input.method, status: 'paid', paidAt: ts(now) },
      confirmedAt: ts(now),
    });
    if (groupRef && group) {
      const riders: string[] = group.riderBookingIds ?? [];
      if (!riders.includes(ref.id)) {
        const nextRiders = [...riders, ref.id];
        tx.update(groupRef, {
          riderBookingIds: nextRiders,
          riderInitials: [...(group.riderInitials ?? []), initials(b.patientSnapshot?.name ?? '')],
          heldSeats: (group.heldSeats ?? []).filter((h: any) => h.bookingId !== ref.id),
          status: nextRiders.length >= (group.capacity ?? GROUP_CAPACITY) ? 'full' : group.status,
        });
      }
    }
    tx.set(db.doc(`receipts/pay-${ref.id}`), {
      uid,
      familyId: b.familyId,
      bookingId: ref.id,
      deliveryId: null,
      amountSen: paidSen,
      kind: 'payment',
      label: `${b.level === 1 ? 'Shared ride' : 'Escort'} · ${b.patientSnapshot?.name ?? ''}`,
      method: METHOD_LABEL[input.method],
      createdAt: ts(now),
    });
    notifyTx(tx, db, b.caregiverId, {
      type: 'confirmed',
      title: 'Visit confirmed',
      body: `${b.patientSnapshot?.name ?? 'The patient'}'s family has paid. It's on your schedule.`,
      link: `/cg/job/${ref.id}`,
    }, now);
    return { status: 'confirmed', paidSen };
  });
}
