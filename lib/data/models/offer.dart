import 'firestore_utils.dart';

enum OfferKind { personal, groupJoin, groupNew, delivery }

enum OfferStatus { offered, accepted, declined, expired, cancelled }

/// A job request sent to one caregiver (spec §4). Carries a display summary so
/// the caregiver's card needs no patient read before accepting.
class Offer {
  const Offer({
    required this.id,
    required this.caregiverId,
    required this.kind,
    required this.status,
    required this.expiresAt,
    this.bookingId,
    this.deliveryId,
    this.patientName = '',
    this.patientAge = 0,
    this.placeName = '',
    this.apptAt,
    this.level = 1,
    this.estimateSen = 0,
    this.needs = const [],
    this.createdAt,
  });

  final String id;
  final String caregiverId;
  final OfferKind kind;
  final OfferStatus status;
  final DateTime expiresAt;
  final String? bookingId;
  final String? deliveryId;
  final String patientName;
  final int patientAge;
  final String placeName;
  final DateTime? apptAt;
  final int level;
  final int estimateSen;
  final List<String> needs;
  final DateTime? createdAt;

  factory Offer.fromMap(String id, Map<String, dynamic> m) => Offer(
        id: id,
        caregiverId: m['caregiverId'] as String? ?? '',
        kind: readEnum(OfferKind.values, m['kind'], OfferKind.personal),
        status: readEnum(OfferStatus.values, m['status'], OfferStatus.offered),
        expiresAt: readDate(m['expiresAt'])!,
        bookingId: m['bookingId'] as String?,
        deliveryId: m['deliveryId'] as String?,
        patientName: m['patientName'] as String? ?? '',
        patientAge: (m['patientAge'] as num?)?.toInt() ?? 0,
        placeName: m['placeName'] as String? ?? '',
        apptAt: readDate(m['apptAt']),
        level: (m['level'] as num?)?.toInt() ?? 1,
        estimateSen: (m['estimateSen'] as num?)?.toInt() ?? 0,
        needs: readStrings(m['needs']),
        createdAt: readDate(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'caregiverId': caregiverId,
        'kind': kind.name,
        'status': status.name,
        'expiresAt': writeDate(expiresAt),
        'bookingId': bookingId,
        'deliveryId': deliveryId,
        'patientName': patientName,
        'patientAge': patientAge,
        'placeName': placeName,
        'apptAt': writeDate(apptAt),
        'level': level,
        'estimateSen': estimateSen,
        'needs': needs,
        'createdAt': writeDate(createdAt),
      };
}
