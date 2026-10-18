import 'firestore_utils.dart';

enum GroupStatus { open, full, locked, completed, cancelled }

class SeatHold {
  const SeatHold({required this.bookingId, required this.until});

  final String bookingId;
  final DateTime until;

  factory SeatHold.fromMap(Map<String, dynamic> m) => SeatHold(
    bookingId: m['bookingId'] as String,
    until: readDate(m['until'])!,
  );

  Map<String, dynamic> toMap() => {
    'bookingId': bookingId,
    'until': writeDate(until),
  };
}

/// A Level 1 shared ride. Holds no patient data, only rider initials.
class Group {
  const Group({
    required this.id,
    required this.hospitalId,
    required this.clinic,
    required this.date,
    required this.pickupPointId,
    required this.pickupAt,
    required this.apptWindow,
    required this.status,
    this.lockAt,
    this.caregiverId,
    this.caregiverName,
    this.caregiverRating,
    this.riderBookingIds = const [],
    this.riderInitials = const [],
    this.heldSeats = const [],
    this.capacity = 3,
  });

  final String id;
  final String hospitalId;
  final String clinic;

  /// Local date 'yyyy-MM-dd' of the trip.
  final String date;
  final String pickupPointId;
  final DateTime pickupAt;
  final String apptWindow;
  final GroupStatus status;
  final DateTime? lockAt;
  final String? caregiverId;
  final String? caregiverName;
  final double? caregiverRating;
  final List<String> riderBookingIds;
  final List<String> riderInitials;
  final List<SeatHold> heldSeats;
  final int capacity;

  int get riders => riderBookingIds.length;
  int activeHolds(DateTime now) =>
      heldSeats.where((h) => h.until.isAfter(now)).length;
  int seatsLeft(DateTime now) => capacity - riders - activeHolds(now);
  bool isFull(DateTime now) =>
      status != GroupStatus.open || seatsLeft(now) <= 0;

  factory Group.fromMap(String id, Map<String, dynamic> m) => Group(
    id: id,
    hospitalId: m['hospitalId'] as String? ?? '',
    clinic: m['clinic'] as String? ?? '',
    date: m['date'] as String? ?? '',
    pickupPointId: m['pickupPointId'] as String? ?? '',
    pickupAt: readDate(m['pickupAt'])!,
    apptWindow: m['apptWindow'] as String? ?? '',
    status: readEnum(GroupStatus.values, m['status'], GroupStatus.open),
    lockAt: readDate(m['lockAt']),
    caregiverId: m['caregiverId'] as String?,
    caregiverName: m['caregiverName'] as String?,
    caregiverRating: (m['caregiverRating'] as num?)?.toDouble(),
    riderBookingIds: readStrings(m['riderBookingIds']),
    riderInitials: readStrings(m['riderInitials']),
    heldSeats: readMaps(m['heldSeats']).map(SeatHold.fromMap).toList(),
    capacity: (m['capacity'] as num?)?.toInt() ?? 3,
  );

  Map<String, dynamic> toMap() => {
    'hospitalId': hospitalId,
    'clinic': clinic,
    'date': date,
    'pickupPointId': pickupPointId,
    'pickupAt': writeDate(pickupAt),
    'apptWindow': apptWindow,
    'status': status.name,
    'lockAt': writeDate(lockAt),
    'caregiverId': caregiverId,
    'caregiverName': caregiverName,
    'caregiverRating': caregiverRating,
    'riderBookingIds': riderBookingIds,
    'riderInitials': riderInitials,
    'heldSeats': [for (final h in heldSeats) h.toMap()],
    'capacity': capacity,
  };
}
