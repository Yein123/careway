import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/places.dart';
import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/design_kit.dart';
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
    return DesignScaffold(
      gap: 18,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        PageHeader(title: 'Request sent', help: true, onBack: () => context.go('/home')),
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
    final l1 = b.level == 1;
    final group = l1 && b.groupId != null;
    final pointName = pickupPoints.where((p) => p.name == b.pickup.label).firstOrNull?.name;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: Column(children: [
          const _Searching(),
          const SizedBox(height: 14),
          Text(l1 ? 'Waiting for the group' : 'Finding your escort', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(
            l1
                ? "We're checking seats and the helper's schedule for $first. Most requests are answered within 2 hours."
                : "We're matching a trained escort with the right skills for $first. Most requests are answered within 2 hours.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5, color: CwColors.muted),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
        child: StatusTimeline(steps: [
          TimelineStep(
            'Request sent',
            null,
            TimelineState.done,
            detail: [
              if (b.createdAt != null) timeLabel(b.createdAt!),
              group ? '${pointName ?? b.pickup.label} group' : placeName(b.hospitalId),
            ].join(' · '),
          ),
          TimelineStep(
            waiting
                ? 'Waiting for ${b.offerCaregiverName} to accept${b.offerExpiresAt == null ? '' : ' (expires ${timeLabel(b.offerExpiresAt!)})'}'
                : (l1 ? 'Checking seats and pickup time' : 'Finding a qualified caregiver'),
            null,
            TimelineState.current,
            detail: 'In progress',
          ),
          TimelineStep(
            waiting ? '${l1 ? 'Helper' : 'Escort'} ${b.offerCaregiverName!.split(' ').first} confirms' : 'Accepted — pay to confirm',
            null,
            TimelineState.upcoming,
          ),
        ]),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(14)),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CwIcon('<path d="M6 8a6 6 0 0 1 12 0c0 7 3 8 3 8H3s3-1 3-8"/><path d="M10 20a2 2 0 0 0 4 0"/>', size: 18, strokeWidth: 2.2, color: CwColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "You can close the app. We'll notify you as soon as there's an answer. You won't be charged until you confirm.",
              style: TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF3A2591)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      BigButton(label: 'Back to home', height: 58, onPressed: () => context.go('/home')),
      const SizedBox(height: 8),
      _cancelling
          ? const SizedBox(height: 44, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))))
          : SizedBox(
              height: 44,
              child: TextButton(
                onPressed: () async {
                  final router = GoRouter.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  if (!await confirmCancelRequest(context)) return;
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
                style: TextButton.styleFrom(
                  foregroundColor: CwColors.muted,
                  textStyle: const TextStyle(fontFamily: cwFont, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                child: const Text('Cancel request'),
              ),
            ),
    ]);
  }
}

/// Asks before cancelling a pending request; true only on "Yes, cancel".
Future<bool> confirmCancelRequest(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel this request?'),
      content: const Text("We'll stop looking for a caregiver. Nothing has been charged."),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep request')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: CwColors.pink),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Yes, cancel'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Pulsing halo with a spinning ring around the family icon.
class _Searching extends StatefulWidget {
  const _Searching();

  @override
  State<_Searching> createState() => _SearchingState();
}

class _SearchingState extends State<_Searching> with TickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _pulse.repeat();
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 120,
        height: 120,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) {
              final t = Curves.easeOut.transform(_pulse.value);
              return Transform.scale(
                scale: 0.85 + 0.5 * t,
                child: Opacity(
                  opacity: _pulse.isAnimating ? 0.7 * (1 - t) : 1,
                  child: Container(decoration: const BoxDecoration(color: Color(0xFFE4DCFB), shape: BoxShape.circle)),
                ),
              );
            },
          ),
          Container(width: 92, height: 92, decoration: const BoxDecoration(color: CwColors.white, shape: BoxShape.circle)),
          RotationTransition(
            turns: _spin,
            child: const SizedBox(
              width: 92,
              height: 92,
              child: CircularProgressIndicator(
                value: 0.25,
                strokeWidth: 5,
                color: CwColors.primary,
                backgroundColor: Color(0xFFE4DCFB),
              ),
            ),
          ),
          const CwIcon(CwIcons.family, size: 40, color: CwColors.primary),
        ]),
      );
}
