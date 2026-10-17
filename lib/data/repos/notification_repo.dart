import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification.dart';

abstract class NotificationRepo {
  Stream<List<AppNotification>> watch(String uid);
  Future<void> markRead(String uid, String nid);
}

class FirestoreNotificationRepo implements NotificationRepo {
  FirestoreNotificationRepo(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<List<AppNotification>> watch(String uid) => _db
      .collection('users/$uid/notifications')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((q) => [for (final d in q.docs) AppNotification.fromMap(d.id, d.data())]);

  @override
  Future<void> markRead(String uid, String nid) => _db.doc('users/$uid/notifications/$nid').update({'read': true});
}

abstract class ReceiptRepo {
  Stream<List<Receipt>> watch(String uid);
}

class FirestoreReceiptRepo implements ReceiptRepo {
  FirestoreReceiptRepo(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<List<Receipt>> watch(String uid) => _db
      .collection('receipts')
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) Receipt.fromMap(d.id, d.data())]);
}
