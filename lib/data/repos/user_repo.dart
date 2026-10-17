import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/caregiver.dart';
import '../models/user.dart';

abstract class UserRepo {
  Stream<AppUser?> watch(String uid);
  Future<void> create(AppUser user);
  Future<void> update(String uid, Map<String, dynamic> fields);
}

class FirestoreUserRepo implements UserRepo {
  FirestoreUserRepo(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<AppUser?> watch(String uid) => _db
      .doc('users/$uid')
      .snapshots()
      .map((s) => s.exists ? AppUser.fromMap(s.id, s.data()!) : null);

  @override
  Future<void> create(AppUser user) =>
      _db.doc('users/${user.uid}').set(user.toMap());

  @override
  Future<void> update(String uid, Map<String, dynamic> fields) =>
      _db.doc('users/$uid').update(fields);
}

abstract class CaregiverRepo {
  Stream<CaregiverProfile?> watch(String uid);
  Future<void> setOnDuty(String uid, bool onDuty);
}

class FirestoreCaregiverRepo implements CaregiverRepo {
  FirestoreCaregiverRepo(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<CaregiverProfile?> watch(String uid) => _db
      .doc('caregivers/$uid')
      .snapshots()
      .map((s) => s.exists ? CaregiverProfile.fromMap(s.id, s.data()!) : null);

  @override
  Future<void> setOnDuty(String uid, bool onDuty) =>
      _db.doc('caregivers/$uid').update({'onDuty': onDuty});
}
