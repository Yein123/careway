import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { setGlobalOptions } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { db } from './db';
import { requireAdmin, requireAuth } from './errors';
import { requestBookingLogic } from './booking/request';
import { autoAcceptBookingLogic, respondToOfferLogic } from './booking/respond';
import { expireOffersLogic } from './booking/expire';
import { payBookingLogic } from './booking/pay';
import { cancelBookingLogic } from './booking/cancel';
import { lockGroupsLogic } from './booking/lock';
import { advanceStepLogic, submitSummaryLogic } from './booking/steps';
import { requestRideHomeLogic } from './booking/ride';
import { requestDeliveryLogic } from './delivery/request';
import { payDeliveryLogic } from './delivery/pay';
import { progressDeliveriesLogic } from './delivery/progress';
import { seedDemoLogic } from './seed';
import {
  adminAdvanceDeliveryLogic,
  adminAdvanceStepLogic,
  adminLockGroupLogic,
  adminNotFoundLogic,
  adminResetLogic,
  adminRespondOfferLogic,
} from './admin/admin';

initializeApp();
setGlobalOptions({ region: 'asia-southeast1' });

export { ping } from './ping';

export const requestBooking = onCall((req) => requestBookingLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const respondToOffer = onCall((req) => respondToOfferLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const autoAcceptBooking = onCall((req) => autoAcceptBookingLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const expireOffers = onSchedule({ schedule: 'every 1 minutes', timeZone: 'Asia/Kuala_Lumpur' }, async () => {
  await expireOffersLogic(db(), new Date());
});

export const payBooking = onCall((req) => payBookingLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const cancelBooking = onCall((req) => cancelBookingLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const lockGroups = onSchedule({ schedule: 'every 5 minutes', timeZone: 'Asia/Kuala_Lumpur' }, async () => {
  await lockGroupsLogic(db(), new Date());
});

export const advanceStep = onCall((req) => advanceStepLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const requestRideHome = onCall((req) => requestRideHomeLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const submitSummary = onCall((req) => submitSummaryLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const requestDelivery = onCall((req) => requestDeliveryLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const payDelivery = onCall((req) => payDeliveryLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const progressDeliveries = onSchedule({ schedule: 'every 1 minutes', timeZone: 'Asia/Kuala_Lumpur' }, async () => {
  await progressDeliveriesLogic(db(), new Date());
});

/** Demo data: emulator only, or a caller with the `admin` custom claim. */
export const seedDemo = onCall((req) => {
  const allowed = process.env.FUNCTIONS_EMULATOR === 'true' || req.auth?.token?.admin === true;
  if (!allowed) throw new HttpsError('permission-denied', 'Demo data can only be loaded in the emulator.');
  return seedDemoLogic(db(), getAuth(), new Date());
});

const adminCall = (fn: (data: unknown, now: Date) => Promise<unknown>) =>
  onCall((req) => {
    requireAdmin(req.auth);
    return fn(req.data, new Date());
  });

export const adminReset = onCall((req) => {
  requireAdmin(req.auth);
  return adminResetLogic(db(), getAuth(), new Date());
});
export const adminRespondOffer = adminCall((d, now) => adminRespondOfferLogic(db(), d, now));
export const adminNotFound = adminCall((d, now) => adminNotFoundLogic(db(), d, now));
export const adminLockGroup = adminCall((d, now) => adminLockGroupLogic(db(), d, now));
export const adminAdvanceDelivery = adminCall((d, now) => adminAdvanceDeliveryLogic(db(), d, now));
export const adminAdvanceStep = adminCall((d, now) => adminAdvanceStepLogic(db(), d, now));
export { claimPushToken, releasePushToken, onNotificationCreated } from './push';
