import fs from 'fs';
import path from 'path';
import { DELIVERY_WEIGHTS, fitFeeModel, isNight, isPeak, parseTrips, predictSen, RIDE_WEIGHTS } from '../src/domain/fee_model';
import {
  addonsSen,
  cancelOutcome,
  deliveryFee,
  escortEstimateSen,
  escortFinalSen,
  groupShareSen,
  haversineKm,
  legKm,
  MIN_FARE_SEN,
  privateRideCost,
  routeCost,
  routeKm,
  settleGroupRefunds,
} from '../src/domain/pricing';

describe('groupShareSen', () => {
  test('saver share falls as riders join', () => {
    expect([1, 2, 3].map((n) => groupShareSen('saver', n))).toEqual([4000, 3000, 2200]);
  });
  test('flex shares', () => {
    expect([1, 2, 3].map((n) => groupShareSen('flex', n))).toEqual([5500, 4500, 3500]);
  });
  test('rider count outside 1..3 throws', () => {
    expect(() => groupShareSen('saver', 4)).toThrow();
    expect(() => groupShareSen('saver', 0)).toThrow();
  });
});

test('addonsSen sums add-on prices', () => {
  expect(addonsSen(['language', 'consultSitIn'])).toBe(1800);
  expect(addonsSen([])).toBe(0);
});

test('escort estimate is 4 hours plus private ride', () => {
  expect(escortEstimateSen()).toBe(14400);
});

test('escort final rounds up to 30-minute steps', () => {
  expect(escortFinalSen(190)).toBe(3 * 3000 + 1500 + 2400);
  expect(escortFinalSen(180)).toBe(9000 + 2400);
  expect(escortEstimateSen(4, 2500)).toBe(14500);
  expect(escortFinalSen(180, 2500)).toBe(9000 + 2500);
});

test('settle worked example: 40/30/22 -> refunds 18/8/0', () => {
  expect(settleGroupRefunds('saver', [4000, 3000, 2200])).toEqual([1800, 800, 0]);
});

test('settle after cancel never charges more', () => {
  const r = settleGroupRefunds('saver', [4000, 3000]);
  expect(r).toEqual([1000, 0]);
  expect(r.every((x) => x >= 0)).toBe(true);
});

describe('cancelOutcome', () => {
  test('before lock is a full refund', () => {
    expect(cancelOutcome({ pkg: 'saver', level: 1, paidSen: 2200, afterLock: false })).toEqual({ refundSen: 2200, creditSen: 0 });
  });
  test('saver after lock becomes credit', () => {
    expect(cancelOutcome({ pkg: 'saver', level: 1, paidSen: 2200, afterLock: true })).toEqual({ refundSen: 0, creditSen: 2200 });
  });
  test('flex after lock refunds 50%', () => {
    expect(cancelOutcome({ pkg: 'flex', level: 1, paidSen: 3500, afterLock: true })).toEqual({ refundSen: 1750, creditSen: 0 });
  });
  test('level 2 after lock refunds 50%', () => {
    expect(cancelOutcome({ pkg: null, level: 2, paidSen: 14400, afterLock: true })).toEqual({ refundSen: 7200, creditSen: 0 });
  });
});

describe('delivery', () => {
  test('haversine one degree at the equator', () => {
    expect(Math.abs(haversineKm(0, 0, 0, 1) - 111.19)).toBeLessThan(0.01);
  });
  test('route is round trip with road factor, 1 decimal', () => {
    expect(routeKm(0, 0, 0, 1)).toBe(289.1);
    expect(routeKm(3.1, 101.5, 3.1, 101.5)).toBe(0);
  });
  test('fee is the delivery model on the round trip', () => {
    const w = DELIVERY_WEIGHTS;
    // 11 AM local: off peak.
    expect(deliveryFee(10, new Date('2026-10-26T03:00:00Z'))).toEqual({
      km: 10, baseSen: Math.round(w.base), distanceSen: Math.round(w.perKm * 10), trafficSen: 0,
      totalSen: Math.round(w.base) + Math.round(w.perKm * 10),
    });
  });
  test('a very short run is topped up to the minimum fee', () => {
    expect(deliveryFee(0, new Date('2026-10-26T03:00:00Z')).totalSen).toBe(MIN_FARE_SEN.delivery);
  });
});

