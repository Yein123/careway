import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_sheet.dart';
import '../../core/widgets/design_kit.dart';
import '../../core/widgets/safety_button.dart';
import '../../data/models/booking.dart';
import '../../data/models/caregiver.dart';
import '../../data/models/delivery.dart';
import '../../data/providers.dart';
import '../../data/push.dart';
import '../home/home_screen.dart' show placeName, levelLabel, levelTone;
import '../visits/live_visit_screen.dart' show callNumber;
import 'cg_providers.dart';

/// Caregiver tab page: grey surface, 20 px padding, 16 px gaps.
class _Tab extends StatelessWidget {
  const _Tab({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: CgColors.surface,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]]],
          ),
        ),
      );
}

const _title = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CgColors.ink);
const _groupLabel = TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: CgColors.muted);

enum _ScheduleView { day, week, month }

DateTime _dayOf(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Monday of the week holding [d].
DateTime _weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// C6 · Caregiver: schedule (CgSchedule.dc.html). Day, week or month view;
/// tap any date to see its jobs.
class CgScheduleScreen extends ConsumerStatefulWidget {
  const CgScheduleScreen({super.key});

  @override
  ConsumerState<CgScheduleScreen> createState() => _CgScheduleScreenState();
}

class _CgScheduleScreenState extends ConsumerState<CgScheduleScreen> {
  _ScheduleView _view = _ScheduleView.week;
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final today = _dayOf(ref.watch(clockProvider)());
    final selected = _selected ?? today;
    final bookings = ref.watch(cgBookingsProvider);
    final deliveries = ref.watch(cgDeliveriesProvider).value ?? const <MedDelivery>[];
    final items = <(DateTime, Widget)>[
      for (final b in bookings.value ?? const <Booking>[])
        if (isActiveJob(b) || b.status.wire == 'awaiting_payment' || b.status.wire == 'completed')
          (
            b.pickupAt ?? b.apptAt,
            _Row(
              time: b.pickupAt ?? b.apptAt,
              title: b.patient.name,
              sub: '${placeName(b.hospitalId)}${switch (b.status.wire) {
                'in_progress' => ' · in progress',
                'awaiting_payment' => ' · waiting for payment',
                'completed' => ' · completed',
                _ => '',
              }}',
              tag: levelLabel(b.level),
              tone: levelTone(b.level),
              onTap: () => context.push('/cg/job/${b.id}'),
            )
          ),
      for (final d in deliveries)
        if (d.date != null && deliveryStageKeys.contains(d.status.wire))
          (
            d.date!,
            _Row(
              time: d.date!,
              title: 'Medicine run · ${d.patientName}',
              sub: '${d.pharmacyName} · ${d.window}${d.status == DeliveryStatus.delivered ? ' · delivered' : ''}',
              tag: 'Delivery',
              tone: (CwColors.deliverySoft, CwColors.deliveryBlue),
            )
          ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final byDay = <DateTime, List<Widget>>{};
    for (final (t, w) in items) {
      byDay.putIfAbsent(_dayOf(t), () => []).add(w);
    }

    // Days whose jobs are listed below the calendar.
    final List<DateTime> shownDays;
    final String period;
    switch (_view) {
      case _ScheduleView.day:
        shownDays = [selected];
        period = DateFormat('EEE, d MMM yyyy').format(selected);
      case _ScheduleView.week:
        final start = _weekStart(selected);
        shownDays = [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
        final end = shownDays.last;
        period = '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM yyyy').format(end)}';
      case _ScheduleView.month:
        shownDays = [selected];
        period = DateFormat('MMMM yyyy').format(selected);
    }

    void select(DateTime d) => setState(() => _selected = d);
    void shift(int dir) => select(switch (_view) {
          _ScheduleView.day => DateTime(selected.year, selected.month, selected.day + dir),
          _ScheduleView.week => DateTime(selected.year, selected.month, selected.day + 7 * dir),
          _ScheduleView.month => DateTime(selected.year, selected.month + dir, 1),
        });

    final listed = [for (final d in shownDays) if (byDay.containsKey(d)) d];

    return _Tab(children: [
      Row(children: [
        const Expanded(child: Text('Schedule', style: _title)),
        TextButton(
          onPressed: () => context.go('/cg'),
          style: TextButton.styleFrom(foregroundColor: CwColors.teal, padding: const EdgeInsets.symmetric(horizontal: 4)),
          child: const Text('Set availability', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ]),
      _ViewSwitch(view: _view, onChanged: (v) => setState(() => _view = v)),
      Row(children: [
        _NavButton(label: 'Previous', icon: CwIcons.back, onTap: () => shift(-1)),
        Expanded(child: Text(period, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CgColors.ink))),
        if (selected != today)
          TextButton(
            onPressed: () => select(today),
            style: TextButton.styleFrom(foregroundColor: CwColors.teal, padding: const EdgeInsets.symmetric(horizontal: 6)),
            child: const Text('Today', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        _NavButton(label: 'Next', icon: CwIcons.chevronRight, onTap: () => shift(1)),
      ]),
      if (_view == _ScheduleView.month)
        _MonthGrid(month: selected, selected: selected, today: today, hasJobs: byDay.containsKey, onPick: select)
      else
        _WeekStrip(start: _weekStart(selected), selected: selected, today: today, hasJobs: byDay.containsKey, onPick: select),
      AsyncView<List<Booking>>(
        value: bookings,
        onRetry: () => ref.invalidate(cgBookingsProvider),
        data: (_) => listed.isEmpty
            ? EmptyState(
                icon: Icons.event_available,
                title: 'Nothing scheduled',
                message: _view == _ScheduleView.week ? 'No jobs this week.' : 'No jobs on ${DateFormat('EEE d MMM').format(selected)}.',
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final day in listed) ...[
                  Text(
                    '${day == today ? 'TODAY · ' : ''}${DateFormat('EEE d MMM').format(day).toUpperCase()}',
                    style: _groupLabel,
                  ),
                  const SizedBox(height: 8),
                  for (final w in byDay[day]!) Padding(padding: const EdgeInsets.only(bottom: 8), child: w),
                  const SizedBox(height: 8),
                ],
              ]),
      ),
    ]);
  }
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.view, required this.onChanged});
  final _ScheduleView view;
  final ValueChanged<_ScheduleView> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          for (final (v, label) in const [(_ScheduleView.day, 'Day'), (_ScheduleView.week, 'Week'), (_ScheduleView.month, 'Month')])
            Expanded(
              child: Semantics(
                button: true,
                selected: v == view,
                child: Material(
                  color: v == view ? CwColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onChanged(v),
                    child: SizedBox(
                      height: 38,
                      child: Center(
                        child: Text(label,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: v == view ? CwColors.white : CgColors.ink)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: CgColors.soft,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(width: 36, height: 36, child: Center(child: CwIcon(icon, size: 18, strokeWidth: 2.4, color: CwColors.tealDark))),
          ),
        ),
      );
}

/// One tappable date: weekday (optional), day number and a dot when it has jobs.
class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.on, required this.isToday, required this.has, required this.onTap, this.weekday = false, this.height = 64});
  final DateTime day;
  final bool on;
  final bool isToday;
  final bool has;
  final VoidCallback onTap;
  final bool weekday;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = on ? CwColors.white : CgColors.ink;
    return Material(
      color: on ? CwColors.teal : CwColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday && !on ? const BorderSide(color: CwColors.teal, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        key: ValueKey('cg-day-${day.year}-${day.month}-${day.day}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (weekday) ...[
              Text(DateFormat('EEE').format(day), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(height: 2),
            ],
            Text('${day.day}', style: TextStyle(fontSize: weekday ? 16 : 14, fontWeight: FontWeight.w800, color: fg)),
            const SizedBox(height: 2),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: has ? (on ? CwColors.white : CwColors.teal) : Colors.transparent, shape: BoxShape.circle),
            ),
          ]),
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.start, required this.selected, required this.today, required this.hasJobs, required this.onPick});
  final DateTime start;
  final DateTime selected;
  final DateTime today;
  final bool Function(DateTime) hasJobs;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Builder(builder: (_) {
              final day = DateTime(start.year, start.month, start.day + i);
              return _DayCell(day: day, weekday: true, on: day == selected, isToday: day == today, has: hasJobs(day), onTap: () => onPick(day));
            }),
          ),
        ],
      ]);
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.selected, required this.today, required this.hasJobs, required this.onPick});
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final bool Function(DateTime) hasJobs;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final offset = first.weekday - 1; // Monday first
    final days = DateTime(month.year, month.month + 1, 0).day;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Row(children: [
          for (final d in const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
            Expanded(child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CgColors.muted))),
        ]),
        const SizedBox(height: 8),
        for (var week = 0; week * 7 < offset + days; week++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Builder(builder: (_) {
                    final n = week * 7 + i - offset + 1;
                    if (n < 1 || n > days) return const SizedBox(height: 44);
                    final day = DateTime(month.year, month.month, n);
                    return _DayCell(day: day, height: 44, on: day == selected, isToday: day == today, has: hasJobs(day), onTap: () => onPick(day));
                  }),
                ),
              ],
            ]),
          ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.time, required this.title, required this.sub, required this.tag, required this.tone, this.onTap});
  final DateTime time;
  final String title;
  final String sub;
  final String tag;
  final (Color, Color) tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = timeLabel(time).split(' ');
    return Material(
      color: CwColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: CgColors.soft, borderRadius: BorderRadius.circular(14)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(t.first, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CwColors.tealDark)),
                Text(t.last, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CwColors.tealDark)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CgColors.ink)),
                const SizedBox(height: 3),
                Text(sub, style: const TextStyle(fontSize: 12, color: CgColors.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            Tag(tag, background: tone.$1, color: tone.$2),
          ]),
        ),
      ),
    );
  }
}

