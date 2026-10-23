// Pricing rules (spec §5), integer sen. Mirrors lib/domain/pricing.dart;
// this copy is the authority for charges.
import { DELIVERY_WEIGHTS, features, FeeWeights, RIDE_WEIGHTS, TripKind } from './fee_model';

export type GroupPackage = 'saver' | 'flex';
export type AddonId = 'language' | 'consultSitIn' | 'medicineCollection' | 'visitSummary' | 'wheelchairOnArrival';

export const ADDON_SEN: Record<AddonId, number> = {
  language: 800,
  consultSitIn: 1000,
  medicineCollection: 500,
  visitSummary: 500,
  wheelchairOnArrival: 500,
};

export const ADDON_LABEL: Record<AddonId, string> = {
  language: 'Language help',
  consultSitIn: 'Consult sit-in',
  medicineCollection: 'Medicine collection',
  visitSummary: 'Visit summary',
  wheelchairOnArrival: 'Wheelchair on arrival',
};

export const PACKAGE_LABEL: Record<GroupPackage, string> = { saver: 'Group Saver', flex: 'Group Flex' };

export const GROUP_CAPACITY = 3;
const SHARES: Record<GroupPackage, number[]> = { saver: [4000, 3000, 2200], flex: [5500, 4500, 3500] };

export const ESCORT_HOURLY_SEN = 3000;
/** Fallback private ride price for bookings made before rides were priced by route. */
export const PRIVATE_RIDE_SEN = 2400;
export const DEFAULT_ESCORT_HOURS = 4;

export const ROAD_FACTOR = 1.3;

export function isAddon(x: unknown): x is AddonId {
  return typeof x === 'string' && x in ADDON_SEN;
}

export function groupShareSen(pkg: GroupPackage, riders: number): number {
  if (!Number.isInteger(riders) || riders < 1 || riders > GROUP_CAPACITY) {
    throw new RangeError(`riders must be 1..${GROUP_CAPACITY}, got ${riders}`);
  }
  return SHARES[pkg][riders - 1];
}

export function addonsSen(addons: AddonId[]): number {
  return addons.reduce((t, a) => t + ADDON_SEN[a], 0);
}

export function escortEstimateSen(hours = DEFAULT_ESCORT_HOURS, rideSen = PRIVATE_RIDE_SEN): number {
  return Math.round(ESCORT_HOURLY_SEN * hours) + rideSen;
}

/** Actual minutes rounded up to 30-minute steps, plus the private ride. */
export function escortFinalSen(minutes: number, rideSen = PRIVATE_RIDE_SEN): number {
  return Math.ceil(minutes / 30) * (ESCORT_HOURLY_SEN / 2) + rideSen;
}

/** Refund per rider at lock: everyone ends at the final-size share, never above what they paid. */
export function settleGroupRefunds(pkg: GroupPackage, paidShares: number[]): number[] {
  if (paidShares.length === 0) return [];
  const finalShare = groupShareSen(pkg, paidShares.length);
  return paidShares.map((p) => Math.max(0, p - finalShare));
}

export function cancelOutcome(o: { pkg: GroupPackage | null; level: number; paidSen: number; afterLock: boolean }): {
  refundSen: number;
  creditSen: number;
} {
  if (!o.afterLock) return { refundSen: o.paidSen, creditSen: 0 };
  if (o.level === 1 && o.pkg === 'saver') return { refundSen: 0, creditSen: o.paidSen };
  return { refundSen: Math.floor(o.paidSen / 2), creditSen: 0 };
}

export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const r = 6371.0088;
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.asin(Math.sqrt(a));
}

export function routeKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  return Math.round(2 * haversineKm(lat1, lng1, lat2, lng2) * ROAD_FACTOR * 10) / 10;
}

/** One-way road distance between two points, rounded to 0.1 km. */
export function legKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  return Math.round(haversineKm(lat1, lng1, lat2, lng2) * ROAD_FACTOR * 10) / 10;
}

// Route costs come from the fee model (fee_model.ts), trained on past trips.
export interface RouteLeg {
  km: number;
  departAt: Date;
}

export interface RouteCost {
  km: number;
  baseSen: number;
  distanceSen: number;
  /** Peak-hour surcharge or night discount the model learned. */
  trafficSen: number;
  totalSen: number;
}

/**
 * Floor under a model estimate per trip: Grab's RM5 minimum fare; for a medicine
 * run, Lalamove's RM5 base plus RM10 waiting for the pharmacy counter.
 */
export const MIN_FARE_SEN: Record<TripKind, number> = { ride: 500, delivery: 1500 };
const WEIGHTS: Record<TripKind, FeeWeights> = { ride: RIDE_WEIGHTS, delivery: DELIVERY_WEIGHTS };

/** Local (UTC+8) hour of [at]. */
export function mytHour(at: Date): number {
  return (at.getUTCHours() + 8) % 24;
}

/** Each leg is priced as its own trip by the model, then the parts are summed. */
export function routeCost(legs: RouteLeg[], kind: TripKind): RouteCost {
  const w = WEIGHTS[kind];
  const c = { km: 0, baseSen: 0, distanceSen: 0, trafficSen: 0, totalSen: 0 };
  for (const l of legs) {
    const [, km, peakKm, nightKm] = features({ km: l.km, hour: mytHour(l.departAt) });
    const distanceSen = Math.round(w.perKm * km);
    const trafficSen = Math.round(w.perKmPeak * peakKm + w.perKmNight * nightKm);
    // A short trip is topped up to the minimum fare through the base line.
    const baseSen = Math.max(Math.round(w.base), MIN_FARE_SEN[kind] - distanceSen - trafficSen);
    c.km += km;
    c.baseSen += baseSen;
    c.distanceSen += distanceSen;
    c.trafficSen += trafficSen;
    c.totalSen += baseSen + distanceSen + trafficSen;
  }
  return { ...c, km: Math.round(c.km * 10) / 10 };
}

/** Level 2 private ride: pickup → hospital an hour before the appointment, back three hours after. */
export function privateRideCost(pickup: { lat: number; lng: number }, hospital: { lat: number; lng: number }, apptAt: Date): RouteCost {
  const km = legKm(pickup.lat, pickup.lng, hospital.lat, hospital.lng);
  return routeCost(
    [
      { km, departAt: new Date(apptAt.getTime() - 3600_000) },
      { km, departAt: new Date(apptAt.getTime() + 3 * 3600_000) },
    ],
    'ride',
  );
}

/** Medicine run fee for a [km] round trip starting at [departAt]. */
export function deliveryFee(km: number, departAt: Date): RouteCost {
  return routeCost([{ km, departAt }], 'delivery');
}
