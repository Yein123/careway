import 'pricing.dart';

/// Patient → caregiver requirements (spec §4). Mirrored in
/// functions/src/domain/needs.ts; enum names are the Firestore wire values.

enum Mobility {
  independent('Without help'),
  stick('Walking stick'),
  wheelchair('Wheelchair'),
  transfer('Needs transfer help');

  const Mobility(this.label);
  final String label;
}

enum Skill {
  wheelchair('Wheelchair'),
  transfer('Patient transfer'),
  consultSitIn('Consultation sit-in'),
  paediatric('Children'),
  dementia('Dementia care'),
  medicineCollection('Medicine collection');

  const Skill(this.label);
  final String label;
}

enum CertType {
  firstAid('First aid'),
  patientHandling('Patient handling'),
  trainedEscort('Trained escort'),
  paediatric('Paediatric care');

  const CertType(this.label);
  final String label;
}

class Requirements {
  const Requirements({required this.skills, required this.certs, this.language});

  final Set<Skill> skills;
  final Set<CertType> certs;

  /// Hard language requirement (only from the Language help add-on).
  final String? language;
}

Requirements deriveRequirements({
  required int level,
  required Mobility mobility,
  required int patientAge,
  required Set<Addon> addons,
  String? language,
  bool delivery = false,
}) {
  final skills = <Skill>{};
  final certs = <CertType>{CertType.firstAid};
  if (level == 2) certs.add(CertType.trainedEscort);
  if (mobility == Mobility.transfer) {
    skills.add(Skill.transfer);
    certs.add(CertType.patientHandling);
  }
  if (mobility == Mobility.wheelchair || addons.contains(Addon.wheelchairOnArrival)) {
    skills.add(Skill.wheelchair);
  }
  if (patientAge < 18) {
    skills.add(Skill.paediatric);
    certs.add(CertType.paediatric);
  }
  if (addons.contains(Addon.consultSitIn)) skills.add(Skill.consultSitIn);
  if (delivery || addons.contains(Addon.medicineCollection)) skills.add(Skill.medicineCollection);
  return Requirements(
    skills: skills,
    certs: certs,
    language: addons.contains(Addon.language) ? language : null,
  );
}

/// Level 1 excludes lifting/transfer help, and children always get Level 2.
bool level1Allowed(Mobility mobility, int age) => mobility != Mobility.transfer && age >= 18;
