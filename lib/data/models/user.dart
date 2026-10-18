import 'firestore_utils.dart';

enum UserRole { guardian, caregiver, admin }

class SavedPlace {
  const SavedPlace({
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String label;
  final String address;
  final double lat;
  final double lng;

  factory SavedPlace.fromMap(Map<String, dynamic> m) => SavedPlace(
    label: m['label'] as String? ?? '',
    address: m['address'] as String? ?? '',
    lat: (m['lat'] as num?)?.toDouble() ?? 0,
    lng: (m['lng'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'label': label,
    'address': address,
    'lat': lat,
    'lng': lng,
  };
}

class PaymentMethod {
  const PaymentMethod({required this.type, required this.label});

  /// 'fpx' | 'tng' | 'duitnow' | 'card'
  final String type;
  final String label;

  factory PaymentMethod.fromMap(Map<String, dynamic> m) => PaymentMethod(
    type: m['type'] as String? ?? 'fpx',
    label: m['label'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {'type': type, 'label': label};
}

class UserSettings {
  const UserSettings({
    this.language = 'English',
    this.textScale = 1.0,
    this.visitUpdates = true,
    this.reminders = true,
    this.promos = false,
  });

  final String language;
  final double textScale;
  final bool visitUpdates;
  final bool reminders;
  final bool promos;

  factory UserSettings.fromMap(Map<String, dynamic> m) {
    final notif = readMap(m['notif']);
    return UserSettings(
      language: m['language'] as String? ?? 'English',
      textScale: (m['textScale'] as num?)?.toDouble() ?? 1.0,
      visitUpdates: notif['visitUpdates'] as bool? ?? true,
      reminders: notif['reminders'] as bool? ?? true,
      promos: notif['promos'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'language': language,
    'textScale': textScale,
    'notif': {
      'visitUpdates': visitUpdates,
      'reminders': reminders,
      'promos': promos,
    },
  };
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.area = '',
    this.familyId,
    this.settings = const UserSettings(),
    this.savedPlaces = const [],
    this.paymentMethods = const [],
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String area;
  final UserRole role;
  final String? familyId;
  final UserSettings settings;
  final List<SavedPlace> savedPlaces;
  final List<PaymentMethod> paymentMethods;

  String get initials => initialsOf(name);
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
    uid: uid,
    name: m['name'] as String? ?? '',
    email: m['email'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    area: m['area'] as String? ?? '',
    role: readEnum(UserRole.values, m['role'], UserRole.guardian),
    familyId: m['familyId'] as String?,
    settings: UserSettings.fromMap(readMap(m['settings'])),
    savedPlaces: readMaps(m['savedPlaces']).map(SavedPlace.fromMap).toList(),
    paymentMethods: readMaps(
      m['paymentMethods'],
    ).map(PaymentMethod.fromMap).toList(),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'phone': phone,
    'area': area,
    'role': role.name,
    'familyId': familyId,
    'settings': settings.toMap(),
    'savedPlaces': [for (final p in savedPlaces) p.toMap()],
    'paymentMethods': [for (final p in paymentMethods) p.toMap()],
  };
}
