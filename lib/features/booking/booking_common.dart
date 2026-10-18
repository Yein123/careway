import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/booking.dart';
import '../../data/models/group.dart';
import '../../data/providers.dart';
import '../../domain/needs.dart';
import '../../domain/pricing.dart';
import 'booking_draft.dart';

final groupProvider = StreamProvider.family<Group?, String>((ref, id) => ref.watch(groupRepoProvider).watch(id));

/// Languages offered by the "Language help" add-on (beyond Malay/English).
const helpLanguages = ['Tamil', 'Cantonese', 'Hokkien', 'Mandarin', 'Sign language'];

const _addonSkill = {
  Addon.consultSitIn: Skill.consultSitIn,
  Addon.wheelchairOnArrival: Skill.wheelchair,
  Addon.medicineCollection: Skill.medicineCollection,
};

List<String> languageOptions(Booking b) => [for (final l in helpLanguages) if (b.caregiverLanguages.contains(l)) l];

/// Whether the accepted helper can provide [a] (server re-checks at payment).
bool addonAvailable(Addon a, Booking b) {
  if (a == Addon.language) return languageOptions(b).isNotEmpty;
  final skill = _addonSkill[a];
  return skill == null || b.caregiverSkills.contains(skill.name);
}

/// Rebuilds a draft from an existing booking (e.g. opened from a notification).
BookingDraft draftFromBooking(Booking b, BookingDraft current) {
  final local = b.apptAt.toLocal();
  return current.copyWith(
    patientId: b.patientId,
    pickup: b.pickup,
    hospitalId: b.hospitalId,
    clinic: b.clinic,
    date: DateTime(local.year, local.month, local.day),
    minutes: local.hour * 60 + local.minute,
    level: b.level,
    groupId: () => b.groupId,
  );
}

bool afterLock(Booking b, DateTime now) {
  if (b.groupId != null && b.lockAt == null) return false;
  final lockAt = b.lockAt ?? b.apptAt.subtract(const Duration(hours: 24));
  return !now.isBefore(lockAt);
}

/// Plain-language cancellation rule for this booking right now.
String cancelRuleText(Booking b, DateTime now) {
  if (!afterLock(b, now)) return "It's more than 24 hours away, so cancelling is free.";
  if (b.level == 1 && b.package == GroupPackage.saver) return 'Less than 24 hours to go: cancelling now gives CareWay credit instead of a refund.';
  return 'Less than 24 hours to go: cancelling now refunds 50%.';
}

/// Riders in the group after this booking joins (for the share price).
int ridersWithMe(Group? g, String bookingId) {
  if (g == null) return 1;
  final n = g.riderBookingIds.contains(bookingId) ? g.riders : g.riders + 1;
  return n.clamp(1, groupCapacity);
}
