import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/status_timeline.dart';
import '../../core/widgets/step_label.dart';
import '../../data/api.dart';
import '../../data/models/delivery.dart';
import '../../data/providers.dart';
import '../booking/confirmed_screen.dart' show bookingRef;
import '../booking/payment_screen.dart';
import '../visits/rate_sheet.dart';

const deliveryRatingTags = ['On time', 'Friendly', 'Medicine checked', 'Kept me updated', 'Careful handover', 'Easy to book'];

/// 32–37 · Medicine delivery after the request: finding a helper, pay,
/// booked, live progress, delivered and rating — driven by the live status.
class DeliveryStatusScreen extends ConsumerWidget {
  const DeliveryStatusScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(deliveryProvider(deliveryId));
    return CwPage(
      title: 'Medicine delivery',
      children: [
        AsyncView<MedDelivery?>(
          value: d,
          onRetry: () => ref.invalidate(deliveryProvider(deliveryId)),
          isEmpty: (x) => x == null,
          empty: const EmptyState(icon: Icons.search_off, title: 'Delivery not found'),
          data: (x) => _Body(x!),
        ),
      ],
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body(this.d);
  final MedDelivery d;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  String _method = 'fpx';
  bool _busy = false;

  Future<void> _pay() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(careWayApiProvider).payDelivery(widget.d.id, _method);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate() async {
    final d = widget.d;
    final router = GoRouter.of(context);
    final r = await RateSheet.show(
      context,
      title: 'How was the delivery?',
      subtitle: "${d.caregiverName ?? 'Your helper'} · ${d.patientName.split(' ').first}'s medicine",
      tags: deliveryRatingTags,
      privacyNote: 'Ratings help us keep helpers on time and medicine handled with care.',
    );
    if (r == null) return;
    await ref.read(deliveryRepoProvider).rate(d.id, r);
    router.go('/delivery/${d.id}/thanks');
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final first = d.patientName.split(' ').first;
    final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("$first's medicine · ${bookingRef(d.id)}", style: CwText.small),
      Text('${d.pharmacyName} → ${d.deliverTo}', style: CwText.bodyBold),
      Text('${d.date == null ? '' : '${dayLabel(d.date!)} · '}${d.window}', style: CwText.small),
    ]);

