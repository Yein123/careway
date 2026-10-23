// Builds data/market_trips.csv: what Malaysian services publicly charge for the
// trips CareWay makes, at every hour of the day. The fee model is trained on it.
//
// Sources (checked October 2026):
// - Grab Klang Valley e-hailing: RM2 base + RM0.25/km + RM0.43/min, RM5 minimum.
//   https://ringgitplus.com/en/blog/en/blog/apps/grab-implements-new-e-hailing-fares-rides-may-cost-more-during-peak-hours.html
//   https://www.thestar.com.my/tech/tech-news/2023/01/16/grab-updates-fee-structure-rides-during-peak-hours-to-cost-more
// - Drive time, TomTom Traffic Index 2025, Kuala Lumpur: 10 km takes 17 min 55 s on
//   average (33.5 km/h), morning rush 28.8 km/h, evening rush 22.9 km/h, morning
//   congestion 68.4% (so free flow is about 48.5 km/h, used at night).
//   https://www.tomtom.com/traffic-index/kuala-lumpur-traffic
// - Lalamove motorcycle: from RM5 + RM0.70/km; waiting RM2 per 5 min after 10 free.
//   https://blog.easyparcel.com/my/lalamove-rate/
//   https://www.lalamove.com/en-my/all-vehicle-pricing-detail
// - GrabExpress bike, Klang Valley: RM1/km up to 20 km, RM2/km beyond, RM10 minimum.
//   https://ringgitplus.com/en/blog/personal-finance-news/grabexpress-delivery-service-now-available-in-the-greater-klang-valley-area.html
// - Pharmacy wait: the MOH KPI is 30 minutes for 95% of prescriptions; Hospital Ampang
//   measured a 34.8-minute mean, so a medicine run waits 35 minutes at the counter.
//   https://www.medrxiv.org/content/10.1101/2022.02.28.22271668.full.pdf
//   https://e-mjm.org/2024/v79s5/PP-40.pdf
// For comparison only (not a same-day courier, so not in the data): MOH's Ubat
// Melalui Pos was RM5.70 in the Peninsula and is free via MyUBAT from 1 Oct 2026.
//   https://www.malaymail.com/news/malaysia/2026/09/30/what-is-ump-how-malaysias-new-free-medicine-delivery-service-works-and-how-to-apply/236993
//
// Run from functions/: npm run train:fees (builds this file, then trains).
const fs = require('fs');
const path = require('path');
const { HOSPITALS, PICKUP_POINTS } = require('../lib/places');
const { legKm } = require('../lib/domain/pricing');

/** km/h by local hour, from the TomTom figures above. */
function speedKmh(h) {
  if (h >= 7 && h < 10) return 28.8;
  if (h >= 17 && h < 20) return 22.9;
  if (h >= 22 || h < 6) return 48.5;
  return 33.5;
}
const minutes = (km, h) => (km / speedKmh(h)) * 60;

const PHARMACY_WAIT_MIN = 35;
const lalamoveWaitSen = (min) => Math.ceil(Math.max(0, min - 10) / 5) * 200;

const grabCar = (km, h) => Math.max(500, 200 + 25 * km + 43 * minutes(km, h));
const lalamoveBike = (km) => 500 + 70 * km + lalamoveWaitSen(PHARMACY_WAIT_MIN);
const grabExpressBike = (km) =>
  Math.max(1000, km <= 20 ? 100 * km : 2000 + 200 * (km - 20)) + lalamoveWaitSen(PHARMACY_WAIT_MIN);

// One-way legs between CareWay's pickup points and hospitals, plus a spread of
// longer trips across the Klang Valley.
const legs = new Set();
for (const p of PICKUP_POINTS) for (const h of HOSPITALS) legs.add(legKm(p.lat, p.lng, h.lat, h.lng));
for (let km = 3; km <= 30; km += 3) legs.add(km);

const rows = ['kind,source,km,hour,costSen'];
for (const km of [...legs].sort((a, b) => a - b)) {
  for (let hour = 0; hour < 24; hour++) {
    rows.push(`ride,grab-car,${km},${hour},${Math.round(grabCar(km, hour))}`);
    // A medicine run is home → pharmacy → home.
    const round = Math.round(2 * km * 10) / 10;
    rows.push(`delivery,lalamove-bike,${round},${hour},${Math.round(lalamoveBike(round))}`);
    rows.push(`delivery,grabexpress-bike,${round},${hour},${Math.round(grabExpressBike(round))}`);
  }
}
fs.writeFileSync(path.join(__dirname, '..', 'data', 'market_trips.csv'), rows.join('\n') + '\n');

// Where each quote's prices come from, saved into the model file by the trainer.
const SOURCES = {
  'grab-car': [
    'https://ringgitplus.com/en/blog/en/blog/apps/grab-implements-new-e-hailing-fares-rides-may-cost-more-during-peak-hours.html',
    'https://www.tomtom.com/traffic-index/kuala-lumpur-traffic',
  ],
  'lalamove-bike': [
    'https://blog.easyparcel.com/my/lalamove-rate/',
    'https://www.lalamove.com/en-my/all-vehicle-pricing-detail',
    'https://e-mjm.org/2024/v79s5/PP-40.pdf',
  ],
  'grabexpress-bike': [
    'https://ringgitplus.com/en/blog/personal-finance-news/grabexpress-delivery-service-now-available-in-the-greater-klang-valley-area.html',
    'https://www.lalamove.com/en-my/all-vehicle-pricing-detail',
    'https://e-mjm.org/2024/v79s5/PP-40.pdf',
  ],
};
fs.writeFileSync(path.join(__dirname, '..', 'data', 'market_sources.json'), JSON.stringify(SOURCES, null, 2) + '\n');
console.log(`${rows.length - 1} market quotes`);
