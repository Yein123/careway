import '../../domain/needs.dart';
import 'firestore_utils.dart';

class Certificate {
  const Certificate({required this.type, required this.verified, required this.expiresAt});

  final CertType type;
  final bool verified;
  final DateTime expiresAt;

  bool isValidOn(DateTime when) => verified && expiresAt.isAfter(when);

  factory Certificate.fromMap(Map<String, dynamic> m) => Certificate(
        type: readEnum(CertType.values, m['type'], CertType.firstAid),
        verified: m['verified'] as bool? ?? false,
        expiresAt: readDate(m['expiresAt']) ?? DateTime.utc(1970),
      );

  Map<String, dynamic> toMap() => {'type': type.name, 'verified': verified, 'expiresAt': writeDate(expiresAt)};
}

class CaregiverProfile {
  const CaregiverProfile({
    required this.uid,
    required this.displayName,
    this.agency = '',
    this.zone = 'Elmina',
    this.phone = '',
    this.onDuty = false,
    this.rating = 0,
    this.ratingCount = 0,
    this.languages = const [],
    this.skills = const {},
    this.certificates = const [],
  });

  final String uid;
  final String displayName;
  final String agency;
  final String zone;
  final String phone;
  final bool onDuty;
  final double rating;
  final int ratingCount;
  final List<String> languages;
  final Set<Skill> skills;
  final List<Certificate> certificates;

  String get initials => initialsOf(displayName);

  factory CaregiverProfile.fromMap(String uid, Map<String, dynamic> m) => CaregiverProfile(
        uid: uid,
        displayName: m['displayName'] as String? ?? '',
        agency: m['agency'] as String? ?? '',
        zone: m['zone'] as String? ?? 'Elmina',
        phone: m['phone'] as String? ?? '',
        onDuty: m['onDuty'] as bool? ?? false,
        rating: (m['rating'] as num?)?.toDouble() ?? 0,
        ratingCount: (m['ratingCount'] as num?)?.toInt() ?? 0,
        languages: readStrings(m['languages']),
        skills: {for (final s in readStrings(m['skills'])) ?readEnumOrNull(Skill.values, s)},
        certificates: readMaps(m['certificates']).map(Certificate.fromMap).toList(),
      );

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'agency': agency,
        'zone': zone,
        'phone': phone,
        'onDuty': onDuty,
        'rating': rating,
        'ratingCount': ratingCount,
        'languages': languages,
        'skills': [for (final s in skills) s.name],
        'certificates': [for (final c in certificates) c.toMap()],
      };
}
