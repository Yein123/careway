import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../data/models/booking.dart';
import '../../data/models/family.dart';
import '../../data/models/firestore_utils.dart' show initialsOf;
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../booking/booking_draft.dart';
import '../home/home_screen.dart' show placeName, levelLabel, levelTone;
import 'rate_sheet.dart';

enum _Tab { upcoming, ongoing, past }

const _ok = (CwColors.successSoft, Color(0xFF1D6B45));
const _wait = (CwColors.amberSoft, CwColors.amber);
const _off = (CwColors.surface, CwColors.muted);

(String, (Color, Color)) _status(BookingStatus s) => switch (s) {
      BookingStatus.draft => ('Waitlist', _wait),
      BookingStatus.pendingCaregiver => ('Pending', _wait),
      BookingStatus.awaitingPayment => ('Pay to confirm', _wait),
      BookingStatus.confirmed => ('Confirmed', _ok),
      BookingStatus.notMatched => ('Not successful', _off),
      BookingStatus.cancelled => ('Cancelled', _off),
      BookingStatus.expired => ('Expired', _off),
      BookingStatus.completed => ('Completed', _ok),
      BookingStatus.inProgress => ('Live', _ok),
    };

String _where(Booking b) => b.clinic.isEmpty ? placeName(b.hospitalId) : '${placeName(b.hospitalId)} · ${b.clinic}';

/// 17 · My visits (Visits.dc.html)
class VisitsScreen extends ConsumerStatefulWidget {
  const VisitsScreen({super.key});

  @override
  ConsumerState<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends ConsumerState<VisitsScreen> {
  _Tab _tab = _Tab.upcoming;
  String? _who; // patient id filter
  String? _open; // expanded past summary

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(familyBookingsProvider);
    final patients = ref.watch(patientsProvider).value ?? const <Patient>[];
    final all = (bookings.value ?? const <Booking>[]).where((b) => _who == null || b.patientId == _who).toList();
    final byTab = {
      _Tab.upcoming: all.where((b) => !b.status.isTerminal && b.status != BookingStatus.inProgress && b.status != BookingStatus.notMatched).toList()
        ..sort((a, b) => a.apptAt.compareTo(b.apptAt)),
      _Tab.ongoing: all.where((b) => b.status == BookingStatus.inProgress).toList(),
      _Tab.past: all.where((b) => b.status.isTerminal || b.status == BookingStatus.notMatched).toList()
        ..sort((a, b) => b.apptAt.compareTo(a.apptAt)),
    };
    final list = byTab[_tab]!;
    final whoName = _who == null ? 'Whole family' : patients.where((p) => p.id == _who).map((p) => p.name.split(' ').first).firstOrNull ?? '';

    return Scaffold(
      backgroundColor: CwColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('My visits', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: () => startBooking(context, ref),
                    style: TextButton.styleFrom(
                      backgroundColor: CwColors.primary,
                      foregroundColor: CwColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontFamily: cwFont, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      CwIcon(CwIcons.plus, size: 16, strokeWidth: 2.6, color: CwColors.white),
                      SizedBox(width: 6),
                      Text('Book'),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFFEFECF6), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  for (final t in _Tab.values) ...[
                    if (t != _Tab.upcoming) const SizedBox(width: 4),
                    Expanded(
                      child: _Segment(
                        label: switch (t) { _Tab.upcoming => 'Upcoming', _Tab.ongoing => 'Ongoing', _Tab.past => 'Past' },
                        count: byTab[t]!.length,
                        on: _tab == t,
                        onTap: () => setState(() => _tab = t),
                      ),
                    ),
                  ],
                ]),
              ),
              if (patients.length > 1) ...[
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, c) => SizedBox(
                    height: 40,
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: c.maxWidth + 20,
                      maxWidth: c.maxWidth + 20,
                      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(right: 20), children: [
                        _WhoChip(label: 'Whole family', on: _who == null, onTap: () => setState(() => _who = null)),
                        for (var i = 0; i < patients.length; i++) ...[
                          const SizedBox(width: 8),
                          _WhoChip(
                            label: patients[i].name.split(' ').first,
                            initials: patients[i].initials,
                            tone: personTone(i),
                            on: _who == patients[i].id,
                            onTap: () => setState(() => _who = patients[i].id),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          Expanded(
            child: AsyncView<List<Booking>>(
              value: bookings,
              onRetry: () => ref.invalidate(familyBookingsProvider),
              data: (_) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  if (list.isEmpty)
                    _EmptyCard(switch (_tab) {
                      _Tab.ongoing => ('Nothing happening now', '$whoName has no visit in progress today.'),
                      _Tab.upcoming => ('No upcoming visits', 'Book a visit and it will show here.'),
                      _Tab.past => ('No past visits yet', 'Finished visits and their summaries show here.'),
                    })
                  else
                    for (final b in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: switch (_tab) {
                          _Tab.upcoming => _UpcomingCard(b),
                          _Tab.ongoing => _OngoingCard(b, ref.watch(clockProvider)()),
                          _Tab.past => _PastCard(b, open: _open == b.id, onToggle: () => setState(() => _open = _open == b.id ? null : b.id)),
                        },
                      ),
                  if (_tab == _Tab.ongoing && list.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text("Only visits happening today show here. You'll get a notification at each step.",
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.5, color: CwColors.muted)),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.count, required this.on, required this.onTap});
  final String label;
  final int count;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: on ? CwColors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: on ? const [BoxShadow(color: Color(0x141E1B2E), blurRadius: 3, offset: Offset(0, 1))] : null,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w800 : FontWeight.w700, color: on ? CwColors.ink : CwColors.muted)),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? CwColors.primary : const Color(0xFFE1DDEB), borderRadius: BorderRadius.circular(9)),
                child: Text('$count', style: TextStyle(fontSize: 11, height: 1, fontWeight: FontWeight.w800, color: on ? CwColors.white : CwColors.muted)),
              ),
            ]),
          ),
        ),
      );
}

