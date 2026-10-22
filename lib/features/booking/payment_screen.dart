import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/design_kit.dart';
import '../../data/api.dart';
import '../../data/models/booking.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../../domain/pricing.dart';
import '../home/home_screen.dart' show placeName;
import 'booking_common.dart';
import 'booking_draft.dart';
import 'confirmed_screen.dart';

/// Simulated payment methods (spec: payments are simulated).
const paymentMethods = [
  ('fpx', 'FPX online banking', 'Maybank2u, CIMB Clicks, RHB and more', 'FPX', Color(0xFFE4DCFB), CwColors.primaryDark),
  ('tng', "Touch 'n Go eWallet", 'Pay in the eWallet app', 'TNG', CwColors.tealSoft, CwColors.tealDark),
  ('duitnow', 'DuitNow QR', 'Scan with any banking app', 'QR', CwColors.pinkSoft, Color(0xFFA02A4C)),
  ('card', 'Debit or credit card', 'Visa, Mastercard', 'CARD', CwColors.amberSoft, CwColors.amber),
];

/// Payment method picker shared by bookings and deliveries.
class PaymentMethodPicker extends StatelessWidget {
  const PaymentMethodPicker({super.key, required this.selected, required this.onPick, this.accent = CwColors.primary});
  final String selected;
  final ValueChanged<String> onPick;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (id, name, sub, abbr, bg, fg) in paymentMethods)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectCard(
              on: selected == id,
              accent: accent,
              onColor: accent == CwColors.primary ? CwColors.lilac : const Color(0xFFEEF3FB),
              onTap: () => onPick(id),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                  child: Text(abbr, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: fg)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(sub, style: const TextStyle(fontSize: 11, color: CwColors.muted)),
                  ]),
                ),
                RadioDot(on: selected == id, color: accent),
              ]),
            ),
          ),
      ]);
}

String methodName(String id) => paymentMethods.firstWhere((m) => m.$1 == id, orElse: () => paymentMethods.first).$2;

/// Short label for receipts ("FPX", "TNG", "QR", "CARD").
String methodShort(String id) => paymentMethods.firstWhere((m) => m.$1 == id, orElse: () => paymentMethods.first).$4;

/// 15 · Payment (Level 2) and 24 · Payment (Level 1 group).
class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return booking.when(
      loading: () => const Scaffold(backgroundColor: CwColors.surface, body: Center(child: CircularProgressIndicator())),
      error: (_, _) => CwPage(
        title: 'Payment',
        children: [AsyncView<Booking?>(value: booking, onRetry: () => ref.invalidate(bookingProvider(bookingId)), data: (_) => const SizedBox())],
      ),
      data: (b) => b == null
          ? const CwPage(title: 'Payment', children: [EmptyState(icon: Icons.search_off, title: 'Booking not found')])
          : isPaid(b)
              ? ConfirmedScreen(bookingId: bookingId)
              : _Body(b),
    );
  }
}

/// Paid bookings show the confirmation instead of asking for payment again.
bool isPaid(Booking b) => const {BookingStatus.confirmed, BookingStatus.inProgress, BookingStatus.completed}.contains(b.status);

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
    final l1 = b.level == 1;
    final subtitle = l1 ? 'Level 1 group · last step' : 'Level 2 escort · last step';
    if (b.status != BookingStatus.awaitingPayment) {
      return DesignScaffold(children: [
        PageHeader(title: 'Payment', subtitle: subtitle, help: true),
        const EmptyState(
          icon: Icons.timer_off_outlined,
          title: 'This booking is no longer waiting for payment',
          message: 'Nothing has been charged.',
        ),
        BigButton(label: 'Back to home', onPressed: () => context.go('/home')),
      ]);
    }

    final group = b.groupId == null ? null : ref.watch(groupProvider(b.groupId!)).value;
    final List<(String, int)> lines;
    int? share;
    final n = ridersWithMe(group, b.id);
    if (l1) {
      share = groupShareSen(draft.package, n);
      final addons = draft.addons;
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
    String rm(int sen) => sen == 0 ? 'Free' : formatRm(sen);

    return DesignScaffold(
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) ...[
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: CwColors.pink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
        ],
        BigButton(
          label: _error == null ? 'Pay ${rm(total)}' : 'Retry · Pay ${rm(total)}',
          icon: lockIcon,
          height: 58,
          loading: _paying,
          onPressed: () => _pay(draft.toPayment(b.id, _method, level: b.level)),
        ),
        const SizedBox(height: 8),
        Text('Paying with ${methodName(_method)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: CwColors.muted)),
      ]),
      children: [
        PageHeader(title: 'Payment', subtitle: subtitle, help: true),
        const StepBars(count: 3, filled: 3),
        HeroCard(
          color: l1 ? CwColors.primary : CwColors.teal,
          overline: l1 ? 'LEVEL 1 · SHARED RIDE + GUIDANCE' : 'LEVEL 2 · ONE-TO-ONE ESCORT',
          badge: l1 ? 'Group of $n' : 'Not shared',
          title: '${b.patient.name}, ${b.patient.age}',
          lines: [
            b.clinic.isEmpty ? placeName(b.hospitalId) : '${placeName(b.hospitalId)} · ${b.clinic}',
            '${dayLabel(b.apptAt)} · appointment ${timeLabel(b.apptAt)}',
            if (b.pickupAt != null)
              'Pickup ${timeLabel(b.pickupAt!)}${l1 ? ' · ' : ' from '}${b.pickup.label}${l1 && b.caregiverName != null ? ' · helper ${b.caregiverName}' : ''}',
          ],
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionLabel('Price'),
          const SizedBox(height: 8),
          PriceTable(
            lines: [for (final (k, v) in lines) (k, rm(v))],
            totalLabel: l1 ? 'Pay now' : 'Pay now (estimate)',
            total: rm(total),
            totalColor: l1 ? CwColors.primaryDark : CwColors.tealDark,
          ),
          const SizedBox(height: 8),
          Text(
            l1
                ? 'You pay ${formatRm(share!)} now for the ride. '
                    '${b.groupId != null && b.lockAt == null ? 'When the group is set before pickup, you get the difference back automatically. ' : 'If more neighbours join before ${dayTimeLabel(b.lockAt ?? b.apptAt.subtract(const Duration(hours: 24)))}, you get the difference back automatically. '}'
                    'Waiting time is not charged. Sample prices.'
                : 'Charged by actual time, in 30-minute steps. If the visit is shorter you get the difference back; '
                    'if longer, we ask you before adding time. Sample prices.',
            style: const TextStyle(fontSize: 11, height: 1.45, color: CwColors.muted),
          ),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionLabel('Pay with'),
          const SizedBox(height: 8),
          PaymentMethodPicker(selected: _method, onPick: (m) => setState(() => _method = m)),
        ]),
        NoteRow(
          text: '${cancelRuleText(b, now)} ${l1 ? 'Your seat is held once payment goes through.' : 'The escort is confirmed once payment goes through.'}',
        ),
      ],
    );
  }
}
