import { deriveRequirements, level1Allowed, NeedsInput } from '../src/domain/needs';

const req = (o: Partial<NeedsInput> = {}) =>
  deriveRequirements({ level: 1, mobility: 'independent', patientAge: 70, addons: [], ...o });

test('basic level 1 needs only first aid', () => {
  const r = req();
  expect(r.skills).toEqual([]);
  expect(r.certs).toEqual(['firstAid']);
  expect(r.language).toBeUndefined();
});

test('level 2 needs a trained escort', () => {
  expect(req({ level: 2 }).certs).toEqual(expect.arrayContaining(['firstAid', 'trainedEscort']));
});

test('transfer needs transfer skill and patient handling cert', () => {
  const r = req({ level: 2, mobility: 'transfer' });
  expect(r.skills).toContain('transfer');
  expect(r.certs).toContain('patientHandling');
});

test('wheelchair mobility or add-on needs wheelchair skill', () => {
  expect(req({ mobility: 'wheelchair' }).skills).toContain('wheelchair');
  expect(req({ addons: ['wheelchairOnArrival'] }).skills).toContain('wheelchair');
});

test('child needs paediatric skill and cert', () => {
  const r = req({ level: 2, patientAge: 9 });
  expect(r.skills).toContain('paediatric');
  expect(r.certs).toContain('paediatric');
});

test('add-ons map to skills and language', () => {
  expect(req({ addons: ['consultSitIn'] }).skills).toContain('consultSitIn');
  expect(req({ addons: ['medicineCollection'] }).skills).toContain('medicineCollection');
  expect(req({ delivery: true }).skills).toContain('medicineCollection');
  expect(req({ addons: ['language'], language: 'Tamil' }).language).toBe('Tamil');
});

test('language without the language add-on is not a requirement', () => {
  expect(req({ language: 'Tamil' }).language).toBeUndefined();
  expect(req({ level: 2, language: 'Tamil' }).language).toBeUndefined();
});

test('level 1 is not allowed for transfer or children', () => {
  expect(level1Allowed('transfer', 70)).toBe(false);
  expect(level1Allowed('stick', 17)).toBe(false);
  expect(level1Allowed('wheelchair', 72)).toBe(true);
});
