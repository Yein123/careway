import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/design_kit.dart';
import '../../data/api.dart';
import '../../data/models/booking.dart';
import '../../data/models/firestore_utils.dart' show initialsOf;
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../../domain/pricing.dart' show GroupPackage;
import '../home/home_screen.dart' show placeName, levelLabel;
import '../visits/live_visit_screen.dart' show callNumber;
import 'booking_common.dart';
import 'booking_draft.dart';
import 'confirmed_screen.dart' show bookingRef;
import 'submit.dart';

const _bring = ['MyKad', 'Appointment card', 'All current medicines', 'Home readings, like blood pressure'];

/// 21 · Upcoming visit (Upcoming.dc.html), plus the status of any booking.
class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return DesignScaffold(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        const PageHeader(title: 'Upcoming visit', help: true),
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
  bool _confirming = false;
  final List<bool> _got = List.filled(_bring.length, false);

  Future<void> _cancel() async {
    final b = widget.b;
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
      if (mounted) setState(() => _confirming = false);
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
    final local = b.apptAt.toLocal();
    final days = DateTime(local.year, local.month, local.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final first = b.patient.name.split(' ').first;
    final l1 = b.level == 1;
    final cancellable = const {
      BookingStatus.draft,
      BookingStatus.pendingCaregiver,
      BookingStatus.awaitingPayment,
      BookingStatus.confirmed,
      BookingStatus.notMatched,
    }.contains(b.status);

    Widget? statusCard() => switch (b.status) {
          BookingStatus.draft when b.waitlist => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: CwColors.amberSoft, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('On the waitlist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CwColors.amber)),
                const SizedBox(height: 2),
                const Text("We'll tell you if a seat opens up. Nothing is charged until you confirm.",
                    style: TextStyle(fontSize: 13, height: 1.45, color: kInk2)),
                const SizedBox(height: 12),
                BigButton(
                  label: 'Request to join now',
                  height: 50,
                  fontSize: 15,
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
              () => context.push(l1 ? '/booking/${b.id}/package' : '/booking/${b.id}/pay')),
          BookingStatus.notMatched => _Link('Not successful', 'Nothing has been charged. See your options.', () => context.push('/booking/${b.id}/not-found')),
          BookingStatus.inProgress => _Link('Happening now', 'Follow the visit live', () => context.push('/booking/${b.id}/live')),
          BookingStatus.completed => _Link('Visit complete', 'Read the summary and rate the visit', () => context.go('/visits')),
          BookingStatus.cancelled => const _Note('This visit was cancelled.'),
          BookingStatus.expired => const _Note('This request expired. Nothing was charged.'),
          _ => null,
        };

    final status = statusCard();
    final pickup = b.pickupAt ?? b.apptAt.subtract(const Duration(hours: 1));
    final helperFirst = b.caregiverName?.split(' ').first;
    final plan = [
      (timeLabel(pickup), 'Pickup${b.pickup.label.isEmpty ? '' : ' · ${b.pickup.label}'}', l1 ? 'Shared ride with neighbours' : 'Private ride'),
      (
        timeLabel(b.apptAt.subtract(const Duration(minutes: 15))),
        'Arrive at ${placeName(b.hospitalId).startsWith('Klinik') ? 'clinic' : 'hospital'}',
        l1 ? '${helperFirst ?? 'Your helper'} walks $first to registration' : '${helperFirst ?? 'Your escort'} stays with $first throughout',
      ),
      (timeLabel(b.apptAt), 'Appointment', b.clinic),
      (
        'When ready',
        'Ride home',
        l1
            ? (b.package == GroupPackage.saver ? 'Next scheduled return: 12:30 or 3:30 PM' : 'Tap Ready for pickup on the day')
            : 'As soon as $first is done',
      ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (status != null) ...[status, const SizedBox(height: 16)],
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: l1 ? CwColors.primary : CwColors.teal, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(days <= 0 ? 'Today' : 'In', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xE6FFFFFF))),
                if (days > 0)
                  Text('$days day${days == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 44, height: 1, fontWeight: FontWeight.w800, letterSpacing: -1, color: CwColors.white)),
              ]),
            ),
            Tag(levelLabel(b.level), background: const Color(0x33FFFFFF), color: CwColors.white, fontSize: 12, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
          ]),
          const SizedBox(height: 14),
          Text('${DateFormat('EEE d MMM yyyy').format(local)} · ${timeLabel(b.apptAt)}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CwColors.white)),
          const SizedBox(height: 3),
          Text('${b.patient.name} · ${placeName(b.hospitalId)}', style: const TextStyle(fontSize: 13, color: Color(0xEBFFFFFF))),
        ]),
      ),
      if (b.caregiverName != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            CircleAvatarText(initialsOf(b.caregiverName!), size: 52, tone: (CwColors.tealSoft, CwColors.teal), fontSize: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l1 ? 'Your helper' : 'Your escort', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CwColors.muted)),
                const SizedBox(height: 2),
                Text(b.caregiverName!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text('Background-checked · first aid trained', style: TextStyle(fontSize: 12, color: CwColors.muted)),
              ]),
            ),
            if ((b.caregiverPhone ?? '').isNotEmpty)
              Semantics(
                button: true,
                label: 'Call $helperFirst',
                excludeSemantics: true,
                child: Material(
                  color: CwColors.tealSoft,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => callNumber(context, b.caregiverPhone!),
                    child: const SizedBox(width: 48, height: 48, child: Center(child: CwIcon(CwIcons.phone, size: 18, strokeWidth: 2.2, color: CwColors.tealDark))),
                  ),
                ),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      const SectionLabel('Plan for the day', size: 15),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          for (var i = 0; i < plan.length; i++)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: 64,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(plan[i].$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 12,
                  child: Column(children: [
                    const SizedBox(height: 3),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: CwColors.white, shape: BoxShape.circle, border: Border.all(color: CwColors.primary, width: 3)),
                    ),
                    if (i < plan.length - 1)
                      Expanded(child: Container(width: 2, constraints: const BoxConstraints(minHeight: 22), color: const Color(0xFFE4DCFB))),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(plan[i].$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(plan[i].$3, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                    ]),
                  ),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        const Expanded(child: SectionLabel('Remember to bring', size: 15)),
        Text('${_got.where((g) => g).length} of ${_bring.length} ready', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CwColors.muted)),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          for (var i = 0; i < _bring.length; i++)
            Semantics(
              checked: _got[i],
              child: InkWell(
                onTap: () => setState(() => _got[i] = !_got[i]),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: kLine))),
                  child: Row(children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _got[i] ? CwColors.primary : CwColors.white,
                        border: Border.all(color: _got[i] ? CwColors.primary : const Color(0xFFC9C4D9), width: 2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: _got[i] ? const Center(child: CwIcon(CwIcons.check, size: 14, strokeWidth: 3, color: CwColors.white)) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_bring[i], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ),
            ),
        ]),
      ),
      if (b.price.paidSen > 0) ...[
        const SizedBox(height: 16),
        InfoTable(rows: [
          ('Booking ID', infoValue(bookingRef(b.id))),
          ('Paid', infoValue(formatRm(b.price.paidSen))),
          if (b.price.refundSen > 0) ('Refunded', infoValue(formatRm(b.price.refundSen))),
          if (b.price.creditSen > 0) ('CareWay credit', infoValue(formatRm(b.price.creditSen))),
        ]),
      ],
      if (cancellable) ...[
        const SizedBox(height: 16),
        if (!_confirming)
          Row(children: [
            Expanded(
              child: _Pill(
                label: 'Reschedule',
                background: CwColors.lilac,
                foreground: CwColors.primaryDark,
                onTap: () {
                  startBooking(context, ref, level: b.level, patientId: b.patientId);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Pill(label: 'Cancel visit', background: CwColors.white, foreground: const Color(0xFFA02A4C), onTap: () => setState(() => _confirming = true)),
            ),
          ])
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CwColors.white,
              border: Border.all(color: CwColors.pink, width: 2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text("Cancel $first's visit?", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(b.status == BookingStatus.confirmed ? cancelRuleText(b, now) : 'Nothing has been charged.',
                  style: const TextStyle(fontSize: 13, height: 1.45, color: CwColors.muted)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _confirming = false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kInk2,
                        side: const BorderSide(color: CwColors.line, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontFamily: cwFont, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Keep visit'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BigButton(label: 'Yes, cancel', color: CwColors.pink, height: 48, fontSize: 14, radius: 12, loading: _busy, onPressed: _cancel),
                ),
              ]),
            ]),
          ),
      ],
    ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.background, required this.foreground, required this.onTap});
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(height: 52, child: Center(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: foreground)))),
        ),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}

class _Link extends StatelessWidget {
  const _Link(this.title, this.body, this.onTap);
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: CwColors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(body, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                ]),
              ),
              const CwIcon(CwIcons.chevronRight, size: 18, strokeWidth: 2.4, color: CwColors.muted),
            ]),
          ),
        ),
      );
}
