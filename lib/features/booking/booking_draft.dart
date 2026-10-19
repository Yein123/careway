import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/booking.dart';
import '../../domain/pricing.dart';

/// A new group's pickup point and time (local).
class NewGroupChoice {
  const NewGroupChoice({required this.pickupPointId, required this.pickupAt});
  final String pickupPointId;
  final DateTime pickupAt;
}

/// The booking being built across steps 1–3 and the package/payment screens.
class BookingDraft {
  const BookingDraft({
    this.patientId,
    this.pickup,
    this.hospitalId,
    this.clinic,
    this.date,
    this.minutes,
    this.level,
    this.preferredLevel,
    this.needsConsult = false,
    this.needsTransfer = false,
    this.groupId,
    this.newGroup,
    this.waitlist = false,
    this.language,
    this.package = GroupPackage.saver,
    this.addons = const {},
  });

  final String? patientId;
  final PlaceRef? pickup;
  final String? hospitalId;
  final String? clinic;

  /// Local calendar day of the appointment.
  final DateTime? date;

  /// Minutes after local midnight.
  final int? minutes;
  final int? level;
  final int? preferredLevel;
  final bool needsConsult;
  final bool needsTransfer;
  final String? groupId;
  final NewGroupChoice? newGroup;
  final bool waitlist;
  final String? language;
  final GroupPackage package;
  final Set<Addon> addons;

  DateTime? get apptAt => date == null || minutes == null
      ? null
      : DateTime(date!.year, date!.month, date!.day).add(Duration(minutes: minutes!));

  /// Local trip date as stored on groups ('yyyy-MM-dd').
  String? get dateKey => date == null ? null : DateFormat('yyyy-MM-dd').format(date!);

  /// Everything on step 1 except who is going.
  bool get placeAndTimeComplete => pickup != null && hospitalId != null && clinic != null && apptAt != null;

  bool get detailsComplete => patientId != null && placeAndTimeComplete;

  BookingDraft copyWith({
    String? patientId,
    PlaceRef? pickup,
    String? hospitalId,
    String? clinic,
    DateTime? date,
    int? minutes,
    bool clearMinutes = false,
    int? level,
    int? preferredLevel,
    bool? needsConsult,
    bool? needsTransfer,
    String? Function()? groupId,
    NewGroupChoice? Function()? newGroup,
    bool? waitlist,
    String? Function()? language,
    GroupPackage? package,
    Set<Addon>? addons,
  }) =>
      BookingDraft(
        patientId: patientId ?? this.patientId,
        pickup: pickup ?? this.pickup,
        hospitalId: hospitalId ?? this.hospitalId,
        clinic: clinic ?? this.clinic,
        date: date ?? this.date,
        minutes: clearMinutes ? null : (minutes ?? this.minutes),
        level: level ?? this.level,
        preferredLevel: preferredLevel ?? this.preferredLevel,
        needsConsult: needsConsult ?? this.needsConsult,
        needsTransfer: needsTransfer ?? this.needsTransfer,
        groupId: groupId != null ? groupId() : this.groupId,
        newGroup: newGroup != null ? newGroup() : this.newGroup,
        waitlist: waitlist ?? this.waitlist,
        language: language != null ? language() : this.language,
        package: package ?? this.package,
        addons: addons ?? this.addons,
      );

  /// Input for the requestBooking callable (no package/add-ons: chosen after
  /// the helper accepts).
  Map<String, dynamic> toRequest() => {
        'patientId': patientId,
        'level': level,
        'pickup': pickup!.toMap(),
        'hospitalId': hospitalId,
        'clinic': clinic,
        'apptAt': apptAt!.toUtc().toIso8601String(),
        if (level == 1 && groupId != null) 'groupId': groupId,
        if (level == 1 && newGroup != null)
          'newGroup': {
            'pickupPointId': newGroup!.pickupPointId,
            'pickupTime': newGroup!.pickupAt.toUtc().toIso8601String(),
          },
        if (language != null) 'language': language,
        if (waitlist) 'waitlist': true,
      };

  /// Input for the payBooking callable.
  Map<String, dynamic> toPayment(String bookingId, String method, {required int level}) => {
        'bookingId': bookingId,
        'method': method,
        if (level == 1) 'package': package.name,
        if (level == 1) 'addons': [for (final a in addons) a.name],
        if (level == 1 && addons.contains(Addon.language) && language != null) 'language': language,
      };
}

class BookingDraftNotifier extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  void reset({int? preferredLevel}) => state = BookingDraft(preferredLevel: preferredLevel);
  void update(BookingDraft Function(BookingDraft) f) => state = f(state);
}

final bookingDraftProvider = NotifierProvider<BookingDraftNotifier, BookingDraft>(BookingDraftNotifier.new);

/// Appointment time slots, minutes after midnight: 7:30 AM to 4:00 PM.
final appointmentSlots = [for (var m = 7 * 60 + 30; m <= 16 * 60 + 30; m += 15) m];

String slotLabel(int minutes) {
  final h = minutes ~/ 60;
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '${h % 12 == 0 ? 12 : h % 12}:$m ${h < 12 ? 'AM' : 'PM'}';
}

/// How long before the appointment the latest new-group pickup is (minutes).
const newGroupMinLeadMinutes = 60;

/// Slots offered on [day]. Today only keeps slots still ahead of [now]; for
/// Level 1 the earliest new-group pickup must also still be ahead.
List<int> availableSlots(DateTime day, DateTime now, {int level = 1}) {
  final n = now.toLocal();
  final dayStart = DateTime(day.year, day.month, day.day);
  if (dayStart.isBefore(DateTime(n.year, n.month, n.day))) return const [];
  if (dayStart.isAfter(DateTime(n.year, n.month, n.day))) return appointmentSlots;
  final lead = level == 1 ? newGroupMinLeadMinutes : 0;
  return [
    for (final m in appointmentSlots)
      if (dayStart.add(Duration(minutes: m - lead)).isAfter(n)) m,
  ];
}

/// A day is bookable from today onwards while a slot remains (same-day visits are allowed).
bool dayBookable(DateTime day, DateTime now, {int level = 1}) => availableSlots(day, now, level: level).isNotEmpty;

/// Entry point for a new booking: clears the draft and opens step 1.
/// [patientId] prefills a follow-up visit.
void startBooking(BuildContext context, WidgetRef ref, {int? level, String? patientId}) {
  ref.read(bookingDraftProvider.notifier).reset(preferredLevel: level);
  if (patientId != null) ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(patientId: patientId));
  context.push('/book');
}
