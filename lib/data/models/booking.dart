import 'package:collection/collection.dart';

import '../../domain/booking_status.dart';
import '../../domain/needs.dart';
import '../../domain/pricing.dart';
import 'firestore_utils.dart';

const _eq = DeepCollectionEquality();

class PatientSnapshot {
  const PatientSnapshot({required this.name, required this.age, required this.mobility, this.allergy = '', this.talkNotes = ''});

  final String name;
  final int age;
  final Mobility mobility;
  final String allergy;
  final String talkNotes;

  String get initials => initialsOf(name);

  factory PatientSnapshot.fromMap(Map<String, dynamic> m) => PatientSnapshot(
        name: m['name'] as String? ?? '',
        age: (m['age'] as num?)?.toInt() ?? 0,
        mobility: readEnum(Mobility.values, m['mobility'], Mobility.independent),
        allergy: m['allergy'] as String? ?? '',
        talkNotes: m['talkNotes'] as String? ?? '',
      );

  Map<String, dynamic> toMap() =>
      {'name': name, 'age': age, 'mobility': mobility.name, 'allergy': allergy, 'talkNotes': talkNotes};
}

class PlaceRef {
  const PlaceRef({required this.label, required this.lat, required this.lng});

  final String label;
  final double lat;
  final double lng;

  factory PlaceRef.fromMap(Map<String, dynamic> m) => PlaceRef(
        label: m['label'] as String? ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {'label': label, 'lat': lat, 'lng': lng};
}

class PriceLine {
  const PriceLine(this.label, this.sen);

  final String label;
  final int sen;

  factory PriceLine.fromMap(Map<String, dynamic> m) =>
      PriceLine(m['label'] as String? ?? '', (m['sen'] as num?)?.toInt() ?? 0);

  Map<String, dynamic> toMap() => {'label': label, 'sen': sen};
}

class PriceInfo {
  const PriceInfo({this.lines = const [], this.paidSen = 0, this.shareSen, this.finalShareSen, this.refundSen = 0, this.creditSen = 0});

  final List<PriceLine> lines;
  final int paidSen;

  /// Level 1: the group share part of [paidSen] (excludes add-ons).
  final int? shareSen;

  /// Level 1: share after the group locked.
  final int? finalShareSen;
  final int refundSen;
  final int creditSen;

  int get totalSen => lines.fold(0, (t, l) => t + l.sen);

