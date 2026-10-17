import 'package:collection/collection.dart';

import '../../domain/needs.dart';
import 'firestore_utils.dart';

const _eq = DeepCollectionEquality();

class Family {
  const Family({
    required this.id,
    required this.name,
    required this.adminUid,
    required this.memberUids,
    this.memberNames = const {},
  });

  final String id;
  final String name;
  final String adminUid;
  final List<String> memberUids;
  final Map<String, String> memberNames;

  factory Family.fromMap(String id, Map<String, dynamic> m) => Family(
    id: id,
    name: m['name'] as String? ?? 'Family',
    adminUid: m['adminUid'] as String? ?? '',
    memberUids: readStrings(m['memberUids']),
    memberNames: Map<String, String>.from(readMap(m['memberNames'])),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'adminUid': adminUid,
    'memberUids': memberUids,
    'memberNames': memberNames,
  };
}

class Contact {
  const Contact({required this.name, required this.role, required this.phone});

  final String name;
  final String role;
  final String phone;

  factory Contact.fromMap(Map<String, dynamic> m) => Contact(
    name: m['name'] as String? ?? '',
    role: m['role'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {'name': name, 'role': role, 'phone': phone};
}

class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.age,
    this.relationship = 'Parent',
    this.phone = '',
    this.mobility = Mobility.independent,
    this.extraHelp = const [],
    this.conditions = '',
    this.surgery = '',
    this.allergy = '',
    this.medicines = '',
    this.clinics = '',
    this.talkNotes = '',
    this.contacts = const [],
    this.helperOnly = true,
    this.sendUpdates = true,
    this.updatedAt,
    this.updatedBy = '',
  });

  final String id;
  final String name;
  final int age;
  final String relationship;
  final String phone;
  final Mobility mobility;
  final List<String> extraHelp;
  final String conditions;
  final String surgery;
  final String allergy;
  final String medicines;
  final String clinics;
  final String talkNotes;
  final List<Contact> contacts;
  final bool helperOnly;
  final bool sendUpdates;
  final DateTime? updatedAt;
  final String updatedBy;

  String get initials => initialsOf(name);

  factory Patient.fromMap(String id, Map<String, dynamic> m) {
    final privacy = readMap(m['privacy']);
    return Patient(
      id: id,
      name: m['name'] as String? ?? '',
      age: (m['age'] as num?)?.toInt() ?? 0,
      relationship: m['relationship'] as String? ?? 'Parent',
      phone: m['phone'] as String? ?? '',
      mobility: readEnum(Mobility.values, m['mobility'], Mobility.independent),
      extraHelp: readStrings(m['extraHelp']),
      conditions: m['conditions'] as String? ?? '',
      surgery: m['surgery'] as String? ?? '',
      allergy: m['allergy'] as String? ?? '',
      medicines: m['medicines'] as String? ?? '',
      clinics: m['clinics'] as String? ?? '',
      talkNotes: m['talkNotes'] as String? ?? '',
      contacts: readMaps(m['contacts']).map(Contact.fromMap).toList(),
      helperOnly: privacy['helperOnly'] as bool? ?? true,
      sendUpdates: privacy['sendUpdates'] as bool? ?? true,
      updatedAt: readDate(m['updatedAt']),
      updatedBy: m['updatedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'age': age,
    'relationship': relationship,
    'phone': phone,
    'mobility': mobility.name,
    'extraHelp': extraHelp,
    'conditions': conditions,
    'surgery': surgery,
    'allergy': allergy,
    'medicines': medicines,
    'clinics': clinics,
    'talkNotes': talkNotes,
    'contacts': [for (final c in contacts) c.toMap()],
    'privacy': {'helperOnly': helperOnly, 'sendUpdates': sendUpdates},
    'updatedAt': writeDate(updatedAt),
    'updatedBy': updatedBy,
  };

  Patient copyWith({
    String? name,
    int? age,
    String? relationship,
    String? phone,
    Mobility? mobility,
    List<String>? extraHelp,
    String? conditions,
    String? surgery,
    String? allergy,
    String? medicines,
    String? clinics,
    String? talkNotes,
    List<Contact>? contacts,
    bool? helperOnly,
    bool? sendUpdates,
    DateTime? updatedAt,
    String? updatedBy,
  }) => Patient(
    id: id,
    name: name ?? this.name,
    age: age ?? this.age,
    relationship: relationship ?? this.relationship,
    phone: phone ?? this.phone,
    mobility: mobility ?? this.mobility,
    extraHelp: extraHelp ?? this.extraHelp,
    conditions: conditions ?? this.conditions,
    surgery: surgery ?? this.surgery,
    allergy: allergy ?? this.allergy,
    medicines: medicines ?? this.medicines,
    clinics: clinics ?? this.clinics,
    talkNotes: talkNotes ?? this.talkNotes,
    contacts: contacts ?? this.contacts,
    helperOnly: helperOnly ?? this.helperOnly,
    sendUpdates: sendUpdates ?? this.sendUpdates,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy ?? this.updatedBy,
  );

  @override
  bool operator ==(Object other) =>
      other is Patient && other.id == id && _eq.equals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hash(id, name, age);
}