/// C7 · Caregiver: patient updates (CgPatients.dc.html)
class CgPatientsScreen extends ConsumerStatefulWidget {
  const CgPatientsScreen({super.key});

  @override
  ConsumerState<CgPatientsScreen> createState() => _CgPatientsScreenState();
}

class _CgPatientsScreenState extends ConsumerState<CgPatientsScreen> {
  String? _pick;

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(cgBookingsProvider);
    final now = ref.watch(clockProvider)();
    return _Tab(children: [
      const Text('Patients', style: _title),
      AsyncView<List<Booking>>(
        value: bookings,
        onRetry: () => ref.invalidate(cgBookingsProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyState(icon: Icons.people_outline, title: 'No patients yet', message: 'Patients from your jobs show up here.'),
        data: (list) {
          final byPatient = <String, List<Booking>>{};
          for (final b in [...list]..sort((a, b) => b.apptAt.compareTo(a.apptAt))) {
            byPatient.putIfAbsent('${b.familyId}/${b.patientId}', () => []).add(b);
          }
          final keys = byPatient.keys.toList();
          final key = keys.contains(_pick) ? _pick! : keys.first;
          final visits = byPatient[key]!;
          final latest = visits.first;
          final upcoming = visits.where((b) => isActiveJob(b) && b.apptAt.isAfter(now)).toList()..sort((a, b) => a.apptAt.compareTo(b.apptAt));
          final past = visits.where((b) => b.summary != null).toList();
          final tones = [
            (CwColors.pinkSoft, CwColors.pink),
            (const Color(0xFFE4DCFB), CwColors.primaryDark),
            (CwColors.amberSoft, CwColors.amber),
            (CwColors.tealSoft, CwColors.teal),
          ];
          final tone = tones[keys.indexOf(key) % tones.length];
          final p = latest.patient;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LayoutBuilder(
              builder: (context, c) => SizedBox(
                height: 40,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: c.maxWidth + 20,
                  maxWidth: c.maxWidth + 20,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 20),
                    itemCount: keys.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final on = keys[i] == key;
                      final bp = byPatient[keys[i]]!.first.patient;
                      final t = tones[i % tones.length];
                      return Semantics(
                        button: true,
                        selected: on,
                        child: Material(
                          color: on ? CgColors.soft : CwColors.white,
                          shape: StadiumBorder(side: BorderSide(color: on ? CwColors.teal : CgColors.line, width: 2)),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () => setState(() => _pick = keys[i]),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6, right: 12),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: t.$1, shape: BoxShape.circle),
                                  child: Text(bp.initials, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: t.$2)),
                                ),
                                const SizedBox(width: 6),
                                Text(bp.name.split(' ').first,
                                    style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w800 : FontWeight.w700, color: on ? CwColors.tealDark : CgColors.ink)),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tone.$1, shape: BoxShape.circle),
                    child: Text(p.initials, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tone.$2)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${p.name}, ${p.age}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CgColors.ink)),
                      const SizedBox(height: 2),
                      Text(
                        upcoming.isNotEmpty
                            ? 'Next visit ${dayTimeLabel(upcoming.first.apptAt)} · ${placeName(upcoming.first.hospitalId)}'
                            : 'Last visit ${dayLabel(latest.apptAt)} · ${placeName(latest.hospitalId)}',
                        style: const TextStyle(fontSize: 12, color: CgColors.muted),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (p.allergy.isNotEmpty) Tag('Allergy: ${p.allergy}', background: CwColors.pinkSoft, color: const Color(0xFFA02A4C), fontSize: 12),
                  Tag(p.mobility.label, background: CgColors.soft, color: CwColors.tealDark, fontSize: 12),
                ]),
                if (p.talkNotes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(p.talkNotes, style: const TextStyle(fontSize: 12, height: 1.5, color: CgColors.ink2)),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            BigButton(label: 'Open latest job', color: CwColors.teal, height: 52, fontSize: 16, onPressed: () => context.push('/cg/job/${(upcoming.firstOrNull ?? latest).id}')),
            const SizedBox(height: 16),
            const Text('Past updates', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CgColors.ink)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
              child: past.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Visit summaries you write show up here.', style: TextStyle(fontSize: 13, color: CgColors.muted)),
                    )
                  : Column(children: [
                      for (var i = 0; i < past.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: CgColors.divider))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              const Tag('Summary', background: CwColors.successSoft, color: Color(0xFF1D6B45), padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3)),
                              const Spacer(),
                              Text(dayLabel(past[i].apptAt), style: const TextStyle(fontSize: 12, color: CgColors.muted)),
                            ]),
                            const SizedBox(height: 6),
                            Text(past[i].summary!.diagnosis, style: const TextStyle(fontSize: 13, height: 1.45, color: CgColors.ink)),
                          ]),
                        ),
                    ]),
            ),
          ]);
        },
      ),
    ]);
  }
}

