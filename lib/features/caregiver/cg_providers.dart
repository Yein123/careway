import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/booking.dart';
import '../../data/models/delivery.dart';
import '../../data/models/offer.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';

final cgOffersProvider = StreamProvider<List<Offer>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(offerRepoProvider).watchOpenForCaregiver(uid);
});

final cgBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(bookingRepoProvider).watchForCaregiver(uid);
});

final cgDeliveriesProvider = StreamProvider<List<MedDelivery>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(deliveryRepoProvider).watchForCaregiver(uid);
});

/// Jobs the caregiver still has to do (paid or under way).
bool isActiveJob(Booking b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.inProgress;

bool sameLocalDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}
