// Pricing rules (spec §5), integer sen. Mirrors lib/domain/pricing.dart;
// this copy is the authority for charges.

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
export const PRIVATE_RIDE_SEN = 2400;
export const DEFAULT_ESCORT_HOURS = 4;

export const DELIVERY_BASE_SEN = 500;
export const DELIVERY_PER_KM_SEN = 50;
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

export function escortEstimateSen(hours = DEFAULT_ESCORT_HOURS): number {
  return Math.round(ESCORT_HOURLY_SEN * hours) + PRIVATE_RIDE_SEN;
}

/** Actual minutes rounded up to 30-minute steps, plus the private ride. */
export function escortFinalSen(minutes: number): number {
  return Math.ceil(minutes / 30) * (ESCORT_HOURLY_SEN / 2) + PRIVATE_RIDE_SEN;
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

export function deliveryFee(km: number): { baseSen: number; distanceSen: number; totalSen: number } {
  const distanceSen = Math.round(DELIVERY_PER_KM_SEN * km);
  return { baseSen: DELIVERY_BASE_SEN, distanceSen, totalSen: DELIVERY_BASE_SEN + distanceSen };
}