    switch (d.status) {
      case DeliveryStatus.pendingCaregiver:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          const Gap(16),
          CwCard(
            child: StatusTimeline(accent: CwColors.deliveryBlue, steps: [
              TimelineStep('Request sent', d.createdAt, TimelineState.done),
              TimelineStep(
                d.offerCaregiverName == null
                    ? 'Finding a helper'
                    : 'Waiting for ${d.offerCaregiverName} to accept${d.offerExpiresAt == null ? '' : ' (expires ${timeLabel(d.offerExpiresAt!)})'}',
                null,
                TimelineState.current,
              ),
              const TimelineStep('Accepted — pay to confirm', null, TimelineState.upcoming),
            ]),
          ),
          const Gap(8),
          const Text("You won't be charged until a helper accepts.", style: CwText.small),
        ]);
      case DeliveryStatus.awaitingPayment:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          const Gap(16),
          CwCard(
            child: Column(children: [
              KeyValueRow('Helper', d.caregiverName ?? ''),
              KeyValueRow('Route', '${d.routeKm} km'),
              KeyValueRow('Base fee', formatRm(d.baseSen)),
              KeyValueRow('Distance fee', formatRm(d.distanceSen)),
              const Divider(),
              KeyValueRow('Delivery fee', formatRm(d.totalSen), bold: true),
            ]),
          ),
          const Gap(14),
          const SectionTitle('Pay with'),
          PaymentMethodPicker(selected: _method, onPick: (m) => setState(() => _method = m)),
          const Gap(10),
          CwButton(label: 'Pay ${formatRm(d.totalSen)}', color: CwColors.deliveryBlue, loading: _busy, onPressed: _pay),
        ]);
      case DeliveryStatus.notMatched || DeliveryStatus.expired || DeliveryStatus.cancelled:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          const Gap(16),
          EmptyState(
            icon: Icons.info_outline,
            title: d.status == DeliveryStatus.notMatched ? 'No helper available this time' : 'This delivery is closed',
            message: 'Nothing has been charged.',
          ),
          CwButton(label: 'Try another time', color: CwColors.deliveryBlue, onPressed: () => context.go('/delivery/new')),
        ]);
      default:
        final done = d.status == DeliveryStatus.delivered;
        final reached = deliveryStageKeys.indexOf(d.status.wire);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (d.status == DeliveryStatus.booked) ...[
            const Center(child: Icon(Icons.check_circle, size: 64, color: CwColors.success)),
            const Text('Delivery booked', textAlign: TextAlign.center, style: CwText.h1),
            Text(
              '${d.caregiverName ?? 'Your helper'} collects the documents between ${d.window} and delivers $first\'s medicine to your doorstep.',
              textAlign: TextAlign.center,
              style: CwText.muted,
            ),
            const Gap(14),
          ],
          header,
          const Gap(12),
          CwCard(
            color: done ? CwColors.successSoft : CwColors.deliverySoft,
            borderColor: done ? CwColors.successSoft : CwColors.deliverySoft,
            child: Row(children: [
              CwBadge(done ? 'DONE' : 'NOW', color: CwColors.white, background: done ? CwColors.success : CwColors.deliveryBlue),
              const SizedBox(width: 8),
              Expanded(child: Text(deliveryStageLabels[d.status.wire]!, style: CwText.h3)),
            ]),
          ),
          const Gap(12),
          CwCard(
            child: StatusTimeline(accent: CwColors.deliveryBlue, steps: [
              for (var i = 0; i < deliveryStageKeys.length; i++)
                TimelineStep(
                  deliveryStageLabels[deliveryStageKeys[i]]!,
                  d.steps.where((s) => s.key == deliveryStageKeys[i]).firstOrNull?.at,
                  i < reached || done ? TimelineState.done : (i == reached ? TimelineState.current : TimelineState.upcoming),
                ),
            ]),
          ),
          const Gap(10),
          KeyValueRow('Amount paid', formatRm(d.totalSen)),
          const Gap(14),
          if (done)
            d.rating == null
                ? CwButton(label: 'Rate this delivery', color: CwColors.deliveryBlue, onPressed: _rate)
                : Text('You rated ${d.rating!.stars}', textAlign: TextAlign.center, style: CwText.bodyBold),
          CwButton(label: 'Back to home', kind: CwButtonKind.text, color: CwColors.deliveryBlue, onPressed: () => context.go('/home')),
        ]);
    }
  }
}

/// 37 · Thank you (DelThanks.dc.html)
class DeliveryThanksScreen extends ConsumerWidget {
  const DeliveryThanksScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(deliveryProvider(deliveryId)).value;
    final first = d?.patientName.split(' ').first ?? 'your family';
    return CwPage(
      showBack: false,
      children: [
        const Gap(40),
        const Center(child: Icon(Icons.star_rounded, size: 96, color: CwColors.star)),
        const Text('Thank you!', textAlign: TextAlign.center, style: CwText.h1),
        const Gap(8),
        Text(
          'Your ${d?.rating?.stars ?? 5}-star rating and feedback have been sent. We\'ll share it with ${d?.caregiverName ?? 'your helper'} and our care team.',
          textAlign: TextAlign.center,
          style: CwText.muted,
        ),
        const Gap(20),
        CwCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Next refill', style: CwText.small),
            Text("Book $first's next medicine delivery in one tap.", style: CwText.bodyBold),
          ]),
        ),
        const Gap(24),
        CwButton(label: 'Book next delivery', color: CwColors.deliveryBlue, onPressed: () => context.go('/delivery/new')),
        CwButton(label: 'Back to home', kind: CwButtonKind.text, color: CwColors.deliveryBlue, onPressed: () => context.go('/home')),
      ],
    );
  }
}
