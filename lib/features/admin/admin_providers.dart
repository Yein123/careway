import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/booking.dart';
import '../../data/models/delivery.dart';

const _bookingStatuses = [
  'pending_caregiver',
  'awaiting_payment',
  'confirmed',
  'in_progress',
];
const _deliveryStatuses = [
  'pending_caregiver',
  'awaiting_payment',
  'booked',
  'collecting',
  'at_pharmacy',
  'collected',
  'on_the_way',
];

/// Read side of the demo admin page (writes go through callables).
abstract class AdminRepo {
  Stream<List<Booking>> watchBookings();
  Stream<List<MedDelivery>> watchDeliveries();

  /// Bookings with the appointment today (local time), earliest first.
  Stream<List<Booking>> watchTodayVisits();
}

class FirestoreAdminRepo implements AdminRepo {
  FirestoreAdminRepo(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<List<Booking>> watchBookings() => _db
      .collection('bookings')
      .where('status', whereIn: _bookingStatuses)
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map((q) => [for (final d in q.docs) Booking.fromMap(d.id, d.data())]);

  @override
  Stream<List<MedDelivery>> watchDeliveries() => _db
      .collection('deliveries')
      .where('status', whereIn: _deliveryStatuses)
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map(
        (q) => [for (final d in q.docs) MedDelivery.fromMap(d.id, d.data())],
      );

  @override
  Stream<List<Booking>> watchTodayVisits() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _db
        .collection('bookings')
        .where('apptAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('apptAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('apptAt')
        .snapshots()
        .map((q) => [for (final d in q.docs) Booking.fromMap(d.id, d.data())]);
  }
}

final adminRepoProvider = Provider<AdminRepo>(
  (ref) => FirestoreAdminRepo(FirebaseFirestore.instance),
);

final adminBookingsProvider = StreamProvider<List<Booking>>(
  (ref) => ref.watch(adminRepoProvider).watchBookings(),
);

final adminDeliveriesProvider = StreamProvider<List<MedDelivery>>(
  (ref) => ref.watch(adminRepoProvider).watchDeliveries(),
);

final adminTodayVisitsProvider = StreamProvider<List<Booking>>(
  (ref) => ref.watch(adminRepoProvider).watchTodayVisits(),
);