class _WhoChip extends StatelessWidget {
  const _WhoChip({required this.label, required this.on, required this.onTap, this.initials, this.tone});
  final String label;
  final String? initials;
  final (Color, Color)? tone;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        child: Material(
          color: on ? CwColors.lilac : CwColors.white,
          shape: StadiumBorder(side: BorderSide(color: on ? CwColors.primary : CwColors.line, width: 2)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.only(left: initials == null ? 12 : 6, right: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (initials != null) ...[
                  CircleAvatarText(initials!, size: 26, tone: tone!, fontSize: 10),
                  const SizedBox(width: 6),
                ],
                Text(label,
                    style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w800 : FontWeight.w700, color: on ? const Color(0xFF3A2591) : CwColors.ink)),
              ]),
            ),
          ),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.text);
  final (String, String) text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Text(text.$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(text.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.5, color: CwColors.muted)),
        ]),
      );
}

class _DateBox extends StatelessWidget {
  const _DateBox(this.d, {required this.tone});
  final DateTime d;
  final (Color, Color) tone;

  @override
  Widget build(BuildContext context) {
    final l = d.toLocal();
    const dows = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mons = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final small = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tone.$2);
    return Container(
      width: 52,
      height: 58,
      decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(dows[l.weekday - 1], style: small),
        Text('${l.day}', style: TextStyle(fontSize: 20, height: 1.1, fontWeight: FontWeight.w800, color: tone.$2)),
        Text(mons[l.month - 1], style: small),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.tone);
  final String text;
  final (Color, Color) tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tone.$2)),
      );
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard(this.b);
  final Booking b;

  @override
  Widget build(BuildContext context) {
    final status = _status(b.status);
    final pickup = b.pickupAt == null ? '' : ' · pickup ${timeLabel(b.pickupAt!)}${b.pickup.label.isEmpty ? '' : ', ${b.pickup.label}'}';
    final helper = b.caregiverName ?? (b.level == 1 ? 'Finding a group' : 'Finding a helper');
    final link = switch (b.status) {
      BookingStatus.pendingCaregiver => '/booking/${b.id}/pending',
      BookingStatus.awaitingPayment => b.level == 1 ? '/booking/${b.id}/package' : '/booking/${b.id}/pay',
      _ => '/booking/${b.id}',
    };
    return Material(
      color: CwColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(link),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _DateBox(b.apptAt, tone: b.level == 1 ? (CwColors.primary, CwColors.white) : (CwColors.tealSoft, CwColors.tealDark)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.patient.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(_where(b), style: const TextStyle(fontSize: 12, color: Color(0xFF3D3955))),
                  const SizedBox(height: 3),
                  Text('${timeLabel(b.apptAt)}$pickup', style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEFECF6)))),
              child: Row(children: [
                _Pill(levelLabel(b.level), levelTone(b.level)),
                const SizedBox(width: 8),
                Expanded(child: Text(helper, style: const TextStyle(fontSize: 12, color: CwColors.muted))),
                const SizedBox(width: 8),
                _Pill(status.$1, status.$2),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _OngoingCard extends StatelessWidget {
  const _OngoingCard(this.b, this.now);
  final Booking b;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final keys = b.stepKeys;
    final last = b.steps.isEmpty ? null : b.steps.last;
    final mins = last == null ? null : now.difference(last.at).inMinutes;
    final current = last?.key ?? '';
    const white90 = Color(0xE6FFFFFF);
    return Material(
      color: CwColors.primary,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/booking/${b.id}/live'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF7BE3B4),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x4D7BE3B4), spreadRadius: 4)],
                ),
              ),
              const SizedBox(width: 8),
              const Text('LIVE NOW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: CwColors.white)),
              const Spacer(),
              if (mins != null)
                Text(mins < 1 ? 'Updated just now' : 'Updated $mins min ago', style: const TextStyle(fontSize: 12, color: Color(0xD9FFFFFF))),
            ]),
            const SizedBox(height: 12),
            Text('${b.patient.name.split(' ').first} · ${(stepLabels[current] ?? 'on the way').toLowerCase()}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CwColors.white)),
            const SizedBox(height: 3),
            Text('${_where(b)}${b.caregiverName == null ? '' : ' · with ${b.caregiverName}'}', style: const TextStyle(fontSize: 13, color: white90)),
            const SizedBox(height: 12),
            Semantics(
              label: 'Step ${b.steps.length + 1} of ${keys.length}',
              child: Row(children: [
                for (var i = 0; i < keys.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i < b.steps.length ? CwColors.white : (i == b.steps.length ? const Color(0x8CFFFFFF) : const Color(0x40FFFFFF)),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(
                  [for (final s in b.steps.take(2)) '${(stepLabels[s.key] ?? '').split(' ').first} ${timeLabel(s.at).replaceAll(RegExp(r' [AP]M$'), '')}'].join(' · '),
                  style: const TextStyle(fontSize: 12, color: white90),
                ),
              ),
              const Text('Track ›', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: CwColors.white)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _PastCard extends ConsumerWidget {
  const _PastCard(this.b, {required this.open, required this.onToggle});
  final Booking b;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = b.summary;
    final first = b.patient.name.split(' ').first;
    final done = b.status == BookingStatus.completed;
    final net = b.price.paidSen - b.price.refundSen;
    final rated = b.rating != null;
    final meta = [
      'Level ${b.level}',
      if (b.caregiverName != null) b.caregiverName!,
      if (done) formatRm(net) else _status(b.status).$1,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _DateBox(b.apptAt, tone: (CwColors.lilac, CwColors.primaryDark)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.patient.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(_where(b), style: const TextStyle(fontSize: 12, color: Color(0xFF3D3955))),
              const SizedBox(height: 3),
              Text(meta, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
            ]),
          ),
        ]),
        if (s != null) ...[
          const SizedBox(height: 10),
          Semantics(
            expanded: open,
            button: true,
            child: Material(
              color: CwColors.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onToggle,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    const Expanded(
                      child: Text('Visit summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
                    ),
                    RotatedBox(
                      quarterTurns: open ? 2 : 0,
                      child: const CwIcon('<path d="m6 9 6 6 6-6"/>', size: 18, strokeWidth: 2.4, color: CwColors.primaryDark),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          if (open) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final row in _summaryRows(b, s)) Padding(padding: const EdgeInsets.only(bottom: 10), child: row),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: CwColors.surface, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    "Written by ${s.writtenBy.isEmpty ? (b.caregiverName ?? 'your helper') : s.writtenBy} after the visit. Not medical advice; check the doctor's letter for details.",
                    style: const TextStyle(fontSize: 11, height: 1.45, color: CwColors.muted),
                  ),
                ),
              ]),
            ),
          ],
        ],
        if (done) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _SmallButton(
                label: rated ? 'Rated ★ ${b.rating!.stars}' : 'Rate this visit',
                background: rated ? CwColors.surface : CwColors.primary,
                foreground: rated ? CwColors.muted : CwColors.white,
                onTap: rated
                    ? null
                    : () => RateSheet.show(
                          context,
                          title: "How was $first's visit?",
                          subtitle: [dayLabel(b.apptAt), if (b.caregiverName != null) b.caregiverName!, placeName(b.hospitalId)].join(' · '),
                          initials: initialsOf(b.caregiverName ?? '?'),
                          onSubmit: (r) => ref.read(bookingRepoProvider).rate(b.id, r),
                        ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SmallButton(
                label: 'Book follow-up',
                background: CwColors.lilac,
                foreground: CwColors.primaryDark,
                onTap: () => startBooking(context, ref, level: b.level, patientId: b.patientId),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

List<Widget> _summaryRows(Booking b, VisitSummary s) {
  Widget label(String k) => Text(k, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: CwColors.muted));
  Widget text(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        label(k),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontSize: 13, height: 1.5)),
      ]);
  String? visitTime() {
    if (b.steps.length < 2) return null;
    final start = b.steps.first.at;
    final end = b.steps.last.at;
    final d = end.difference(start);
    return 'Picked up ${timeLabel(start)} · home ${timeLabel(end)} (${d.inHours} h ${d.inMinutes % 60} min)';
  }

  final time = visitTime();
  return [
    if (s.seenBy.isNotEmpty) text('SEEN BY', s.seenBy),
    if (s.diagnosis.isNotEmpty) text("DOCTOR'S ADVICE", s.diagnosis),
    if (s.medicines.isNotEmpty) text('MEDICINE COLLECTED', s.medicines),
    if (s.instructions.isNotEmpty)
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        label('MEDICAL INSTRUCTIONS'),
        const SizedBox(height: 4),
        for (final it in s.instructions)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 7, right: 8),
                decoration: const BoxDecoration(color: CwColors.primary, shape: BoxShape.circle),
              ),
              Expanded(child: Text(it, style: const TextStyle(fontSize: 13, height: 1.45))),
            ]),
          ),
      ]),
    if (s.nextAppt.isNotEmpty) text('NEXT APPOINTMENT', s.nextAppt),
    if (s.notes.isNotEmpty) text('NOTES', s.notes),
    if (time != null) text('VISIT TIME', time),
  ];
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.background, required this.foreground, this.onTap});
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: foreground))),
          ),
        ),
      );
}
