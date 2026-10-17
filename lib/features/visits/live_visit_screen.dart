import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/safety_button.dart';
import '../../core/widgets/status_timeline.dart';
import '../../data/models/booking.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../home/home_screen.dart' show placeName, levelLabel;
import 'rate_sheet.dart';

/// Timeline rows for a booking's visit steps.
List<TimelineStep> visitTimeline(Booking b) {
  final keys = b.stepKeys;
  return [
    for (var i = 0; i < keys.length; i++)
      TimelineStep(
        stepLabels[keys[i]]!,
        i < b.steps.length ? b.steps[i].at : null,
        i < b.steps.length ? TimelineState.done : (i == b.steps.length && b.status != BookingStatus.completed ? TimelineState.current : TimelineState.upcoming),
      ),
  ];
}

/// Opens the phone dialer; shows a snackbar if that isn't possible (e.g. web).
Future<void> callNumber(BuildContext context, String number) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(Uri(scheme: 'tel', path: number.replaceAll(' ', ''))).catchError((_) => false);
  if (!ok) messenger.showSnackBar(SnackBar(content: Text('Call $number')));
}

/// 10 · Visit day (Group) and 19 · Visit day (Personal).
class LiveVisitScreen extends ConsumerWidget {
  const LiveVisitScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return CwPage(
      title: 'Visit day',
      action: const SafetyButton(),
      children: [
        AsyncView<Booking?>(
          value: booking,
          onRetry: () => ref.invalidate(bookingProvider(bookingId)),
          isEmpty: (b) => b == null,
          empty: const EmptyState(icon: Icons.search_off, title: 'Visit not found'),
          data: (b) => _Body(b!),
        ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.b);
  final Booking b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = b.patient.name.split(' ').first;
    final next = b.nextStepKey;
    final done = b.status == BookingStatus.completed;
    final status = done
        ? '$first is home safely'
        : b.steps.isEmpty
            ? 'Pickup at ${timeLabel(b.pickupAt ?? b.apptAt.subtract(const Duration(hours: 1)))}'
            : 'Now: ${stepLabels[next] ?? stepLabels[b.steps.last.key]}';
    final accent = b.level == 1 ? CwColors.primary : CwColors.teal;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CwCard(
        child: Row(children: [
          Avatar(b.patient.initials, background: CwColors.pinkSoft, color: CwColors.pink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text("$first's visit ${dayLabel(b.apptAt)}", style: CwText.h3)),
                const SizedBox(width: 6),
                CwBadge(levelLabel(b.level).toUpperCase(), color: accent, background: accent.withValues(alpha: 0.12)),
              ]),
              Text('${placeName(b.hospitalId)} · ${b.caregiverName ?? ''}', style: CwText.small),
            ]),
          ),
        ]),
      ),
      const Gap(12),
      CwCard(
        color: done ? CwColors.successSoft : CwColors.lilac,
        borderColor: done ? CwColors.successSoft : CwColors.lilac,
        child: Row(children: [
          if (!done) const CwBadge('LIVE', color: CwColors.white, background: CwColors.success),
          if (!done) const SizedBox(width: 8),
          Expanded(child: Text(status, style: CwText.h3)),
        ]),
      ),
      const Gap(12),
      CwCard(child: StatusTimeline(steps: visitTimeline(b), accent: accent)),
      const Gap(8),
      const Text("Updates come from your helper's app. You'll get a notification at each step.", style: CwText.small),
      const Gap(16),
      if ((b.caregiverPhone ?? '').isNotEmpty)
        CwButton(
          label: 'Call ${b.caregiverName?.split(' ').first ?? 'helper'} · ${b.caregiverPhone}',
          kind: CwButtonKind.secondary,
          color: accent,
          onPressed: () => callNumber(context, b.caregiverPhone!),
        ),
      if (done) ...[
        const Gap(10),
        b.rating == null
            ? CwButton(
                label: 'Home safe? Rate this visit',
                onPressed: () async {
                  final r = await RateSheet.show(context,
                      title: "How was $first's visit?",
                      subtitle: 'Rate ${b.caregiverName ?? 'your helper'}${b.level == 1 ? ' and the ride' : ''}',
                      privacyNote: "Shared with CareWay and the helper's partner agency only.");
                  if (r != null) await ref.read(bookingRepoProvider).rate(b.id, r);
                },
              )
            : Text('You rated ${b.rating!.stars}', textAlign: TextAlign.center, style: CwText.bodyBold),
      ],
    ]);
  }
}
