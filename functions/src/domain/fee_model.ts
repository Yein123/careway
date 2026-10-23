// Fee model: a linear regression learned from Malaysian market prices
// (data/market_trips.csv: Grab, Lalamove and GrabExpress rate cards with TomTom
// drive times; scripts/build-market-trips.js lists the sources). It predicts
// what one trip costs from its distance and the hour it sets off:
//   cost = base + perKm × km + perKmPeak × km in the peaks + perKmNight × km at night
// scripts/train-fee-model.js fits it and saves the model file
// src/models/fee_model.json (weights, accuracy, sources), which the server loads
// here and the Flutter app bundles as an asset, so the app shows what the
// server charges.
// Retrain on real completed trips by adding them to the CSV.

import model from '../models/fee_model.json';

export type TripKind = 'ride' | 'delivery';

export interface TripSample {
  kind: TripKind;
  km: number;
  /** Local (UTC+8) hour the trip set off. */
  hour: number;
  costSen: number;
}

export interface FeeWeights {
  base: number;
  perKm: number;
  perKmPeak: number;
  perKmNight: number;
}

export interface Leg {
  km: number;
  hour: number;
}

export const isPeak = (h: number) => (h >= 7 && h < 10) || (h >= 17 && h < 20);
export const isNight = (h: number) => h >= 22 || h < 6;

/** [1, km, km in the peaks, km at night] for one trip. */
export function features(l: Leg): number[] {
  return [1, l.km, isPeak(l.hour) ? l.km : 0, isNight(l.hour) ? l.km : 0];
}

export function predictSen(w: FeeWeights, l: Leg): number {
  const [, km, peak, night] = features(l);
  return w.base + w.perKm * km + w.perKmPeak * peak + w.perKmNight * night;
}

/** Least squares (normal equations), weights rounded to 0.01 sen. */
export function fitFeeModel(samples: TripSample[]): FeeWeights {
  const n = 4;
  const a = Array.from({ length: n }, () => new Array<number>(n + 1).fill(0));
  for (const s of samples) {
    const x = features(s);
    for (let i = 0; i < n; i++) {
      for (let j = 0; j < n; j++) a[i][j] += x[i] * x[j];
      a[i][n] += x[i] * s.costSen;
    }
  }
  // Gauss-Jordan with partial pivoting.
  for (let c = 0; c < n; c++) {
    let p = c;
    for (let r = c + 1; r < n; r++) if (Math.abs(a[r][c]) > Math.abs(a[p][c])) p = r;
    if (Math.abs(a[p][c]) < 1e-9) throw new Error('Not enough varied trips to fit the fee model.');
    [a[c], a[p]] = [a[p], a[c]];
    for (let r = 0; r < n; r++) {
      if (r === c) continue;
      const f = a[r][c] / a[c][c];
      for (let k = c; k <= n; k++) a[r][k] -= f * a[c][k];
    }
  }
  // `+ 0` turns -0 into 0.
  const w = a.map((row, i) => Math.round((row[n] / row[i]) * 100) / 100 + 0);
  return { base: w[0], perKm: w[1], perKmPeak: w[2], perKmNight: w[3] };
}

export const RIDE_WEIGHTS: FeeWeights = model.models.ride.weights;
export const DELIVERY_WEIGHTS: FeeWeights = model.models.delivery.weights;

export function parseTrips(csv: string): TripSample[] {
  return csv
    .trim()
    .split(/\r?\n/)
    .slice(1)
    .map((line) => {
      const [kind, , km, hour, costSen] = line.split(',');
      return { kind: kind as TripKind, km: Number(km), hour: Number(hour), costSen: Number(costSen) };
    });
}