/// C8 · Caregiver: account (CgAccount.dc.html)
class CgAccountScreen extends ConsumerWidget {
  const CgAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(caregiverProfileProvider);
    final now = ref.watch(clockProvider)();
    return _Tab(children: [
      AsyncView<CaregiverProfile?>(
        value: profile,
        onRetry: () => ref.invalidate(caregiverProfileProvider),
        isEmpty: (p) => p == null,
        empty: const EmptyState(icon: Icons.badge_outlined, title: 'Caregiver profile not set up', message: 'Ask your agency to finish your profile.'),
        data: (p) {
          p!;
          final valid = p.certificates.where((c) => c.isValidOn(now)).toList();
          Widget row(String icon, String title, String sub, VoidCallback onTap, {bool last = false}) => InkWell(
                onTap: onTap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: CgColors.divider))),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: CgColors.soft, borderRadius: BorderRadius.circular(10)),
                      child: Center(child: CwIcon(icon, size: 18, strokeWidth: 2.2, color: CwColors.tealDark)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: CgColors.ink)),
                        Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: CgColors.muted)),
                      ]),
                    ),
                    const CwIcon(CwIcons.chevronRight, size: 20, strokeWidth: 2.4, color: CgColors.faint),
                  ]),
                ),
              );
          void certSheet() => showCwSheet<void>(
                context,
                builder: (_) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Certificates', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  for (final c in p.certificates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        CwIcon(c.isValidOn(now) ? CwIcons.check : CwIcons.close, size: 18, strokeWidth: 2.6, color: c.isValidOn(now) ? CwColors.success : CwColors.pink),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.type.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                            Text(
                              '${c.verified ? 'Verified' : 'Not verified yet'} · ${c.expiresAt.isAfter(now) ? 'Expires' : 'Expired'} ${DateFormat('d MMM yyyy').format(c.expiresAt.toLocal())}',
                              style: const TextStyle(fontSize: 12, color: CgColors.muted),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 4),
                  const Text('Expired or unverified certificates stop matching for jobs that need them. Your agency renews them.',
                      style: TextStyle(fontSize: 12, height: 1.5, color: CgColors.muted)),
                ]),
              );
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: CwColors.teal, shape: BoxShape.circle),
                child: Text(p.initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: CwColors.white)),
              ),
            ),
            const SizedBox(height: 8),
            Text(p.displayName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CgColors.ink)),
            const SizedBox(height: 8),
            Text(p.agency, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: CgColors.muted)),
            const SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
              for (final c in valid.where((c) => c.verified).take(2))
                Tag('✓ ${c.type.label}', background: CwColors.successSoft, color: const Color(0xFF1D6B45), fontSize: 12),
              Tag('${p.rating} ★ · ${p.ratingCount} visits', background: CgColors.soft, color: CwColors.tealDark, fontSize: 12),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                row('<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 8h6M9 12h6M9 16h3"/>', 'Certificates',
                    p.certificates.isEmpty
                        ? 'None on file'
                        : p.certificates
                            .map((c) => '${c.type.label}${c.isValidOn(now) ? ' (until ${DateFormat('MMM yyyy').format(c.expiresAt.toLocal())})' : ' (expired)'}')
                            .join(', '),
                    certSheet),
                row('<path d="M3 12h4l3-8 4 16 3-8h4"/>', 'Services I offer', p.skills.map((s) => s.label).join(', '), certSheet),
                row('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>', 'Languages', p.languages.join(', '), () {}),
                row(CwIcons.pinAlt, 'Work zone', p.zone, () {}),
                row('<path d="M12 3 5 6v5c0 4.5 3 8 7 10 4-2 7-5.5 7-10V6z"/>', 'Safety and incident report', 'Report a fall, injury or problem',
                    () => callNumber(context, coordinatorNumber),
                    last: true),
              ]),
            ),
            const SizedBox(height: 16),
            Material(
              color: CwColors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => signOutEverywhere(ref),
                child: const SizedBox(
                  height: 52,
                  child: Center(child: Text('Sign out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFA02A4C)))),
                ),
              ),
            ),
          ]);
        },
      ),
    ]);
  }
}