  factory PriceInfo.fromMap(Map<String, dynamic> m) => PriceInfo(
        lines: readMaps(m['lines']).map(PriceLine.fromMap).toList(),
        paidSen: (m['paidSen'] as num?)?.toInt() ?? 0,
        shareSen: (m['shareSen'] as num?)?.toInt(),
        finalShareSen: (m['finalShareSen'] as num?)?.toInt(),
        refundSen: (m['refundSen'] as num?)?.toInt() ?? 0,
        creditSen: (m['creditSen'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'lines': [for (final l in lines) l.toMap()],
        'paidSen': paidSen,
        'shareSen': shareSen,
        'finalShareSen': finalShareSen,
        'refundSen': refundSen,
        'creditSen': creditSen,
      };
}

class PaymentInfo {
  const PaymentInfo({required this.method, required this.status, this.paidAt});

  final String method;
  final String status;
  final DateTime? paidAt;

  factory PaymentInfo.fromMap(Map<String, dynamic> m) => PaymentInfo(
        method: m['method'] as String? ?? '',
        status: m['status'] as String? ?? '',
        paidAt: readDate(m['paidAt']),
      );

  Map<String, dynamic> toMap() => {'method': method, 'status': status, 'paidAt': writeDate(paidAt)};
}

class VisitStep {
  const VisitStep(this.key, this.at);

  final String key;
  final DateTime at;

  factory VisitStep.fromMap(Map<String, dynamic> m) => VisitStep(m['key'] as String, readDate(m['at'])!);

  Map<String, dynamic> toMap() => {'key': key, 'at': writeDate(at)};
}

class VisitSummary {
  const VisitSummary({
    required this.seenBy,
    required this.diagnosis,
    this.instructions = const [],
    this.nextAppt = '',
    this.medicines = '',
    this.notes = '',
    this.writtenBy = '',
    this.writtenAt,
  });

  final String seenBy;
  final String diagnosis;
  final List<String> instructions;
  final String nextAppt;
  final String medicines;
  final String notes;
  final String writtenBy;
  final DateTime? writtenAt;

  factory VisitSummary.fromMap(Map<String, dynamic> m) => VisitSummary(
        seenBy: m['seenBy'] as String? ?? '',
        diagnosis: m['diagnosis'] as String? ?? '',
        instructions: readStrings(m['instructions']),
        nextAppt: m['nextAppt'] as String? ?? '',
        medicines: m['medicines'] as String? ?? '',
        notes: m['notes'] as String? ?? '',
        writtenBy: m['writtenBy'] as String? ?? '',
        writtenAt: readDate(m['writtenAt']),
      );

  Map<String, dynamic> toMap() => {
        'seenBy': seenBy,
        'diagnosis': diagnosis,
        'instructions': instructions,
        'nextAppt': nextAppt,
        'medicines': medicines,
        'notes': notes,
        'writtenBy': writtenBy,
        'writtenAt': writeDate(writtenAt),
      };
}

class Rating {
  const Rating({required this.stars, this.tags = const [], this.text = ''});

  final int stars;
  final List<String> tags;
  final String text;

  factory Rating.fromMap(Map<String, dynamic> m) => Rating(
        stars: (m['stars'] as num?)?.toInt() ?? 0,
        tags: readStrings(m['tags']),
        text: m['text'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'stars': stars, 'tags': tags, 'text': text};
}

/// Visit step keys (spec §6). Group rides skip "waiting for the doctor".
const groupStepKeys = ['picked_up', 'registered', 'with_doctor', 'pharmacy', 'ride_home', 'home'];
const personalStepKeys = ['picked_up', 'registered', 'waiting_doctor', 'with_doctor', 'pharmacy', 'ride_home', 'home'];
const stepLabels = {
  'picked_up': 'Picked up',
  'registered': 'Arrived and registered',
  'waiting_doctor': 'Waiting for the doctor',
  'with_doctor': 'With the doctor',
  'pharmacy': 'At the pharmacy',
  'ride_home': 'Ride home',
  'home': 'Home safely',
};

class Booking {
  const Booking({
    required this.id,
    required this.familyId,
    required this.guardianUid,
    required this.patientId,
    required this.patient,
    required this.level,
    required this.pickup,
    required this.hospitalId,
    required this.clinic,
    required this.apptAt,
    required this.status,
    this.guardianName = '',
    this.pickupAt,
    this.groupId,
    this.package,
    this.addons = const {},
    this.language,
    this.caregiverId,
    this.caregiverName,
    this.caregiverPhone,
    this.offerCaregiverName,
    this.offerExpiresAt,
    this.notMatchedReason,
    this.price = const PriceInfo(),
    this.payment,
    this.steps = const [],
    this.summary,
    this.rating,
    this.waitlist = false,
    this.lockAt,
    this.createdAt,
    this.acceptedAt,
  });

  final String id;
  final String familyId;
  final String guardianUid;
  final String guardianName;
  final String patientId;
  final PatientSnapshot patient;
  final int level;
  final PlaceRef pickup;
  final String hospitalId;
  final String clinic;
  final DateTime apptAt;
  final DateTime? pickupAt;
  final String? groupId;
  final GroupPackage? package;
  final Set<Addon> addons;
  final String? language;
  final String? caregiverId;
  final String? caregiverName;
  final String? caregiverPhone;

  /// Name of the caregiver the current open offer went to, and when it expires.
  final String? offerCaregiverName;
  final DateTime? offerExpiresAt;

  /// 'no-caregiver' | 'helper-declined' | 'seat-taken'
  final String? notMatchedReason;
  final BookingStatus status;
  final PriceInfo price;
  final PaymentInfo? payment;
  final List<VisitStep> steps;
  final VisitSummary? summary;
  final Rating? rating;
  final bool waitlist;
  final DateTime? lockAt;
  final DateTime? createdAt;
  final DateTime? acceptedAt;

  List<String> get stepKeys => level == 1 ? groupStepKeys : personalStepKeys;

  /// The next step the caregiver will tap, or null when all done.
  String? get nextStepKey => steps.length < stepKeys.length ? stepKeys[steps.length] : null;

  factory Booking.fromMap(String id, Map<String, dynamic> m) => Booking(
        id: id,
        familyId: m['familyId'] as String? ?? '',
        guardianUid: m['guardianUid'] as String? ?? '',
        guardianName: m['guardianName'] as String? ?? '',
        patientId: m['patientId'] as String? ?? '',
        patient: PatientSnapshot.fromMap(readMap(m['patientSnapshot'])),
        level: (m['level'] as num?)?.toInt() ?? 1,
        pickup: PlaceRef.fromMap(readMap(m['pickup'])),
        hospitalId: m['hospitalId'] as String? ?? '',
        clinic: m['clinic'] as String? ?? '',
        apptAt: readDate(m['apptAt'])!,
        pickupAt: readDate(m['pickupAt']),
        groupId: m['groupId'] as String?,
        package: readEnumOrNull(GroupPackage.values, m['package']),
        addons: {for (final a in readStrings(m['addons'])) ?readEnumOrNull(Addon.values, a)},
        language: m['language'] as String?,
        caregiverId: m['caregiverId'] as String?,
        caregiverName: m['caregiverName'] as String?,
        caregiverPhone: m['caregiverPhone'] as String?,
        offerCaregiverName: m['offerCaregiverName'] as String?,
        offerExpiresAt: readDate(m['offerExpiresAt']),
        notMatchedReason: m['notMatchedReason'] as String?,
        status: BookingStatus.fromWire(m['status'] as String? ?? 'draft'),
        price: PriceInfo.fromMap(readMap(m['price'])),
        payment: m['payment'] == null ? null : PaymentInfo.fromMap(readMap(m['payment'])),
        steps: readMaps(m['steps']).map(VisitStep.fromMap).toList(),
        summary: m['summary'] == null ? null : VisitSummary.fromMap(readMap(m['summary'])),
        rating: m['rating'] == null ? null : Rating.fromMap(readMap(m['rating'])),
        waitlist: m['waitlist'] as bool? ?? false,
        lockAt: readDate(m['lockAt']),
        createdAt: readDate(m['createdAt']),
        acceptedAt: readDate(m['acceptedAt']),
      );

  Map<String, dynamic> toMap() => {
        'familyId': familyId,
        'guardianUid': guardianUid,
        'guardianName': guardianName,
        'patientId': patientId,
        'patientSnapshot': patient.toMap(),
        'level': level,
        'pickup': pickup.toMap(),
        'hospitalId': hospitalId,
        'clinic': clinic,
        'apptAt': writeDate(apptAt),
        'pickupAt': writeDate(pickupAt),
        'groupId': groupId,
        'package': package?.name,
        'addons': [for (final a in addons) a.name],
        'language': language,
        'caregiverId': caregiverId,
        'caregiverName': caregiverName,
        'caregiverPhone': caregiverPhone,
        'offerCaregiverName': offerCaregiverName,
        'offerExpiresAt': writeDate(offerExpiresAt),
        'notMatchedReason': notMatchedReason,
        'status': status.wire,
        'price': price.toMap(),
        'payment': payment?.toMap(),
        'steps': [for (final s in steps) s.toMap()],
        'summary': summary?.toMap(),
        'rating': rating?.toMap(),
        'waitlist': waitlist,
        'lockAt': writeDate(lockAt),
        'createdAt': writeDate(createdAt),
        'acceptedAt': writeDate(acceptedAt),
      };

  @override
  bool operator ==(Object other) => other is Booking && other.id == id && _eq.equals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hash(id, status, apptAt);
}
