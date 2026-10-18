import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/places.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/design_kit.dart';
import '../../data/models/booking.dart';
import '../../data/models/family.dart';
import '../../data/providers.dart';
import '../../domain/needs.dart';
import '../family/patient_form.dart';
import '../family/patient_profile_screen.dart';
import 'booking_draft.dart';

/// 3 · Book a visit (Book.dc.html) and 23 · Book from a service tile
/// (BookService.dc.html, when the draft already has a preferred level).
class BookScreen extends ConsumerStatefulWidget {
  const BookScreen({super.key, this.service});

  /// 'level1' | 'level2' (deep link); Home tiles set the draft's preferred level instead.
  final String? service;

  @override
  ConsumerState<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends ConsumerState<BookScreen> {
  bool _addingNew = false;
  bool _calOpen = true;
  bool _timeOpen = false;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final first = ref.read(clockProvider)().toLocal();
    _month = DateTime(first.year, first.month);
    final pref = switch (widget.service) { 'level1' => 1, 'level2' => 2, _ => null };
    if (pref != null) {
      Future.microtask(() => ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(preferredLevel: pref)));
    }
  }

  void _set(BookingDraft Function(BookingDraft) f) => ref.read(bookingDraftProvider.notifier).update(f);

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final family = ref.watch(patientsProvider).value ?? const <Patient>[];
    final oneOff = (ref.watch(allPatientsProvider).value ?? const <Patient>[])
        .where((p) => p.id == draft.patientId && !p.inFamilyList);
    final patients = [...family, ...oneOff];
    final user = ref.watch(currentUserProvider).value;
    final now = ref.watch(clockProvider)();
    final showForm = _addingNew || patients.isEmpty;
    final service = draft.preferredLevel != null;
    final selectedLevel = draft.level ?? draft.preferredLevel ?? 1;
    final patient = patients.where((p) => p.id == draft.patientId).firstOrNull;
    final l1Allowed = patient == null || level1Allowed(patient.mobility, patient.age);
    final level = service && !l1Allowed ? 2 : selectedLevel;

    final slots = draft.date == null ? appointmentSlots : availableSlots(draft.date!, now, level: level);

    final pickups = [
      for (final p in user?.savedPlaces ?? const [])
        PlaceRef(label: '${p.label} · ${p.address}', lat: p.lat, lng: p.lng),
      for (final p in pickupPoints) PlaceRef(label: p.name, lat: p.lat, lng: p.lng),
    ];

    void next() {
      if (!service) {
        context.push('/book/help');
        return;
      }
      _set((d) => d.copyWith(level: level));
      context.push(level == 2 ? '/book/escort' : '/book/groups');
    }

    return DesignScaffold(
      gap: 20,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        PageHeader(title: 'Book a visit', subtitle: service ? 'Step 1 of 2 · Visit details' : 'Step 1 of 3 · Visit details', help: true),
        StepBars(count: service ? 2 : 3, filled: 1),
        if (service)
          _Group(title: 'Type of help', children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _ServiceCard(
                  key: const ValueKey('service-1'),
                  tag: 'LEVEL 1 · GROUP',
                  name: 'Shared ride + guidance',
                  desc: 'Helper at drop-off and pickup, ride shared with neighbours',
                  price: 'Up to RM 40',
                  accent: CwColors.primary,
                  tagColor: CwColors.primaryDark,
                  onColor: CwColors.lilac,
                  on: level == 1,
                  onTap: l1Allowed ? () => _set((d) => d.copyWith(level: 1)) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ServiceCard(
                  key: const ValueKey('service-2'),
                  tag: 'LEVEL 2 · PERSONAL',
                  name: 'One-to-one escort',
                  desc: "Escort stays for the whole visit, inside the doctor's room",
                  price: 'RM 30 per hour',
                  accent: CwColors.teal,
                  tagColor: CwColors.tealDark,
                  onColor: CwColors.tealSoft,
                  on: level == 2,
                  onTap: () => _set((d) => d.copyWith(level: 2)),
                ),
              ),
            ]),
            if (!l1Allowed)
              Text(
                patient.age < 18 ? 'Children under 18 always get Level 2.' : 'Lifting and transfer help needs Level 2.',
                style: const TextStyle(fontSize: 12, color: CwColors.muted),
              ),
          ]),
        _Group(
          title: 'Who is going?',
          trailing: patients.isEmpty ? null : 'From your family list',
          children: [
            if (patients.isNotEmpty)
              LayoutBuilder(builder: (context, c) {
                final w = (c.maxWidth - 24) / 4;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var i = 0; i < patients.length; i++)
                    SizedBox(
                      width: w,
                      child: _PatientChip(
                        initials: patients[i].initials,
                        tone: personTone(i),
                        title: patients[i].name.split(' ').first,
                        sub: '${patients[i].relationship}, ${patients[i].age}',
                        selected: draft.patientId == patients[i].id && !_addingNew,
                        onTap: () {
                          setState(() => _addingNew = false);
                          _set((d) => d.copyWith(patientId: patients[i].id));
                        },
                      ),
                    ),
                  SizedBox(
                    width: w,
                    child: _PatientChip(
                      initials: '+',
                      tone: const (CwColors.lilac, CwColors.primary),
                      title: 'Someone new',
                      sub: 'Add details',
                      selected: _addingNew,
                      onTap: () => setState(() => _addingNew = true),
                    ),
                  ),
                ]);
              }),
            if (showForm)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Patient details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  PatientForm(
                    saveTick: true,
                    saveLabel: 'Use these details',
                    onSave: (p) async {
                      final id = await savePatientForFamily(ref, p);
                      _set((d) => d.copyWith(patientId: id));
                      if (mounted) setState(() => _addingNew = false);
                    },
                  ),
                ]),
              ),
          ],
        ),
        _Group(title: 'Where', children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: 24,
                  child: Column(children: [
                    const SizedBox(height: 30),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(color: CwColors.white, shape: BoxShape.circle, border: Border.all(color: CwColors.primary, width: 3)),
                    ),
                    const Expanded(child: _DashedLine()),
                    SvgPicture.string(
                      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#6C4EE3"><path d="M12 2c-4 0-7 3-7 7 0 5.3 7 13 7 13s7-7.7 7-13c0-4-3-7-7-7zm0 9.5a2.5 2.5 0 1 1 0-5 2.5 2.5 0 0 1 0 5z"/></svg>',
                      width: 18,
                      height: 18,
                    ),
                    const SizedBox(height: 80),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Select<String>(
                      label: 'Pick up from',
                      hint: 'Choose a pickup place',
                      value: pickups.any((p) => p.label == draft.pickup?.label) ? draft.pickup!.label : null,
                      items: [for (final p in pickups) (p.label, p.label)],
                      onChanged: (v) => _set((d) => d.copyWith(pickup: pickups.firstWhere((p) => p.label == v))),
                    ),
                    const SizedBox(height: 12),
                    _Select<String>(
                      label: 'Going to',
                      hint: 'Choose a hospital or clinic',
                      value: draft.hospitalId,
                      items: [for (final h in hospitals) (h.id, h.name)],
                      onChanged: (v) => _set((d) => d.copyWith(hospitalId: v)),
                    ),
                    const SizedBox(height: 12),
                    _Select<String>(
                      label: 'Clinic or department',
                      hint: 'Choose a clinic',
                      value: draft.clinic,
                      items: [for (final c in clinicDepartments) (c, c)],
                      onChanged: (v) => _set((d) => d.copyWith(clinic: v)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
        _Group(title: 'Appointment date', children: [
          _FieldButton(
            icon: CwIcons.calendar,
            label: draft.date == null ? 'Choose a date' : DateFormat('EEE, d MMM yyyy').format(draft.date!),
            open: _calOpen,
            onTap: () => setState(() {
              _calOpen = !_calOpen;
              _timeOpen = false;
            }),
          ),
          if (_calOpen)
            _Calendar(
              month: _month,
              now: now,
              selected: draft.date,
              level: level,
              onMonth: (m) => setState(() => _month = m),
              onPick: (d) {
                // A time chosen for another day may already have passed today.
                final stale = draft.minutes != null && !availableSlots(d, now, level: level).contains(draft.minutes);
                _set((x) => x.copyWith(date: d, clearMinutes: stale));
              },
            ),
        ]),
        _Group(title: 'Appointment time', children: [
          _FieldButton(
            icon: CwIcons.clock,
            label: draft.minutes == null ? 'Choose a time' : slotLabel(draft.minutes!),
            open: _timeOpen,
            onTap: () => setState(() {
              _timeOpen = !_timeOpen;
              _calOpen = false;
            }),
          ),
          if (_timeOpen)
            Container(
              height: 220,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
              child: ListView.separated(
                itemCount: slots.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final m = slots[i];
                  final on = draft.minutes == m;
                  return Material(
                    color: on ? CwColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: ValueKey('slot-$m'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _set((d) => d.copyWith(minutes: m));
                        setState(() => _timeOpen = false);
                      },
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: Text(slotLabel(m),
                              style: TextStyle(fontSize: 15, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? CwColors.white : CwColors.ink)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(14)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CwIcon('<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>', size: 18, strokeWidth: 2.2, color: CwColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text('Same-day visits can be booked while the pickup time is still ahead.',
                  style: TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF3A2591))),
            ),
          ]),
        ),
        BigButton(
          label: service ? (level == 2 ? 'Next: review escort' : 'Next: review visit') : 'Next: choose help',
          trailingIcon: CwIcons.arrowRight,
          height: 58,
          onPressed: draft.detailsComplete ? next : null,
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children, this.trailing});
  final String title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
          if (trailing != null) Text(trailing!, style: const TextStyle(fontSize: 11, color: CwColors.muted)),
        ]),
        for (final c in children) ...[const SizedBox(height: 10), c],
      ]);
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    super.key,
    required this.tag,
    required this.name,
    required this.desc,
    required this.price,
    required this.accent,
    required this.tagColor,
    required this.onColor,
    required this.on,
    required this.onTap,
  });
  final String tag;
  final String name;
  final String desc;
  final String price;
  final Color accent;
  final Color tagColor;
  final Color onColor;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.55 : 1,
        child: SelectCard(
          on: on,
          accent: accent,
          onColor: onColor,
          onTap: onTap,
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 122),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: tagColor)),
              const SizedBox(height: 6),
              Text(name, style: const TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(desc, style: const TextStyle(fontSize: 11, height: 1.4, color: CwColors.muted)),
              const SizedBox(height: 6),
              Text(price, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tagColor)),
            ]),
          ),
        ),
      );
}

