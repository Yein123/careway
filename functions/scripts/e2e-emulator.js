// End-to-end check against the running emulator suite (auth 9099, firestore
// 8085, functions 5001). Signs in demo users and drives the real callables:
//   source tool/dev-env.sh && firebase emulators:exec --only auth,firestore,functions \
//     "node functions/scripts/e2e-emulator.js"
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const PROJECT = 'careway-tehwoq';
const REGION = 'asia-southeast1';
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085';
initializeApp({ projectId: PROJECT });
const db = getFirestore();

let failures = 0;
function check(label, ok, extra = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${extra ? ` (${extra})` : ''}`);
  if (!ok) failures++;
}

async function signIn(email) {
  const r = await fetch(`http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'careway123', returnSecureToken: true }),
  });
  const j = await r.json();
  if (!j.idToken) throw new Error(`sign in failed for ${email}: ${JSON.stringify(j)}`);
  return { token: j.idToken, uid: j.localId };
}

async function call(name, data, user) {
  const r = await fetch(`http://127.0.0.1:5001/${PROJECT}/${REGION}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${user.token}` } : {}) },
    body: JSON.stringify({ data }),
  });
  const j = await r.json();
  if (j.error) throw Object.assign(new Error(`${name}: ${j.error.message}`), { details: j.error.details });
  return j.result;
}

const get = async (path) => (await db.doc(path).get()).data();
const openOffer = async (field, id) =>
  (await db.collection('offers').where(field, '==', id).where('status', '==', 'offered').get()).docs[0];

/** Local (UTC+8) date d days from now at hh:mm, as a Date. */
function localAt(days, hh, mm) {
  const day = new Date(Date.now() + 8 * 3600e3 + days * 86400e3).toISOString().slice(0, 10);
  return new Date(`${day}T${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}:00+08:00`);
}

(async () => {
  await call('seedDemo', null);
  const aisyah = await signIn('user@gmail.com');
  const farid = await signIn('farid@careway.demo');
  const nurul = await signIn('nurul@careway.demo');
  const familyId = (await get(`users/${aisyah.uid}`)).familyId;
  check('demo data seeded', !!familyId);

  // Level 1: join the Elmina Lakeside group 3 days out.
  const appt = localAt(3, 9, 0);
  const dateKey = new Date(appt.getTime() + 8 * 3600e3).toISOString().slice(0, 10);
  const groupId = `demo-${dateKey}-elmina-lakeside`;
  const req = await call('requestBooking', {
    patientId: 'zainab', level: 1, groupId,
    pickup: { label: 'Home', lat: 3.1885, lng: 101.5165 },
    hospitalId: 'hsb', clinic: 'Orthopaedic specialist clinic', apptAt: appt.toISOString(),
  }, aisyah);
  check('L1 join → pending_caregiver', req.status === 'pending_caregiver', req.status);
  const o1 = await openOffer('bookingId', req.bookingId);
  check('offer goes to the group helper (Farid)', o1 && o1.data().caregiverId === farid.uid);
  await call('respondToOffer', { offerId: o1.id, accept: true }, farid);
  check('accepted → awaiting_payment', (await get(`bookings/${req.bookingId}`)).status === 'awaiting_payment');
  const paid = await call('payBooking', { bookingId: req.bookingId, method: 'fpx', package: 'saver', addons: [] }, aisyah);
  check('paid the 3-rider Saver share', paid.paidSen === 2200, `paid ${paid.paidSen}`);
  check('rider added to the group', (await get(`groups/${groupId}`)).riderBookingIds.includes(req.bookingId));
  let step;
  for (let i = 0; i < 6; i++) step = await call('advanceStep', { bookingId: req.bookingId }, farid);
  const done = await get(`bookings/${req.bookingId}`);
  check('6 steps → completed', done.status === 'completed' && step.step === 'home', done.status);
  const notes = await db.collection(`users/${aisyah.uid}/notifications`).get();
  check('guardian got step notifications', notes.docs.filter((d) => d.data().type === 'visit-step').length === 6);

  // Level 2: wheelchair patient, escort matched by certificate.
  const r2 = await call('requestBooking', {
    patientId: 'limahkow', level: 2,
    pickup: { label: 'Home', lat: 3.1885, lng: 101.5165 },
    hospitalId: 'kke', clinic: 'Dialysis', apptAt: localAt(4, 10, 30).toISOString(),
  }, aisyah);
  const o2 = await openOffer('bookingId', r2.bookingId);
  const firstCg = o2.data().caregiverId;
  const firstCerts = ((await get(`caregivers/${firstCg}`)).certificates || []).map((c) => c.type);
  check('L2 offer goes to a trained escort', firstCerts.includes('trainedEscort'), firstCerts.join(','));
  // Decline → cascade to the next qualified escort.
  const signInUid = async (uid) => signIn((await get(`users/${uid}`)).email);
  const firstUser = await signInUid(firstCg);
  await call('respondToOffer', { offerId: o2.id, accept: false }, firstUser);
  const o3 = await openOffer('bookingId', r2.bookingId);
  check('decline cascades to the next escort', o3 && o3.data().caregiverId !== firstCg);
  const second = await signInUid(o3.data().caregiverId);
  await call('respondToOffer', { offerId: o3.id, accept: true }, second);
  const p2 = await call('payBooking', { bookingId: r2.bookingId, method: 'tng' }, aisyah);
  check('L2 pays the RM 144 estimate', p2.paidSen === 14400, `paid ${p2.paidSen}`);
  check('escort can read the patient profile (access doc)',
    (await db.doc(`families/${familyId}/patients/limahkow/access/${second.uid}`).get()).exists);

  // Medicine delivery: distance fee, matched to a medicine-collection helper.
  const d = await call('requestDelivery', {
    patientId: 'zainab', pharmacyId: 'hsb', window: '8:00 – 10:00 AM',
    windowStart: localAt(2, 8, 0).toISOString(), method: 'fpx', docs: { card: true, ic: true, letter: true },
  }, aisyah);
  const del = await get(`deliveries/${d.deliveryId}`);
  check('delivery fee = RM 5 + RM 0.50/km', del.fee.totalSen === 500 + Math.round(50 * del.routeKm), `${del.routeKm} km → ${del.fee.totalSen} sen`);
  // Deliveries are paid and booked at request time (a helper is assigned immediately).
  check('delivery booked and paid at request', del.status === 'booked' && del.payment.status === 'paid' && !!del.caregiverId);

  // Security: another user cannot pay this family's booking.
  try {
    await call('payBooking', { bookingId: r2.bookingId, method: 'fpx' }, farid);
    check('caregiver cannot pay a family booking', false);
  } catch (e) {
    check('caregiver cannot pay a family booking', /another family/.test(e.message), e.message);
  }

  console.log(failures === 0 ? '\nE2E OK' : `\nE2E FAILED (${failures})`);
  process.exit(failures === 0 ? 0 : 1);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
