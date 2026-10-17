// Patient → caregiver requirements (spec §4). Mirrors lib/domain/needs.dart.
import { AddonId } from './pricing';

export type Mobility = 'independent' | 'stick' | 'wheelchair' | 'transfer';
export type Skill = 'wheelchair' | 'transfer' | 'consultSitIn' | 'paediatric' | 'dementia' | 'medicineCollection';
export type CertType = 'firstAid' | 'patientHandling' | 'trainedEscort' | 'paediatric';

export interface NeedsInput {
  level: number;
  mobility: Mobility;
  patientAge: number;
  addons: AddonId[];
  language?: string;
  delivery?: boolean;
}

export interface Requirements {
  skills: Skill[];
  certs: CertType[];
  /** Hard language requirement (only from the Language help add-on). */
  language?: string;
}

export function deriveRequirements(i: NeedsInput): Requirements {
  const skills = new Set<Skill>();
  const certs = new Set<CertType>(['firstAid']);
  if (i.level === 2) certs.add('trainedEscort');
  if (i.mobility === 'transfer') {
    skills.add('transfer');
    certs.add('patientHandling');
  }
  if (i.mobility === 'wheelchair' || i.addons.includes('wheelchairOnArrival')) skills.add('wheelchair');
  if (i.patientAge < 18) {
    skills.add('paediatric');
    certs.add('paediatric');
  }
  if (i.addons.includes('consultSitIn')) skills.add('consultSitIn');
  if (i.delivery || i.addons.includes('medicineCollection')) skills.add('medicineCollection');
  const r: Requirements = { skills: [...skills], certs: [...certs] };
  if (i.addons.includes('language') && i.language) r.language = i.language;
  return r;
}

export function level1Allowed(mobility: Mobility, age: number): boolean {
  return mobility !== 'transfer' && age >= 18;
}

/** Human-readable need chips for the caregiver's offer card. */
export function needLabels(r: Requirements, mobility: Mobility): string[] {
  const out: string[] = [];
  if (mobility === 'stick') out.push('Walking stick');
  if (r.skills.includes('wheelchair')) out.push('Wheelchair');
  if (r.skills.includes('transfer')) out.push('Transfer help');
  if (r.skills.includes('paediatric')) out.push('Child');
  if (r.skills.includes('consultSitIn')) out.push('Consult sit-in');
  if (r.skills.includes('medicineCollection')) out.push('Collect medicine');
  if (r.language) out.push(`Speaks ${r.language}`);
  return out;
}
