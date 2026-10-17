import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2';
import { onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { db } from './db';
import { requireAuth } from './errors';
import { requestBookingLogic } from './booking/request';
import { respondToOfferLogic } from './booking/respond';
import { expireOffersLogic } from './booking/expire';

initializeApp();
setGlobalOptions({ region: 'asia-southeast1' });

export { ping } from './ping';

export const requestBooking = onCall((req) => requestBookingLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const respondToOffer = onCall((req) => respondToOfferLogic(db(), requireAuth(req.auth), req.data, new Date()));

export const expireOffers = onSchedule({ schedule: 'every 1 minutes', timeZone: 'Asia/Kuala_Lumpur' }, async () => {
  await expireOffersLogic(db(), new Date());
});
