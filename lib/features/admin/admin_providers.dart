import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/booking.dart';
import '../../data/models/delivery.dart';

/// Id of the scenario-3 booking the admin drives step by step.
const demoS3BookingId = 'demo-s3-visit';

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
  'on_the_way',
];

/// Read side of the demo admin page (writes go through callables).
abstract class AdminRepo {
  Stream<List<Booking>> watchBookings();
  Stream<List<MedDelivery>> watchDeliveries();
  Stream<Booking?> watchS3();
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
  Stream<Booking?> watchS3() => _db
      .doc('bookings/$demoS3BookingId')
      .snapshots()
      .map((s) => s.exists ? Booking.fromMap(s.id, s.data()!) : null);
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

final adminS3Provider = StreamProvider<Booking?>(
  (ref) => ref.watch(adminRepoProvider).watchS3(),
);
