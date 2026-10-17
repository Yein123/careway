import 'booking.dart';
import 'firestore_utils.dart';

enum DeliveryStatus {
  pendingCaregiver('pending_caregiver'),
  awaitingPayment('awaiting_payment'),
  booked('booked'),
  collecting('collecting'),
  atPharmacy('at_pharmacy'),
  onTheWay('on_the_way'),
  delivered('delivered'),
  notMatched('not_matched'),
  cancelled('cancelled'),
  expired('expired');

  const DeliveryStatus(this.wire);
  final String wire;

  static DeliveryStatus fromWire(String s) => values.firstWhere((v) => v.wire == s, orElse: () => pendingCaregiver);
}

const deliveryStageKeys = ['booked', 'collecting', 'at_pharmacy', 'on_the_way', 'delivered'];
const deliveryStageLabels = {
  'booked': 'Booked',
  'collecting': 'Collecting documents',
  'at_pharmacy': 'At the pharmacy',
  'on_the_way': 'On the way to you',
  'delivered': 'Delivered',
};

class MedDelivery {
  const MedDelivery({
    required this.id,
    required this.familyId,
    required this.guardianUid,
    required this.patientId,
    required this.patientName,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.window,
    required this.deliverTo,
    required this.routeKm,
    required this.baseSen,
    required this.distanceSen,
    required this.status,
    this.date,
    this.caregiverId,
    this.caregiverName,
    this.offerCaregiverName,
    this.offerExpiresAt,
    this.steps = const [],
    this.payment,
    this.rating,
    this.createdAt,
  });

  final String id;
  final String familyId;
  final String guardianUid;
  final String patientId;
  final String patientName;
  final String pharmacyId;
  final String pharmacyName;
  final String window;
  final String deliverTo;
  final DateTime? date;
  final double routeKm;
  final int baseSen;
  final int distanceSen;
  final DeliveryStatus status;
  final String? caregiverId;
  final String? caregiverName;
  final String? offerCaregiverName;
  final DateTime? offerExpiresAt;
  final List<VisitStep> steps;
  final PaymentInfo? payment;
  final Rating? rating;
  final DateTime? createdAt;

  int get totalSen => baseSen + distanceSen;

  factory MedDelivery.fromMap(String id, Map<String, dynamic> m) {
    final fee = readMap(m['fee']);
    return MedDelivery(
      id: id,
      familyId: m['familyId'] as String? ?? '',
      guardianUid: m['guardianUid'] as String? ?? '',
      patientId: m['patientId'] as String? ?? '',
      patientName: m['patientName'] as String? ?? '',
      pharmacyId: m['pharmacyId'] as String? ?? '',
      pharmacyName: m['pharmacyName'] as String? ?? '',
      window: m['window'] as String? ?? '',
      deliverTo: m['deliverTo'] as String? ?? '',
      date: readDate(m['date']),
      routeKm: (m['routeKm'] as num?)?.toDouble() ?? 0,
      baseSen: (fee['baseSen'] as num?)?.toInt() ?? 0,
      distanceSen: (fee['distanceSen'] as num?)?.toInt() ?? 0,
      status: DeliveryStatus.fromWire(m['status'] as String? ?? 'pending_caregiver'),
      caregiverId: m['caregiverId'] as String?,
      caregiverName: m['caregiverName'] as String?,
      offerCaregiverName: m['offerCaregiverName'] as String?,
      offerExpiresAt: readDate(m['offerExpiresAt']),
      steps: readMaps(m['steps']).map(VisitStep.fromMap).toList(),
      payment: m['payment'] == null ? null : PaymentInfo.fromMap(readMap(m['payment'])),
      rating: m['rating'] == null ? null : Rating.fromMap(readMap(m['rating'])),
      createdAt: readDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'familyId': familyId,
        'guardianUid': guardianUid,
        'patientId': patientId,
        'patientName': patientName,
        'pharmacyId': pharmacyId,
        'pharmacyName': pharmacyName,
        'window': window,
        'deliverTo': deliverTo,
        'date': writeDate(date),
        'routeKm': routeKm,
        'fee': {'baseSen': baseSen, 'distanceSen': distanceSen, 'totalSen': totalSen},
        'status': status.wire,
        'caregiverId': caregiverId,
        'caregiverName': caregiverName,
        'offerCaregiverName': offerCaregiverName,
        'offerExpiresAt': writeDate(offerExpiresAt),
        'steps': [for (final s in steps) s.toMap()],
        'payment': payment?.toMap(),
        'rating': rating?.toMap(),
        'createdAt': writeDate(createdAt),
      };
}
