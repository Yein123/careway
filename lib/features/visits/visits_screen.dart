import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/step_label.dart';
import '../../data/models/booking.dart';
import '../../data/models/family.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../booking/booking_draft.dart';
import '../home/home_screen.dart' show placeName, levelLabel;
import 'rate_sheet.dart';

enum _Tab { upcoming, now, past }

const _statusText = {
  BookingStatus.draft: 'Waitlist',
  BookingStatus.pendingCaregiver: 'Finding caregiver',
  BookingStatus.awaitingPayment: 'Pay to confirm',
  BookingStatus.confirmed: 'Confirmed',
  BookingStatus.notMatched: 'Not successful',
  BookingStatus.cancelled: 'Cancelled',
  BookingStatus.expired: 'Expired',
  BookingStatus.completed: 'Completed',
  BookingStatus.inProgress: 'Live',
};

/// 17 · My visits (Visits.dc.html)
class VisitsScreen extends ConsumerStatefulWidget {
  const VisitsScreen({super.key});

  @override
  ConsumerState<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends ConsumerState<VisitsScreen> {
  _Tab _tab = _Tab.upcoming;
  String? _who; // patient id filter

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(familyBookingsProvider);
    final patients = ref.watch(patientsProvider).value ?? const <Patient>[];
    final all = (bookings.value ?? const <Booking>[]).where((b) => _who == null || b.patientId == _who).toList();
    final byTab = {
      _Tab.upcoming: all.where((b) => !b.status.isTerminal && b.status != BookingStatus.inProgress).toList()
        ..sort((a, b) => a.apptAt.compareTo(b.apptAt)),
      _Tab.now: all.where((b) => b.status == BookingStatus.inProgress).toList(),
      _Tab.past: all.where((b) => b.status.isTerminal).toList()..sort((a, b) => b.apptAt.compareTo(a.apptAt)),
    };
    final list = byTab[_tab]!;

    return CwPage(
      title: 'My visits',
      showBack: false,
      action: TextButton(onPressed: () => startBooking(context, ref), child: const Text('Book', style: TextStyle(fontWeight: FontWeight.w800))),
      children: [
        Row(children: [
          for (final t in _Tab.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: CwChip(
                  label: '${switch (t) { _Tab.upcoming => 'Upcoming', _Tab.now => 'Now', _Tab.past => 'Past' }} (${byTab[t]!.length})',
                  selected: _tab == t,
                  onTap: () => setState(() => _tab = t),
                ),
              ),
            ),
        ]),
        const Gap(10),
        if (patients.length > 1)
          Wrap(spacing: 8, runSpacing: 8, children: [
            CwChip(label: 'Everyone', selected: _who == null, onTap: () => setState(() => _who = null)),
            for (final p in patients)
              CwChip(label: p.name.split(' ').first, selected: _who == p.id, onTap: () => setState(() => _who = p.id)),
          ]),
        const Gap(14),
        AsyncView<List<Booking>>(
          value: bookings,
          onRetry: () => ref.invalidate(familyBookingsProvider),
          data: (_) {
            if (list.isEmpty) {
              return switch (_tab) {
                _Tab.now => const EmptyState(
                    icon: Icons.directions_walk,
                    title: 'Nothing happening now',
                    message: "Only visits happening today show here. You'll get a notification at each step.",
                  ),
                _Tab.upcoming => const EmptyState(icon: Icons.event_available, title: 'No upcoming visits'),
                _Tab.past => const EmptyState(icon: Icons.history, title: 'No past visits yet'),
              };
            }
            return Column(children: [
              for (final b in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _tab == _Tab.past ? _PastCard(b) : _VisitCard(b, live: _tab == _Tab.now),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox(this.d);
  final DateTime d;

  @override
  Widget build(BuildContext context) {
    final l = d.toLocal();
    const dows = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const mons = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(dows[l.weekday - 1], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
        Text('${l.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(mons[l.month - 1], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CwColors.muted)),
      ]),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard(this.b, {required this.live});
  final Booking b;
  final bool live;

  @override
  Widget build(BuildContext context) => CwCard(
        onTap: () => context.push(live ? '/booking/${b.id}/live' : '/booking/${b.id}'),
        child: Row(children: [
          _DateBox(b.apptAt),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.patient.name, style: CwText.bodyBold),
              Text('${placeName(b.hospitalId)} · ${timeLabel(b.apptAt)}', style: CwText.small),
              Text('${levelLabel(b.level)}${b.caregiverName == null ? '' : ' · ${b.caregiverName}'}', style: CwText.small),
            ]),
          ),
          CwBadge(live ? 'LIVE NOW' : _statusText[b.status]!.toUpperCase(),
              color: live ? CwColors.white : CwColors.primaryDark, background: live ? CwColors.success : CwColors.lilac),
        ]),
      );
}

class _PastCard extends ConsumerStatefulWidget {
  const _PastCard(this.b);
  final Booking b;

  @override
  ConsumerState<_PastCard> createState() => _PastCardState();
}

class _PastCardState extends ConsumerState<_PastCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final s = b.summary;
    final first = b.patient.name.split(' ').first;
    final net = b.price.paidSen - b.price.refundSen;
    return CwCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _DateBox(b.apptAt),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.patient.name, style: CwText.bodyBold),
              Text(placeName(b.hospitalId), style: CwText.small),
              Text(
                '${levelLabel(b.level)}${b.caregiverName == null ? '' : ' · ${b.caregiverName}'}${b.status == BookingStatus.completed ? ' · ${formatRm(net)}' : ''}',
                style: CwText.small,
              ),
            ]),
          ),
          if (b.status != BookingStatus.completed) CwBadge(_statusText[b.status]!.toUpperCase(), color: CwColors.muted, background: CwColors.surface),
        ]),
        if (s != null) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                const Text('Visit summary', style: TextStyle(fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
                Icon(_open ? Icons.expand_less : Icons.expand_more, color: CwColors.primaryDark),
              ]),
            ),
          ),
          if (_open) ...[
            KeyValueRow('Seen by', s.seenBy),
            KeyValueRow('What the doctor said', s.diagnosis),
            if (s.nextAppt.isNotEmpty) KeyValueRow('Next appointment', s.nextAppt),
            if (s.medicines.isNotEmpty) KeyValueRow('Medicines', s.medicines),
            for (final it in s.instructions)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  ', style: CwText.body),
                  Expanded(child: Text(it, style: CwText.body)),
                ]),
              ),
            if (s.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.notes, style: CwText.muted)),
            const SizedBox(height: 6),
            Text("Written by ${s.writtenBy.isEmpty ? (b.caregiverName ?? 'your helper') : s.writtenBy} after the visit. Not medical advice; check the doctor's letter for details.",
                style: CwText.small),
          ],
        ],
        if (b.status == BookingStatus.completed) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: b.rating == null
                  ? TextButton(
                      onPressed: () async {
                        final r = await RateSheet.show(context,
                            title: "How was $first's visit?", subtitle: 'Rate ${b.caregiverName ?? 'your helper'}');
                        if (r != null) await ref.read(bookingRepoProvider).rate(b.id, r);
                      },
                      child: const Text('Rate this visit', style: TextStyle(fontWeight: FontWeight.w800)),
                    )
                  : Text('You rated ${b.rating!.stars}', style: CwText.bodyBold),
            ),
            TextButton(
              onPressed: () => startBooking(context, ref, level: b.level, patientId: b.patientId),
              child: const Text('Book follow-up', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ],
      ]),
    );
  }
}