class _PatientChip extends StatelessWidget {
  const _PatientChip({required this.initials, required this.tone, required this.title, required this.sub, required this.selected, required this.onTap});
  final String initials;
  final (Color, Color) tone;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SelectCard(
        on: selected,
        onTap: onTap,
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatarText(initials, size: 34, tone: tone, fontSize: initials == '+' ? 20 : 12),
            const SizedBox(height: 3),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: CwColors.muted)),
          ]),
        ),
      );
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashPainter(),
        child: const SizedBox(width: 2, height: double.infinity),
      );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFC9C4D9);
    for (double y = 0; y + 4 <= size.height; y += 8) {
      canvas.drawRect(Rect.fromLTWH(0, y, 2, 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Labelled dropdown styled like the design's selects (48 px, 2 px border).
class _Select<T> extends StatelessWidget {
  const _Select({required this.label, required this.hint, required this.value, required this.items, required this.onChanged});
  final String label;
  final String hint;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CwColors.muted)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.only(left: 10, right: 6),
          decoration: BoxDecoration(
            color: CwColors.white,
            border: Border.all(color: CwColors.line, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              hint: Text(hint, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CwColors.muted)),
              icon: const CwIcon('<path d="m6 9 6 6 6-6"/>', size: 18, strokeWidth: 2.2, color: CwColors.muted),
              style: const TextStyle(fontFamily: cwFont, fontSize: 14, fontWeight: FontWeight.w700, color: CwColors.ink),
              items: [
                for (final (v, l) in items) DropdownMenuItem<T>(value: v, child: Text(l, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ]);
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({required this.icon, required this.label, required this.open, required this.onTap});
  final String icon;
  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        expanded: open,
        child: Material(
          color: CwColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: open ? CwColors.primary : CwColors.white, width: 2)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  CwIcon(icon, size: 20, strokeWidth: 2.2, color: CwColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                  RotatedBox(
                    quarterTurns: open ? 2 : 0,
                    child: const CwIcon('<path d="m6 9 6 6 6-6"/>', size: 18, strokeWidth: 2.2, color: CwColors.muted),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.month, required this.now, required this.selected, required this.level, required this.onMonth, required this.onPick});
  final int level;
  final DateTime month;
  final DateTime now;
  final DateTime? selected;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onPick;

  Widget _nav(String label, String icon, VoidCallback? onTap) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: onTap == null ? CwColors.surface : CwColors.lilac,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(child: CwIcon(icon, size: 18, strokeWidth: 2.4, color: onTap == null ? const Color(0xFFC9C4D9) : CwColors.primaryDark)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final offset = (first.weekday + 6) % 7; // Monday first
    final days = DateTime(month.year, month.month + 1, 0).day;
    final localNow = now.toLocal();
    final canGoBack = DateTime(localNow.year, localNow.month).isBefore(first);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _nav('Previous month', CwIcons.back, canGoBack ? () => onMonth(DateTime(month.year, month.month - 1)) : null),
          Expanded(child: Text(DateFormat('MMMM yyyy').format(first), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
          _nav('Next month', CwIcons.chevronRight, () => onMonth(DateTime(month.year, month.month + 1))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          for (final d in const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
            Expanded(child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CwColors.muted))),
        ]),
        const SizedBox(height: 10),
        for (var week = 0; week * 7 < offset + days; week++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(child: _cell(week * 7 + i - offset + 1, days, localNow)),
              ],
            ]),
          ),
        const SizedBox(height: 8),
        const Text('Greyed-out dates are in the past.', style: TextStyle(fontSize: 11, color: CwColors.muted)),
      ]),
    );
  }

  Widget _cell(int day, int days, DateTime localNow) {
    if (day < 1 || day > days) return const SizedBox(height: 40);
    final date = DateTime(month.year, month.month, day);
    final enabled = dayBookable(date, now, level: level);
    final isSel = selected != null && selected!.year == date.year && selected!.month == date.month && selected!.day == day;
    final isToday = DateUtils.isSameDay(date, localNow);
    return Material(
      color: isSel ? CwColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('day-${date.year}-${date.month}-${date.day}'),
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => onPick(date) : null,
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSel ? FontWeight.w800 : (enabled ? FontWeight.w700 : FontWeight.w600),
                decoration: isToday && !enabled ? TextDecoration.underline : null,
                color: isSel ? CwColors.white : (enabled ? CwColors.ink : const Color(0xFFC9C4D9)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
