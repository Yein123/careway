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
import '../../core/widgets/step_label.dart';
import '../../data/api.dart';
import '../../data/models/booking.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../../domain/pricing.dart';
import '../home/home_screen.dart' show placeName;
import 'booking_common.dart';
import 'booking_draft.dart';

/// Simulated payment methods (spec: payments are simulated).
const paymentMethods = [
  ('fpx', 'FPX online banking', 'Maybank2u, CIMB Clicks, RHB and more', 'FPX', CwColors.lilac, CwColors.primaryDark),
  ('tng', "Touch 'n Go eWallet", 'Pay in the eWallet app', 'TNG', CwColors.tealSoft, CwColors.tealDark),
  ('duitnow', 'DuitNow QR', 'Scan with any banking app', 'QR', CwColors.pinkSoft, CwColors.pink),
  ('card', 'Debit or credit card', 'Visa, Mastercard', 'CARD', CwColors.amberSoft, CwColors.amber),
];

/// Payment method picker shared by bookings and deliveries.
class PaymentMethodPicker extends StatelessWidget {
  const PaymentMethodPicker({super.key, required this.selected, required this.onPick});
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (id, name, sub, abbr, bg, fg) in paymentMethods)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CwCard(
              selected: selected == id,
              onTap: () => onPick(id),
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Text(abbr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: CwText.bodyBold),
                    Text(sub, style: CwText.small),
                  ]),
                ),
                Icon(selected == id ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected == id ? CwColors.primary : CwColors.muted),
              ]),
            ),
          ),
      ]);
}

String methodName(String id) => paymentMethods.firstWhere((m) => m.$1 == id, orElse: () => paymentMethods.first).$2;

/// 15 · Payment (Level 2) and 24 · Payment (Level 1 group).
class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return CwPage(
      title: 'Payment',
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
  String _method = 'fpx';
  bool _paying = false;
  String? _error;

  Future<void> _pay(Map<String, dynamic> input) async {
    final router = GoRouter.of(context);
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      await ref.read(careWayApiProvider).payBooking(input);
      router.go('/booking/${widget.b.id}/confirmed');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final draft = ref.watch(bookingDraftProvider);
    final now = ref.watch(clockProvider)();
    if (b.status == BookingStatus.confirmed) {
      return Column(children: [
        const EmptyState(icon: Icons.check_circle_outline, title: 'Already paid'),
        CwButton(label: 'View booking', onPressed: () => context.go('/booking/${b.id}/confirmed')),
      ]);
    }
    if (b.status != BookingStatus.awaitingPayment) {
      return Column(children: [
        const EmptyState(
          icon: Icons.timer_off_outlined,
          title: 'This booking is no longer waiting for payment',
          message: 'Nothing has been charged.',
        ),
        CwButton(label: 'Back to home', onPressed: () => context.go('/home')),
      ]);
    }

    final group = b.groupId == null ? null : ref.watch(groupProvider(b.groupId!)).value;
    final List<(String, int)> lines;
    int? share;
    if (b.level == 1) {
      final n = ridersWithMe(group, b.id);
      share = groupShareSen(draft.package, n);
      final addons = {for (final a in draft.addons) if (addonAvailable(a, b)) a};
      lines = [
        ('${draft.package.label} (ride + shared helper)', share),
        for (final a in addons) (a == Addon.language ? 'Language help (${draft.language ?? ''})' : a.label, a.sen),
      ];
    } else {
      lines = [
        ('Escort · RM 30 × est. ${defaultEscortHours.toInt()} hours', escortHourlySen * defaultEscortHours.toInt()),
        ('Private ride, both ways', privateRideSen),
      ];
    }
    final total = lines.fold(0, (t, l) => t + l.$2);
    final first = b.patient.name.split(' ').first;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(b.level == 1 ? 'Level 1 group · last step' : 'Level 2 escort · last step', style: CwText.small),
      const Gap(10),
      CwCard(
        color: b.level == 1 ? CwColors.lilac : CwColors.tealSoft,
        borderColor: b.level == 1 ? CwColors.lilac : CwColors.tealSoft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CwBadge(b.level == 1 ? 'LEVEL 1 · SHARED RIDE + GUIDANCE' : 'LEVEL 2 · ONE-TO-ONE ESCORT',
              color: b.level == 1 ? CwColors.primaryDark : CwColors.tealDark, background: CwColors.white),
          const SizedBox(height: 8),
          Text('${b.patient.name}, ${b.patient.age}', style: CwText.h3),
          Text('${placeName(b.hospitalId)} · ${b.clinic}', style: CwText.small),
          Text('${dayLabel(b.apptAt)} · appointment ${timeLabel(b.apptAt)}', style: CwText.small),
          if (b.pickupAt != null) Text('Pickup ${timeLabel(b.pickupAt!)} · ${b.pickup.label}', style: CwText.small),
          if (b.caregiverName != null) Text('${b.level == 1 ? 'Helper' : 'Escort'} ${b.caregiverName}', style: CwText.small),
        ]),
      ),
      const Gap(16),
      const SectionTitle('Price'),
      CwCard(
        child: Column(children: [
          for (final (label, sen) in lines) KeyValueRow(label, formatRm(sen)),
          const Divider(),
          KeyValueRow(b.level == 1 ? 'Pay now' : 'Pay now (estimate)', formatRm(total), bold: true),
        ]),
      ),
      const Gap(8),
      Text(
        b.level == 1
            ? 'You pay ${formatRm(share!)} now for the ride. If more neighbours join before '
                '${dayTimeLabel(b.lockAt ?? b.apptAt.subtract(const Duration(hours: 24)))}, you get the difference back automatically. '
                'Waiting time is not charged. Sample prices.'
            : 'Charged by actual time, in 30-minute steps. If the visit is shorter you get the difference back; '
                'if longer, we ask you before adding time. Sample prices.',
        style: CwText.small,
      ),
      const Gap(16),
      const SectionTitle('Pay with'),
      PaymentMethodPicker(selected: _method, onPick: (m) => setState(() => _method = m)),
      const Gap(6),
      Text('${cancelRuleText(b, now)} ${b.level == 1 ? 'Your seat is held once payment goes through.' : 'The escort is confirmed once payment goes through.'}',
          style: CwText.small),
      if (_error != null) ...[
        const Gap(10),
        Text(_error!, style: const TextStyle(color: CwColors.pink, fontWeight: FontWeight.w700)),
      ],
      const Gap(16),
      CwButton(
        label: _error == null ? 'Pay ${formatRm(total)}' : 'Retry · Pay ${formatRm(total)}',
        loading: _paying,
        onPressed: () => _pay(draft.toPayment(b.id, _method, level: b.level)),
      ),
      const Gap(6),
      Text('Paying with ${methodName(_method)} · $first\'s visit', textAlign: TextAlign.center, style: CwText.small),
    ]);
  }
}
