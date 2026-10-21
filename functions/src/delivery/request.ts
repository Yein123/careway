// requestDelivery: repeat-medicine run, fee by distance formula, paid on the spot
// (MedRun → MedBooked in the design). The best available helper is assigned at once.
import { Firestore } from 'firebase-admin/firestore';
import { HOUR, ts } from '../db';
import { fail } from '../errors';
import { notifyTx } from '../notify';
import { deriveRequirements } from '../domain/needs';
import { deliveryFee, routeKm } from '../domain/pricing';
import { HOSPITALS, PICKUP_POINTS } from '../places';
import { rankFor } from '../booking/request';
import { demoCaregiverUid } from '../booking/load';
import { METHOD_LABEL, PAYMENT_METHODS } from '../booking/pay';

interface DeliveryInput {
  patientId: string;
  pharmacyId: string;
  window: string;
  windowStart: string;
  method: string;
  docs: { card?: boolean; ic?: boolean; letter?: boolean };
}

export async function requestDeliveryLogic(db: Firestore, uid: string, raw: unknown, now: Date): Promise<{ deliveryId: string; status: string }> {
  const input = raw as DeliveryInput;
  if (typeof input?.patientId !== 'string' || typeof input.pharmacyId !== 'string' || typeof input.windowStart !== 'string') {
    fail('bad-request', 'Some delivery details are missing.');
  }
  if (!input.docs?.card || !input.docs?.ic || !input.docs?.letter) fail('docs-missing', 'Tick all 3 documents to continue.');
  const method = input.method ?? 'fpx';
  if (!PAYMENT_METHODS.includes(method as never)) fail('bad-request', 'Choose a payment method.');
  const user = (await db.doc(`users/${uid}`).get()).data();
  const familyId: string | undefined = user?.familyId;
  if (!familyId) fail('no-patient', 'Set up your family first.');
  const patient = (await db.doc(`families/${familyId}/patients/${input.patientId}`).get()).data();
  if (!patient) fail('no-patient', 'Choose who the medicine is for.');
  const pharmacy = HOSPITALS.find((h) => h.id === input.pharmacyId);
  if (!pharmacy) fail('bad-request', 'Unknown pharmacy.');
  const start = new Date(input.windowStart);
  if (isNaN(start.getTime()) || start <= now) fail('bad-request', 'Pick a pickup window in the future.');

  const saved = (user!.savedPlaces ?? [])[0];
  const home = saved
    ? { label: `${saved.label} · ${saved.address}`, lat: Number(saved.lat), lng: Number(saved.lng) }
    : { label: PICKUP_POINTS[0].name, lat: PICKUP_POINTS[0].lat, lng: PICKUP_POINTS[0].lng };
  const km = routeKm(home.lat, home.lng, pharmacy.lat, pharmacy.lng);
  const fee = deliveryFee(km);

  const req = deriveRequirements({ level: 1, mobility: 'independent', patientAge: 30, addons: [], delivery: true });
  const window = { start, end: new Date(start.getTime() + 3 * HOUR) };
  const demo = await demoCaregiverUid(db);
  const ranked = await rankFor(db, req, { apptAt: start, pickup: home, window, familyId: familyId!, patientId: input.patientId });
  if (ranked.length === 0) fail('no-caregiver', 'No helper is free in that window. Try another time; nothing was charged.');

  const ref = db.collection('deliveries').doc();
  await db.runTransaction(async (tx) => {
    // First helper in the ranking who is still on duty.
    let cgUid: string | null = null;
    let cg: FirebaseFirestore.DocumentData | undefined;
    for (const id of ranked) {
      const data = (await tx.get(db.doc(`caregivers/${id}`))).data();
      // The demo caregiver takes every delivery, on duty or not.
      if (data?.onDuty || id === demo) {
        cgUid = id;
        cg = data;
        break;
      }
    }
    if (!cgUid || !cg) fail('no-caregiver', 'No helper is free in that window. Try another time; nothing was charged.');

    tx.set(ref, {
      familyId,
      guardianUid: uid,
      patientId: input.patientId,
      patientName: patient.name ?? '',
      pharmacyId: pharmacy.id,
      pharmacyName: pharmacy.name,
      placeName: `Medicine run · ${pharmacy.name}`,
      window: String(input.window ?? ''),
      date: ts(start),
      apptAt: ts(start),
      deliverTo: home.label,
      routeKm: km,
      fee,
      estimateSen: fee.totalSen,
      needs: ['Collect medicine', 'Signature on handover'],
      level: 1,
      status: 'booked',
      caregiverId: cgUid,
      caregiverName: cg.displayName ?? cgUid,
      caregiverPhone: cg.phone ?? '',
      acceptedAt: ts(now),
      windowStart: ts(window.start),
      windowEnd: ts(window.end),
      payment: { method, status: 'paid', paidAt: ts(now) },
      steps: [{ key: 'booked', at: ts(now) }],
      createdAt: ts(now),
    });
    tx.set(db.doc(`receipts/pay-del-${ref.id}`), {
      uid,
      familyId,
      bookingId: null,
      deliveryId: ref.id,
      amountSen: fee.totalSen,
      kind: 'payment',
      label: `Medicine delivery · ${patient.name ?? ''}`,
      method: METHOD_LABEL[method],
      createdAt: ts(now),
    });
    notifyTx(tx, db, cgUid, {
      type: 'confirmed',
      title: 'New medicine run',
      body: `Collect documents from ${home.label} · ${input.window ?? ''}.`,
      link: '/cg/schedule',
    }, now);
  });
  return { deliveryId: ref.id, status: 'booked' };
}
