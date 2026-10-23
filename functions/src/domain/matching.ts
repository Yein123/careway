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
  /** Personalisation signals for this family and patient (all optional). */
  personal?: Personalisation;
}

/** What we know about this family and patient that makes one caregiver a better fit than another. */
export interface Personalisation {
  /** Caregiver uid → completed visits with this patient. */
  patientVisits?: Map<string, number>;
  /** Caregiver uid → average stars this family gave them. */
  familyRatings?: Map<string, number>;
  /** Skills that suit this patient without being required (e.g. dementia care). */
  preferredSkills?: Skill[];
  /** Caregiver uid → completed jobs at this hospital or pharmacy. */
  placeVisits?: Map<string, number>;
}

/** A family rating at or below this many stars keeps the caregiver out of their matches. */
export const BLOCK_AT_STARS = 2;

/** Caregivers this family rated poorly; they are not offered this family's jobs again. */
export function blockedByFamily(p: Personalisation | undefined): Set<string> {
  return new Set([...(p?.familyRatings ?? new Map<string, number>())].filter(([, s]) => s <= BLOCK_AT_STARS).map(([u]) => u));
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
  s += personalScore(c, ctx.personal);
  s -= 0.2 * haversineKm(c.home.lat, c.home.lng, ctx.pickup.lat, ctx.pickup.lng);
  s -= 0.5 * (ctx.jobsThatDay.get(c.uid) ?? 0);
  return s;
}

/**
 * Personal fit: repeat visits with this patient (+0.5 each after the first, up to +1),
 * the family's own ratings (+1 per star above 3), suitable optional skills (+1.5 each),
 * and familiarity with the place (+0.25 per job, up to +1).
 */
export function personalScore(c: Caregiver, p: Personalisation | undefined): number {
  if (!p) return 0;
  let s = 0;
  const visits = p.patientVisits?.get(c.uid) ?? 0;
  if (visits > 1) s += 0.5 * Math.min(visits - 1, 2);
  const stars = p.familyRatings?.get(c.uid);
  if (stars !== undefined) s += stars - 3;
  s += 1.5 * (p.preferredSkills ?? []).filter((k) => c.skills.includes(k)).length;
  s += 0.25 * Math.min(p.placeVisits?.get(c.uid) ?? 0, 4);
  return s;
}

/** Caregiver uids, best first; ties by uid for determinism. */
export function rankCandidates(cgs: Caregiver[], ctx: ScoreContext): string[] {
  return cgs
    .map((c) => ({ uid: c.uid, s: scoreCandidate(c, ctx) }))
    .sort((a, b) => b.s - a.s || (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0))
    .map((x) => x.uid);
}
