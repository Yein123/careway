import 'package:careway/domain/needs.dart';
import 'package:careway/domain/pricing.dart';
import 'package:flutter_test/flutter_test.dart';

Requirements req({
  int level = 1,
  Mobility mobility = Mobility.independent,
  int age = 70,
  Set<Addon> addons = const {},
  String? language,
  bool delivery = false,
}) =>
    deriveRequirements(
      level: level,
      mobility: mobility,
      patientAge: age,
      addons: addons,
      language: language,
      delivery: delivery,
    );

void main() {
  test('basic level 1 needs only first aid', () {
    final r = req();
    expect(r.skills, isEmpty);
    expect(r.certs, {CertType.firstAid});
    expect(r.language, isNull);
  });

  test('level 2 needs a trained escort', () {
    expect(req(level: 2).certs, containsAll([CertType.firstAid, CertType.trainedEscort]));
  });

  test('transfer needs transfer skill and patient handling cert', () {
    final r = req(level: 2, mobility: Mobility.transfer);
    expect(r.skills, contains(Skill.transfer));
    expect(r.certs, contains(CertType.patientHandling));
  });

  test('wheelchair mobility or add-on needs wheelchair skill', () {
    expect(req(mobility: Mobility.wheelchair).skills, contains(Skill.wheelchair));
    expect(req(addons: {Addon.wheelchairOnArrival}).skills, contains(Skill.wheelchair));
  });

  test('child needs paediatric skill and cert', () {
    final r = req(level: 2, age: 9);
    expect(r.skills, contains(Skill.paediatric));
    expect(r.certs, contains(CertType.paediatric));
  });

  test('add-ons map to skills and language', () {
    expect(req(addons: {Addon.consultSitIn}).skills, contains(Skill.consultSitIn));
    expect(req(addons: {Addon.medicineCollection}).skills, contains(Skill.medicineCollection));
    expect(req(delivery: true).skills, contains(Skill.medicineCollection));
    expect(req(addons: {Addon.language}, language: 'Tamil').language, 'Tamil');
  });

  test('language without the language add-on is not a requirement', () {
    expect(req(language: 'Tamil').language, isNull);
    expect(req(level: 2, language: 'Tamil').language, isNull);
  });

  test('level 1 is not allowed for transfer or children', () {
    expect(level1Allowed(Mobility.transfer, 70), isFalse);
    expect(level1Allowed(Mobility.stick, 17), isFalse);
    expect(level1Allowed(Mobility.wheelchair, 72), isTrue);
  });
}
