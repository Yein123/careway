// Caregiver matching (spec §4): hard filter, then score and rank.
import { CertType, Requirements, Skill } from './needs';
import { haversineKm } from './pricing';

export const SERVICE_RADIUS_KM = 25;

export interface LatLng {
  lat: number;
  lng: number;
}

export interface Interval {
  start: Date;
  end: Date;
}

export interface Certificate {
  type: CertType;
  verified: boolean;
  expiresAt: Date;
}

export interface Caregiver {
  uid: string;
  displayName: string;
  phone?: string;
  onDuty: boolean;
  rating: number;
  languages: string[];
  skills: Skill[];
  certificates: Certificate[];
  home: LatLng;
}

export interface FilterContext {
  apptAt: Date;
  pickup: LatLng;
  /** Time the job occupies the caregiver. */
  window: Interval;
  /** Caregiver uid → intervals already taken (accepted jobs, open offers). */
  busy: Map<string, Interval[]>;
}

export interface ScoreContext {
  pickup: LatLng;
  patientHistory: Set<string>;
  jobsThatDay: Map<string, number>;
  /** Preferred (not required) language. */
  language?: string;
}

const overlaps = (a: Interval, b: Interval) => a.start < b.end && b.start < a.end;

export function hasValidCert(c: Caregiver, type: CertType, on: Date): boolean {
  return c.certificates.some((x) => x.type === type && x.verified && x.expiresAt > on);
}

export function qualifies(c: Caregiver, req: Requirements, apptAt: Date): boolean {
  return (
    req.skills.every((s) => c.skills.includes(s)) &&
    req.certs.every((t) => hasValidCert(c, t, apptAt)) &&
    (!req.language || c.languages.includes(req.language))
  );
}

export function filterCandidates(cgs: Caregiver[], req: Requirements, ctx: FilterContext): Caregiver[] {
  return cgs.filter(
    (c) =>
      c.onDuty &&
      qualifies(c, req, ctx.apptAt) &&
      haversineKm(c.home.lat, c.home.lng, ctx.pickup.lat, ctx.pickup.lng) <= SERVICE_RADIUS_KM &&
      !(ctx.busy.get(c.uid) ?? []).some((b) => overlaps(b, ctx.window)),
  );
}

export function scoreCandidate(c: Caregiver, ctx: ScoreContext): number {
  let s = c.rating;
  if (ctx.language && c.languages.includes(ctx.language)) s += 3;
  if (ctx.patientHistory.has(c.uid)) s += 2;
  s -= 0.2 * haversineKm(c.home.lat, c.home.lng, ctx.pickup.lat, ctx.pickup.lng);
  s -= 0.5 * (ctx.jobsThatDay.get(c.uid) ?? 0);
  return s;
}

/** Caregiver uids, best first; ties by uid for determinism. */
export function rankCandidates(cgs: Caregiver[], ctx: ScoreContext): string[] {
  return cgs
    .map((c) => ({ uid: c.uid, s: scoreCandidate(c, ctx) }))
    .sort((a, b) => b.s - a.s || (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0))
    .map((x) => x.uid);
}
