import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/status_timeline.dart';
import '../../core/widgets/step_label.dart';
import '../../data/api.dart';
import '../../data/models/booking.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../home/home_screen.dart' show placeName, levelLabel;
import 'booking_common.dart';
import 'booking_draft.dart';
import 'confirmed_screen.dart' show bookingRef;
import 'submit.dart';

/// 21 · Upcoming visit (Upcoming.dc.html), plus the status of any booking.
class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return CwPage(
      title: 'Your visit',
      children: [
        AsyncView<Booking?>(
          value: booking,
          onRetry: () => ref.invalidate(bookingProvider(bookingId)),
          isEmpty: (b) => b == null,
          empty: const EmptyState(icon: Icons.search_off, title: 'Booking not found'),
          data: (b) => _Body(b!),
        ),
      ],
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body(this.b);
  final Booking b;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  Future<void> _cancel() async {
    final b = widget.b;
    final now = ref.read(clockProvider)();
    final first = b.patient.name.split(' ').first;
    final yes = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text("Cancel $first's visit?", style: CwText.h2),
          const SizedBox(height: 6),
          Text(b.status == BookingStatus.confirmed ? cancelRuleText(b, now) : 'Nothing has been charged.', style: CwText.muted),
          const SizedBox(height: 16),
          CwButton(label: 'Keep visit', onPressed: () => Navigator.pop(ctx, false)),
          const SizedBox(height: 8),
          CwButton(label: 'Yes, cancel', kind: CwButtonKind.text, color: CwColors.pink, onPressed: () => Navigator.pop(ctx, true)),
        ]),
      ),
    );
    if (yes != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final r = await ref.read(careWayApiProvider).cancelBooking(b.id);
      messenger.showSnackBar(SnackBar(
        content: Text(r.refundSen > 0
            ? 'Visit cancelled. ${formatRm(r.refundSen)} is on its way back to you.'
            : r.creditSen > 0
                ? 'Visit cancelled. ${formatRm(r.creditSen)} added as CareWay credit.'
                : 'Visit cancelled.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final now = ref.watch(clockProvider)();
    final days = b.apptAt.difference(now).inDays;
    final first = b.patient.name.split(' ').first;
    final cancellable = const {
      BookingStatus.draft,
      BookingStatus.pendingCaregiver,
      BookingStatus.awaitingPayment,
      BookingStatus.confirmed,
      BookingStatus.notMatched,
    }.contains(b.status);

    Widget statusCard() => switch (b.status) {
          BookingStatus.draft when b.waitlist => CwCard(
              color: CwColors.amberSoft,
              borderColor: CwColors.amberSoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('On the waitlist', style: CwText.h3),
                const Text("We'll tell you if a seat opens up. Nothing is charged until you confirm.", style: CwText.small),
                const SizedBox(height: 10),
                CwButton(
                  label: 'Request to join now',
                  loading: _busy,
                  onPressed: () async {
                    ref.read(bookingDraftProvider.notifier).update((d) => draftFromBooking(b, d).copyWith(waitlist: false));
                    setState(() => _busy = true);
                    await submitDraft(context, ref);
                    if (mounted) setState(() => _busy = false);
                  },
                ),
              ]),
            ),
          BookingStatus.pendingCaregiver => _Link('Finding a caregiver', 'Tap to see the request', () => context.push('/booking/${b.id}/pending')),
          BookingStatus.awaitingPayment => _Link('Pay to confirm', '${b.caregiverName ?? 'Your caregiver'} accepted. Pay within 30 minutes.',
              () => context.push(b.level == 1 ? '/booking/${b.id}/package' : '/booking/${b.id}/pay')),
          BookingStatus.notMatched => _Link('Not successful', 'Nothing has been charged. See your options.', () => context.push('/booking/${b.id}/not-found')),
          BookingStatus.inProgress => _Link('Happening now', 'Follow the visit live', () => context.push('/booking/${b.id}/live')),
          BookingStatus.completed => _Link('Visit complete', 'Read the summary and rate the visit', () => context.go('/visits')),
          BookingStatus.cancelled => const CwCard(child: Text('This visit was cancelled.', style: CwText.bodyBold)),
          BookingStatus.expired => const CwCard(child: Text('This request expired. Nothing was charged.', style: CwText.bodyBold)),
          _ => CwCard(
              color: CwColors.lilac,
              borderColor: CwColors.lilac,
              child: Row(children: [
                Column(children: [
                  const Text('In', style: CwText.small),
                  Text('$days', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
                  Text(days == 1 ? 'day' : 'days', style: CwText.small),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CwBadge(levelLabel(b.level).toUpperCase()),
                    const SizedBox(height: 4),
                    Text(dayTimeLabel(b.apptAt), style: CwText.h3),
                    Text('$first · ${placeName(b.hospitalId)}', style: CwText.small),
                  ]),
                ),
              ]),
            ),
        };

    final pickup = b.pickupAt ?? b.apptAt.subtract(const Duration(hours: 1));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      statusCard(),
      const Gap(14),
      if (b.caregiverName != null) ...[
        CwCard(
          child: Row(children: [
            Avatar(b.caregiverName!.split(' ').map((w) => w.isEmpty ? '' : w[0]).take(2).join(), color: CwColors.tealDark, background: CwColors.tealSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.level == 1 ? 'Your helper' : 'Your escort', style: CwText.small),
                Text(b.caregiverName!, style: CwText.bodyBold),
                const Text('Background-checked · first aid trained', style: CwText.small),
              ]),
            ),
          ]),
        ),
        const Gap(14),
      ],
      const SectionTitle('Plan for the day'),
      CwCard(
        child: StatusTimeline(steps: [
          TimelineStep('Pickup · ${b.pickup.label}', null, TimelineState.upcoming, detail: timeLabel(pickup)),
          TimelineStep('Arrive at ${placeName(b.hospitalId)}', null, TimelineState.upcoming,
              detail: b.level == 1 ? 'Walk to registration together' : 'Your escort stays throughout'),
          TimelineStep('Appointment · ${b.clinic}', null, TimelineState.upcoming, detail: timeLabel(b.apptAt)),
          TimelineStep('Ride home', null, TimelineState.upcoming,
              detail: b.package?.name == 'saver' ? 'Next scheduled return: 12:30 or 3:30 PM' : 'As soon as $first is done'),
        ]),
      ),
      const Gap(14),
      if (b.price.paidSen > 0)
        CwCard(
          child: Column(children: [
            KeyValueRow('Booking ID', bookingRef(b.id)),
            KeyValueRow('Paid', formatRm(b.price.paidSen)),
            if (b.price.refundSen > 0) KeyValueRow('Refunded', formatRm(b.price.refundSen)),
            if (b.price.creditSen > 0) KeyValueRow('CareWay credit', formatRm(b.price.creditSen)),
          ]),
        ),
      if (b.status == BookingStatus.confirmed) ...[
        const Gap(10),
        Text(cancelRuleText(b, now), style: CwText.small),
      ],
      if (cancellable) ...[
        const Gap(16),
        CwButton(label: 'Cancel visit', kind: CwButtonKind.text, color: CwColors.pink, loading: _busy, onPressed: _cancel),
      ],
    ]);
  }
}

class _Link extends StatelessWidget {
  const _Link(this.title, this.body, this.onTap);
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CwCard(
        onTap: onTap,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: CwText.h3),
              Text(body, style: CwText.small),
            ]),
          ),
          const Icon(Icons.chevron_right, color: CwColors.muted),
        ]),
      );
}
