// requestDelivery: repeat-medicine run, fee by distance formula, then matching.
import { Firestore } from 'firebase-admin/firestore';
import { HOUR, ts } from '../db';
import { fail } from '../errors';
import { deriveRequirements } from '../domain/needs';
import { deliveryFee, routeKm } from '../domain/pricing';
import { HOSPITALS, PICKUP_POINTS } from '../places';
import { rankFor } from '../booking/request';
import { offerNext } from '../booking/offers';

interface DeliveryInput {
  patientId: string;
  pharmacyId: string;
  window: string;
  windowStart: string;
  docs: { card?: boolean; ic?: boolean; letter?: boolean };
}

export async function requestDeliveryLogic(db: Firestore, uid: string, raw: unknown, now: Date): Promise<{ deliveryId: string; status: string }> {
  const input = raw as DeliveryInput;
  if (typeof input?.patientId !== 'string' || typeof input.pharmacyId !== 'string' || typeof input.windowStart !== 'string') {
    fail('bad-request', 'Some delivery details are missing.');
  }
  if (!input.docs?.card || !input.docs?.ic || !input.docs?.letter) fail('docs-missing', 'Tick all 3 documents to continue.');
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
  const ranked = await rankFor(db, req, { apptAt: start, pickup: home, window, familyId: familyId!, patientId: input.patientId });

  const ref = db.collection('deliveries').doc();
  await ref.set({
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
    status: 'pending_caregiver',
    offerKind: 'delivery',
    rankedUids: ranked,
    offeredUids: [],
    currentOfferId: null,
    windowStart: ts(window.start),
    windowEnd: ts(window.end),
    steps: [],
    createdAt: ts(now),
  });
  await offerNext(db, 'deliveries', ref.id, now, null);
  return { deliveryId: ref.id, status: (await ref.get()).data()!.status };
}
