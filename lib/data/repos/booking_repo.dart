import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking.dart';
import '../models/delivery.dart';
import '../models/group.dart';
import '../models/offer.dart';

abstract class BookingRepo {
  Stream<List<Booking>> watchForFamily(String fid);
  Stream<Booking?> watch(String id);
  Stream<List<Booking>> watchForCaregiver(String uid);

  /// Guardian rating on a completed booking (the only client write allowed).
  Future<void> rate(String id, Rating rating);
}

class FirestoreBookingRepo implements BookingRepo {
  FirestoreBookingRepo(this._db);
  final FirebaseFirestore _db;

  List<Booking> _list(QuerySnapshot<Map<String, dynamic>> q) => [for (final d in q.docs) Booking.fromMap(d.id, d.data())];

  @override
  Stream<List<Booking>> watchForFamily(String fid) => _db
      .collection('bookings')
      .where('familyId', isEqualTo: fid)
      .orderBy('apptAt', descending: true)
      .snapshots()
      .map(_list);

  @override
  Stream<Booking?> watch(String id) =>
      _db.doc('bookings/$id').snapshots().map((s) => s.exists ? Booking.fromMap(s.id, s.data()!) : null);

  @override
  Stream<List<Booking>> watchForCaregiver(String uid) => _db
      .collection('bookings')
      .where('caregiverId', isEqualTo: uid)
      .orderBy('apptAt')
      .snapshots()
      .map(_list);

  @override
  Future<void> rate(String id, Rating rating) => _db.doc('bookings/$id').update({'rating': rating.toMap()});
}

abstract class GroupRepo {
  /// Groups for a hospital on a trip date ('yyyy-MM-dd'), open or full.
  Stream<List<Group>> watchForDay({required String hospitalId, required String date});
  Stream<Group?> watch(String id);
}

class FirestoreGroupRepo implements GroupRepo {
  FirestoreGroupRepo(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<List<Group>> watchForDay({required String hospitalId, required String date}) => _db
      .collection('groups')
      .where('hospitalId', isEqualTo: hospitalId)
      .where('date', isEqualTo: date)
      .where('status', whereIn: ['open', 'full'])
      .snapshots()
      .map((q) => [for (final d in q.docs) Group.fromMap(d.id, d.data())]..sort((a, b) => a.pickupAt.compareTo(b.pickupAt)));

  @override
  Stream<Group?> watch(String id) =>
      _db.doc('groups/$id').snapshots().map((s) => s.exists ? Group.fromMap(s.id, s.data()!) : null);
}

abstract class OfferRepo {
  Stream<List<Offer>> watchOpenForCaregiver(String uid);
}

class FirestoreOfferRepo implements OfferRepo {
  FirestoreOfferRepo(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<List<Offer>> watchOpenForCaregiver(String uid) => _db
      .collection('offers')
      .where('caregiverId', isEqualTo: uid)
      .where('status', isEqualTo: 'offered')
      .orderBy('expiresAt')
      .snapshots()
      .map((q) => [for (final d in q.docs) Offer.fromMap(d.id, d.data())]);
}

abstract class DeliveryRepo {
  Stream<List<MedDelivery>> watchForFamily(String fid);
  Stream<MedDelivery?> watch(String id);
  Stream<List<MedDelivery>> watchForCaregiver(String uid);
  Future<void> rate(String id, Rating rating);
}

class FirestoreDeliveryRepo implements DeliveryRepo {
  FirestoreDeliveryRepo(this._db);
  final FirebaseFirestore _db;

  List<MedDelivery> _list(QuerySnapshot<Map<String, dynamic>> q) =>
      [for (final d in q.docs) MedDelivery.fromMap(d.id, d.data())];

  @override
  Stream<List<MedDelivery>> watchForFamily(String fid) => _db
      .collection('deliveries')
      .where('familyId', isEqualTo: fid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_list);

  @override
  Stream<MedDelivery?> watch(String id) =>
      _db.doc('deliveries/$id').snapshots().map((s) => s.exists ? MedDelivery.fromMap(s.id, s.data()!) : null);

  @override
  Stream<List<MedDelivery>> watchForCaregiver(String uid) =>
      _db.collection('deliveries').where('caregiverId', isEqualTo: uid).snapshots().map(_list);

  @override
  Future<void> rate(String id, Rating rating) => _db.doc('deliveries/$id').update({'rating': rating.toMap()});
}
