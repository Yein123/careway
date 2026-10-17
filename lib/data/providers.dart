import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/booking.dart';
import 'models/caregiver.dart';
import 'models/delivery.dart';
import 'models/family.dart';
import 'models/notification.dart';
import 'models/user.dart';
import 'repos/auth_repo.dart';
import 'repos/booking_repo.dart';
import 'repos/family_repo.dart';
import 'repos/notification_repo.dart';
import 'repos/user_repo.dart';

final authRepoProvider = Provider<AuthRepo>(
  (ref) => FirebaseAuthRepo(FirebaseAuth.instance),
);
final userRepoProvider = Provider<UserRepo>(
  (ref) => FirestoreUserRepo(FirebaseFirestore.instance),
);
final caregiverRepoProvider = Provider<CaregiverRepo>(
  (ref) => FirestoreCaregiverRepo(FirebaseFirestore.instance),
);
final familyRepoProvider = Provider<FamilyRepo>(
  (ref) => FirestoreFamilyRepo(FirebaseFirestore.instance),
);
final bookingRepoProvider = Provider<BookingRepo>(
  (ref) => FirestoreBookingRepo(FirebaseFirestore.instance),
);
final groupRepoProvider = Provider<GroupRepo>(
  (ref) => FirestoreGroupRepo(FirebaseFirestore.instance),
);
final offerRepoProvider = Provider<OfferRepo>(
  (ref) => FirestoreOfferRepo(FirebaseFirestore.instance),
);
final deliveryRepoProvider = Provider<DeliveryRepo>(
  (ref) => FirestoreDeliveryRepo(FirebaseFirestore.instance),
);
final notificationRepoProvider = Provider<NotificationRepo>(
  (ref) => FirestoreNotificationRepo(FirebaseFirestore.instance),
);
final receiptRepoProvider = Provider<ReceiptRepo>(
  (ref) => FirestoreReceiptRepo(FirebaseFirestore.instance),
);

/// Current time; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Current time, re-emitted every 30 seconds (countdowns). Overridden in tests.
final tickProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => clock());
});

/// Signed-in uid, or null.
final authStateProvider = StreamProvider<String?>(
  (ref) => ref.watch(authRepoProvider).authState,
);

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepoProvider).watch(uid);
});

final familyIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider).value?.familyId,
);

final familyProvider = StreamProvider<Family?>((ref) {
  final fid = ref.watch(familyIdProvider);
  if (fid == null) return Stream.value(null);
  return ref.watch(familyRepoProvider).watchFamily(fid);
});

final patientsProvider = StreamProvider<List<Patient>>((ref) {
  final fid = ref.watch(familyIdProvider);
  if (fid == null) return Stream.value(const []);
  return ref.watch(familyRepoProvider).watchPatients(fid);
});

final caregiverProfileProvider = StreamProvider<CaregiverProfile?>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(null);
  return ref.watch(caregiverRepoProvider).watch(uid);
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationRepoProvider).watch(uid);
});

final patientProvider = StreamProvider.family<Patient?, String>((ref, pid) {
  final fid = ref.watch(familyIdProvider);
  if (fid == null) return Stream.value(null);
  return ref.watch(familyRepoProvider).watchPatient(fid, pid);
});

final familyBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final fid = ref.watch(familyIdProvider);
  if (fid == null) return Stream.value(const []);
  return ref.watch(bookingRepoProvider).watchForFamily(fid);
});

final bookingProvider = StreamProvider.family<Booking?, String>(
  (ref, id) => ref.watch(bookingRepoProvider).watch(id),
);

final deliveryProvider = StreamProvider.family<MedDelivery?, String>(
  (ref, id) => ref.watch(deliveryRepoProvider).watch(id),
);
