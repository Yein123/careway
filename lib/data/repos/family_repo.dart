import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/family.dart';

abstract class FamilyRepo {
  Stream<Family?> watchFamily(String fid);
  Stream<List<Patient>> watchPatients(String fid);
  Stream<Patient?> watchPatient(String fid, String pid);

  /// Creates the family with [adminUid] as its only member and links the
  /// user's `familyId`. Returns the family id.
  Future<String> createFamily({
    required String name,
    required String adminUid,
    required String adminName,
  });

  /// Creates (empty id) or replaces a patient. Returns the patient id.
  Future<String> savePatient(String fid, Patient patient);
}

class FirestoreFamilyRepo implements FamilyRepo {
  FirestoreFamilyRepo(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<Family?> watchFamily(String fid) => _db
      .doc('families/$fid')
      .snapshots()
      .map((s) => s.exists ? Family.fromMap(s.id, s.data()!) : null);

  @override
  Stream<List<Patient>> watchPatients(String fid) => _db
      .collection('families/$fid/patients')
      .orderBy('name')
      .snapshots()
      .map((q) => [for (final d in q.docs) Patient.fromMap(d.id, d.data())]);

  @override
  Stream<Patient?> watchPatient(String fid, String pid) => _db
      .doc('families/$fid/patients/$pid')
      .snapshots()
      .map((s) => s.exists ? Patient.fromMap(s.id, s.data()!) : null);

  @override
  Future<String> createFamily({
    required String name,
    required String adminUid,
    required String adminName,
  }) async {
    final ref = _db.collection('families').doc();
    final batch = _db.batch()
      ..set(
        ref,
        Family(
          id: ref.id,
          name: name,
          adminUid: adminUid,
          memberUids: [adminUid],
          memberNames: {adminUid: adminName},
        ).toMap(),
      )
      ..update(_db.doc('users/$adminUid'), {'familyId': ref.id});
    await batch.commit();
    return ref.id;
  }

  @override
  Future<String> savePatient(String fid, Patient patient) async {
    final col = _db.collection('families/$fid/patients');
    final ref = patient.id.isEmpty ? col.doc() : col.doc(patient.id);
    await ref.set(patient.toMap());
    return ref.id;
  }
}
