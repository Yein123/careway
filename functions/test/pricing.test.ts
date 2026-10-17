import {
  addonsSen,
  cancelOutcome,
  deliveryFee,
  escortEstimateSen,
  escortFinalSen,
  groupShareSen,
  haversineKm,
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
  test('fee is RM 5 base plus RM 0.50 per km', () => {
    expect(deliveryFee(10)).toEqual({ baseSen: 500, distanceSen: 500, totalSen: 1000 });
    expect(deliveryFee(0).totalSen).toBe(500);
  });
});
