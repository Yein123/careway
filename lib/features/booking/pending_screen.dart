import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/status_timeline.dart';
import '../../data/api.dart';
import '../../data/models/booking.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../home/home_screen.dart' show placeName;

/// Where a booking's status should take the guardian, if somewhere else.
String? routeForStatus(Booking b) => switch (b.status) {
      BookingStatus.awaitingPayment => b.level == 1 ? '/booking/${b.id}/package' : '/booking/${b.id}/pay',
      BookingStatus.notMatched => '/booking/${b.id}/not-found',
      BookingStatus.confirmed => '/booking/${b.id}/confirmed',
      _ => null,
    };

/// 6 · Request pending (Pending.dc.html). Reacts to the live booking status.
class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(bookingProvider(bookingId), (prev, next) {
      final b = next.value;
      if (b == null || prev?.value?.status == b.status) return;
      final to = routeForStatus(b);
      if (to != null) context.go(to);
    });
    final booking = ref.watch(bookingProvider(bookingId));
    return CwPage(
      title: 'Request sent',
      showBack: false,
      children: [
        AsyncView<Booking?>(
          value: booking,
          onRetry: () => ref.invalidate(bookingProvider(bookingId)),
          isEmpty: (b) => b == null,
          empty: const EmptyState(icon: Icons.search_off, title: 'Request not found'),
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
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final first = b.patient.name.split(' ').first;
    final waiting = b.offerCaregiverName != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(b.level == 1 ? 'Waiting for the group' : 'Finding your escort', style: CwText.h1),
      const SizedBox(height: 6),
      Text(
        b.level == 1
            ? "We're checking the seat and the helper's schedule for $first."
            : "We're matching a trained escort with the right skills for $first.",
        style: CwText.muted,
      ),
      const Gap(16),
      CwCard(
        child: StatusTimeline(steps: [
          TimelineStep('Request sent', b.createdAt, TimelineState.done, detail: placeName(b.hospitalId)),
          TimelineStep(
            waiting
                ? 'Waiting for ${b.offerCaregiverName} to accept${b.offerExpiresAt == null ? '' : ' (expires ${timeLabel(b.offerExpiresAt!)})'}'
                : 'Finding a qualified caregiver',
            null,
            TimelineState.current,
            detail: 'In progress',
          ),
          const TimelineStep('Accepted — pay to confirm', null, TimelineState.upcoming),
        ]),
      ),
      const Gap(14),
      Text(
        "You can close the app. We'll notify you as soon as there's an answer. You won't be charged until you confirm.",
        style: CwText.small,
      ),
      const Gap(20),
      CwButton(label: 'Back to home', kind: CwButtonKind.secondary, onPressed: () => context.go('/home')),
      const Gap(8),
      CwButton(
        label: 'Cancel request',
        kind: CwButtonKind.text,
        color: CwColors.pink,
        loading: _cancelling,
        onPressed: () async {
          final router = GoRouter.of(context);
          final messenger = ScaffoldMessenger.of(context);
          setState(() => _cancelling = true);
          try {
            await ref.read(careWayApiProvider).cancelBooking(b.id);
            router.go('/home');
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
          } finally {
            if (mounted) setState(() => _cancelling = false);
          }
        },
      ),
    ]);
  }
}
