import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_top_bar.dart';
import '../../core/widgets/design_kit.dart';
import '../../core/widgets/safety_button.dart';
import '../../data/models/booking.dart';
import '../../data/providers.dart';
import '../home/home_screen.dart' show placeName;
import 'booking_common.dart';
import 'payment_screen.dart' show methodName, methodShort;

/// Short display reference for a booking id.
String bookingRef(String id) => 'CW-${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}';

/// 9 · Booking confirmed (Confirmed.dc.html) and 16 · Escort booked (EscortConfirmed.dc.html).
class ConfirmedScreen extends ConsumerWidget {
  const ConfirmedScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return DesignScaffold(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SquareIconButton(svg: CwIcons.shield, label: 'Help and safety', color: CwColors.primary, onTap: () => showHelpSheet(context)),
        ),
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
  bool _cal = false;
  bool _shared = false;

  Future<void> _addToCalendar() async {
    final b = widget.b;
    final fmt = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    final start = (b.pickupAt ?? b.apptAt).toUtc();
    final end = b.apptAt.add(const Duration(hours: 3)).toUtc();
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': "${b.patient.name.split(' ').first}'s visit · ${placeName(b.hospitalId)}",
      'dates': '${fmt.format(start)}/${fmt.format(end)}',
      'details': 'CareWay booking ${bookingRef(b.id)}',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (mounted) setState(() => _cal = true);
  }

  void _share() {
    setState(() => _shared = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Everyone in your family group can see this visit.')));
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final now = ref.watch(clockProvider)();
    final l1 = b.level == 1;
    final first = b.patient.name.split(' ').first;
    final weekday = DateFormat('EEEE').format(b.apptAt.toLocal());
    final method = b.payment?.method ?? 'fpx';
    final helper = b.caregiverName ?? '';
    final pkg = b.package?.label;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Column(children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(color: Color(0xFFE4DCFB), shape: BoxShape.circle),
          child: Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(color: CwColors.primary, shape: BoxShape.circle),
              child: const Center(child: CwIcon(CwIcons.check, size: 34, strokeWidth: 3, color: CwColors.white)),
            ),
          ),
        ),
        SizedBox(height: l1 ? 16 : 10),
        const Tag('Payment successful', background: CwColors.tealSoft, color: CwColors.tealDark, fontSize: 12, padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
        const SizedBox(height: 10),
        Text(l1 ? 'Visit booked' : 'Escort booked', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 10),
        Text(
          l1
              ? "$first is all set for $weekday. We'll call $first the evening before with a reminder."
              : "${helper.isEmpty ? 'Your escort' : helper.split(' ').first} will stay with $first for the whole visit on $weekday. We'll call $first the evening before with a reminder.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5, color: CwColors.muted),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(10)),
          child: Text('Booking ID ${bookingRef(b.id)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CwColors.primaryDark)),
        ),
      ]),
      const SizedBox(height: 16),
      InfoTable(rows: [
        ('Patient', infoValue('${b.patient.name}, ${b.patient.age}')),
        ('Appointment', infoValue(dayTimeLabel(b.apptAt))),
        ('Hospital', infoValue(b.clinic.isEmpty ? placeName(b.hospitalId) : '${placeName(b.hospitalId)}, ${b.clinic}')),
        if (b.pickupAt != null) ('Pickup', infoValue('${timeLabel(b.pickupAt!)}, ${b.pickup.label}${l1 ? '' : ' · private ride'}')),
        ('Help', infoValue(l1 ? 'Level 1${pkg == null ? '' : ' · $pkg'}${helper.isEmpty ? '' : ' · $helper'}' : 'Level 2 · $helper (one-to-one)')),
        if (l1)
          (
            'Amount paid',
            Text.rich(
              TextSpan(text: formatRm(b.price.paidSen), style: const TextStyle(fontWeight: FontWeight.w800, color: CwColors.primaryDark), children: [
                TextSpan(text: ' · ${methodShort(method)}', style: const TextStyle(fontWeight: FontWeight.w600, color: CwColors.muted)),
              ]),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14),
            ),
          )
        else
          ('Payment method', infoValue(methodName(method))),
      ]),
      if (!l1) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: CwColors.teal, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final l in b.price.lines) ...[
              Row(children: [
                Expanded(child: Text(l.label, style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF)))),
                Text(formatRm(l.sen), style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
              ]),
              const SizedBox(height: 8),
            ],
            Container(height: 1, color: const Color(0x4DFFFFFF)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              const Expanded(child: Text('Amount paid', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CwColors.white))),
              Text(formatRm(b.price.paidSen), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CwColors.white)),
            ]),
            const SizedBox(height: 8),
            Text(
              '${b.payment?.paidAt == null ? '' : 'Paid ${DateFormat('d MMM yyyy, h:mm a').format(b.payment!.paidAt!.toLocal())} · '}Any unused time is refunded after the visit.',
              style: const TextStyle(fontSize: 11, height: 1.45, color: Color(0xE6FFFFFF)),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: _Action(
            icon: CwIcons.calendar,
            label: _cal ? 'Added' : 'Add to calendar',
            done: _cal,
            onTap: _addToCalendar,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Action(
            icon: '<circle cx="18" cy="5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="19" r="2.5"/><path d="m8.2 10.8 7.6-4.4M8.2 13.2l7.6 4.4"/>',
            label: _shared ? 'Sent to family group' : 'Share with family',
            done: _shared,
            onTap: _share,
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Text(
        l1
            ? '${cancelRuleText(b, now)} If more neighbours join before the group locks, the difference comes back to you automatically. Sample details and prices.'
            : '${cancelRuleText(b, now)} Receipt sent to your email. Sample details and prices.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, height: 1.5, color: CwColors.muted),
      ),
      const SizedBox(height: 16),
      BigButton(label: 'View visit', onPressed: () => context.go('/booking/${b.id}')),
      const SizedBox(height: 10),
      LinkButton(label: 'Back to home', onPressed: () => context.go('/home')),
    ]);
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.done, required this.onTap});
  final String icon;
  final String label;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = done ? CwColors.tealDark : CwColors.primaryDark;
    return Material(
      color: done ? CwColors.tealSoft : CwColors.lilac,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            CwIcon(icon, size: 18, strokeWidth: 2.2, color: fg),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg))),
          ]),
        ),
      ),
    );
  }
}