describe('fee model', () => {
  const at = (mytHour: number) => new Date(Date.UTC(2026, 9, 26, (mytHour + 16) % 24));
  const trips = parseTrips(fs.readFileSync(path.join(__dirname, '..', 'data', 'market_trips.csv'), 'utf8'));

  test('the model file holds what training on the market quotes gives', () => {
    expect(fitFeeModel(trips.filter((t) => t.kind === 'ride'))).toEqual(RIDE_WEIGHTS);
    expect(fitFeeModel(trips.filter((t) => t.kind === 'delivery'))).toEqual(DELIVERY_WEIGHTS);
  });
  test('fitting recovers a known linear rule', () => {
    const rule = (km: number, h: number) => 300 + 60 * km + (isPeak(h) ? 25 * km : 0) - (isNight(h) ? 5 * km : 0);
    const samples = [];
    for (let h = 0; h < 24; h++) for (const km of [3, 11, 27]) samples.push({ kind: 'ride' as const, km, hour: h, costSen: rule(km, h) });
    expect(fitFeeModel(samples)).toEqual({ base: 300, perKm: 60, perKmPeak: 25, perKmNight: -5 });
  });
  test('ride estimates are within RM 1 of the Grab quotes on average', () => {
    const err = trips.filter((t) => t.kind === 'ride').map((t) => Math.abs(predictSen(RIDE_WEIGHTS, t) - t.costSen));
    expect(err.reduce((a, b) => a + b, 0) / err.length).toBeLessThan(100);
  });
  test('medicine run fees sit within RM 3 of the range Lalamove and GrabExpress quote', () => {
    const quotes = new Map<number, number[]>();
    for (const t of trips.filter((x) => x.kind === 'delivery')) quotes.set(t.km, [...(quotes.get(t.km) ?? []), t.costSen]);
    for (const [km, q] of quotes) {
      const fee = deliveryFee(km, at(13)).totalSen;
      expect(fee).toBeGreaterThanOrEqual(Math.min(...q) - 300);
      expect(fee).toBeLessThanOrEqual(Math.max(...q) + 300);
    }
  });
  test('the same route costs more in the morning peak than at midday or night', () => {
    const leg = (h: number) => routeCost([{ km: 10, departAt: at(h) }], 'ride').totalSen;
    expect(leg(8)).toBeGreaterThan(leg(13));
    expect(leg(13)).toBeGreaterThan(leg(23));
  });
  test('route cost sums the legs, splitting the traffic part out', () => {
    const c = routeCost([{ km: 10, departAt: at(8) }, { km: 10, departAt: at(13) }], 'ride');
    expect(c.km).toBe(20);
    expect(c.distanceSen).toBe(Math.round(RIDE_WEIGHTS.perKm * 20));
    expect(c.baseSen).toBe(2 * Math.round(RIDE_WEIGHTS.base));
    expect(c.trafficSen).toBe(Math.round(RIDE_WEIGHTS.perKmPeak * 10));
    expect(c.totalSen).toBe(c.baseSen + c.distanceSen + c.trafficSen);
  });
  test('private ride goes an hour before the appointment and back three hours after', () => {
    const pickup = { lat: 3.187, lng: 101.518 };
    const hsb = { lat: 3.2196, lng: 101.5826 };
    const km = legKm(pickup.lat, pickup.lng, hsb.lat, hsb.lng);
    expect(privateRideCost(pickup, hsb, at(9))).toEqual(routeCost([{ km, departAt: at(8) }, { km, departAt: at(12) }], 'ride'));
  });
});
