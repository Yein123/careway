import { blockedByFamily, Caregiver, filterCandidates, personalScore, rankCandidates, scoreCandidate } from '../src/domain/matching';
import { preferredSkills, Requirements } from '../src/domain/needs';

const appt = new Date('2026-10-26T01:00:00Z');
const future = new Date('2028-01-01T00:00:00Z');
const past = new Date('2026-01-01T00:00:00Z');
const pickup = { lat: 3.187, lng: 101.518 };

function cg(uid: string, o: Partial<Caregiver> = {}): Caregiver {
  return {
    uid,
    displayName: uid,
    onDuty: true,
    rating: 4.8,
    languages: ['Malay', 'English'],
    skills: ['wheelchair', 'transfer', 'consultSitIn', 'medicineCollection'],
    certificates: [
      { type: 'firstAid', verified: true, expiresAt: future },
      { type: 'patientHandling', verified: true, expiresAt: future },
      { type: 'trainedEscort', verified: true, expiresAt: future },
    ],
    home: { lat: 3.18, lng: 101.51 },
    ...o,
  };
}

const ctx = { apptAt: appt, pickup, window: { start: new Date(appt.getTime() - 3600e3), end: new Date(appt.getTime() + 4 * 3600e3) }, busy: new Map() };

const transferReq: Requirements = { skills: ['transfer'], certs: ['firstAid', 'patientHandling'] };

test('caregiver missing a required skill is excluded', () => {
  const out = filterCandidates([cg('a', { skills: ['wheelchair'] }), cg('b')], transferReq, ctx);
  expect(out.map((c) => c.uid)).toEqual(['b']);
});

test('expired or unverified certificate is excluded', () => {
  const expired = cg('a', { certificates: [{ type: 'firstAid', verified: true, expiresAt: past }, { type: 'patientHandling', verified: true, expiresAt: future }] });
  const unverified = cg('c', { certificates: [{ type: 'firstAid', verified: false, expiresAt: future }, { type: 'patientHandling', verified: true, expiresAt: future }] });
  const out = filterCandidates([expired, unverified, cg('b')], transferReq, ctx);
  expect(out.map((c) => c.uid)).toEqual(['b']);
});

test('off-duty caregiver is excluded', () => {
  expect(filterCandidates([cg('a', { onDuty: false })], transferReq, ctx)).toEqual([]);
});

test('caregiver outside the 25 km service radius is excluded', () => {
  expect(filterCandidates([cg('far', { home: { lat: 2.7, lng: 101.9 } })], transferReq, ctx)).toEqual([]);
});

test('overlapping busy interval is excluded', () => {
  const busy = new Map([['a', [{ start: new Date(appt.getTime() + 3600e3), end: new Date(appt.getTime() + 2 * 3600e3) }]]]);
  const out = filterCandidates([cg('a'), cg('b')], transferReq, { ...ctx, busy });
  expect(out.map((c) => c.uid)).toEqual(['b']);
});

test('hard language requirement filters', () => {
  const out = filterCandidates([cg('a'), cg('t', { languages: ['Tamil', 'English'] })], { skills: [], certs: ['firstAid'], language: 'Tamil' }, ctx);
  expect(out.map((c) => c.uid)).toEqual(['t']);
});

test('preferred language outranks an otherwise equal caregiver', () => {
  const sctx = { pickup, patientHistory: new Set<string>(), jobsThatDay: new Map<string, number>(), language: 'Tamil' };
  const ranked = rankCandidates([cg('a'), cg('t', { languages: ['Tamil'] })], sctx);
  expect(ranked).toEqual(['t', 'a']);
});

test('patient history outranks an otherwise equal caregiver', () => {
  const sctx = { pickup, patientHistory: new Set(['b']), jobsThatDay: new Map<string, number>() };
  expect(rankCandidates([cg('a'), cg('b')], sctx)).toEqual(['b', 'a']);
});

test('score formula', () => {
  const s = scoreCandidate(cg('x', { home: pickup, rating: 4.5 }), {
    pickup,
    patientHistory: new Set(['x']),
    jobsThatDay: new Map([['x', 2]]),
    language: 'Malay',
  });
  expect(s).toBeCloseTo(3 + 2 + 4.5 - 0 - 1, 5);
});

test('ties break by uid', () => {
  const sctx = { pickup, patientHistory: new Set<string>(), jobsThatDay: new Map<string, number>() };
  expect(rankCandidates([cg('b'), cg('a')], sctx)).toEqual(['a', 'b']);
});

describe('personalised matching', () => {
  const sctx = (personal: object) => ({ pickup, patientHistory: new Set<string>(), jobsThatDay: new Map<string, number>(), personal });

  test('a caregiver the family rated highly outranks an otherwise equal one', () => {
    expect(rankCandidates([cg('a'), cg('b')], sctx({ familyRatings: new Map([['b', 5]]) }))).toEqual(['b', 'a']);
  });

  test('a caregiver with a suitable optional skill outranks one without', () => {
    const ranked = rankCandidates([cg('a'), cg('d', { skills: ['dementia'] })], sctx({ preferredSkills: ['dementia'] }));
    expect(ranked).toEqual(['d', 'a']);
  });

  test('repeat visits and place familiarity add up, capped', () => {
    expect(personalScore(cg('x'), { patientVisits: new Map([['x', 1]]) })).toBe(0);
    expect(personalScore(cg('x'), { patientVisits: new Map([['x', 2]]) })).toBe(0.5);
    expect(personalScore(cg('x'), { patientVisits: new Map([['x', 9]]) })).toBe(1);
    expect(personalScore(cg('x'), { placeVisits: new Map([['x', 2]]) })).toBe(0.5);
    expect(personalScore(cg('x'), { placeVisits: new Map([['x', 10]]) })).toBe(1);
  });

  test('family rating moves the score by a point per star from 3', () => {
    expect(personalScore(cg('x'), { familyRatings: new Map([['x', 4.5]]) })).toBe(1.5);
    expect(personalScore(cg('x'), { familyRatings: new Map([['x', 2.5]]) })).toBe(-0.5);
  });

  test('caregivers the family rated 2 stars or less are blocked', () => {
    expect([...blockedByFamily({ familyRatings: new Map([['a', 2], ['b', 2.5], ['c', 1]]) })].sort()).toEqual(['a', 'c']);
    expect(blockedByFamily(undefined).size).toBe(0);
  });

  test('preferred skills come from conditions, extra help and mobility', () => {
    expect(preferredSkills({ conditions: 'Early Alzheimer', mobility: 'stick' }).sort()).toEqual(['dementia', 'wheelchair']);
    expect(preferredSkills({ extraHelp: ['Memory or confusion', 'Translate for doctor'] }).sort()).toEqual(['consultSitIn', 'dementia']);
    expect(preferredSkills({})).toEqual([]);
  });
});
