import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/places.dart';
import '../../core/theme.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/step_label.dart';
import '../../data/models/booking.dart';
import '../../data/models/family.dart';
import '../../data/providers.dart';
import '../family/patient_form.dart';
import '../family/patient_profile_screen.dart';
import 'booking_draft.dart';

/// 3 · Book a visit (Book.dc.html; 23 · BookService.dc.html when opened from a service tile).
class BookScreen extends ConsumerStatefulWidget {
  const BookScreen({super.key, this.service});

  /// 'level1' | 'level2' when opened from a Home service tile.
  final String? service;

  @override
  ConsumerState<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends ConsumerState<BookScreen> {
  bool _addingNew = false;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final first = ref.read(clockProvider)().toLocal().add(const Duration(days: 1));
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
    final patients = ref.watch(patientsProvider).value ?? const <Patient>[];
    final user = ref.watch(currentUserProvider).value;
    final now = ref.watch(clockProvider)();
    final showForm = _addingNew || patients.isEmpty;

    final pickups = [
      for (final p in user?.savedPlaces ?? const [])
        PlaceRef(label: '${p.label} · ${p.address}', lat: p.lat, lng: p.lng),
      for (final p in pickupPoints) PlaceRef(label: p.name, lat: p.lat, lng: p.lng),
    ];

    return CwPage(
      title: 'Book a visit',
      stepLabel: 'Step 1 of 3 · Visit details',
      bottom: CwButton(
        label: 'Next: choose help',
        onPressed: draft.detailsComplete ? () => context.push('/book/help') : null,
      ),
      children: [
        const SectionTitle('Who is going?'),
        if (patients.isNotEmpty) ...[
          const Text('From your family list', style: CwText.small),
          const Gap(8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in patients)
              _PatientChip(
                initials: p.initials,
                title: p.name.split(' ').first,
                sub: '${p.relationship} · ${p.age}',
                selected: draft.patientId == p.id && !_addingNew,
                onTap: () {
                  setState(() => _addingNew = false);
                  _set((d) => d.copyWith(patientId: p.id));
                },
              ),
            _PatientChip(
              initials: '+',
              title: 'Someone new',
              sub: 'Add details',
              selected: _addingNew,
              onTap: () => setState(() => _addingNew = true),
            ),
          ]),
        ],
        if (showForm) ...[
          const Gap(12),
          CwCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Patient details', style: CwText.h3),
              const SizedBox(height: 4),
              const Text('Pick them in one tap next time. You can add medical details later.', style: CwText.small),
              const Gap(12),
              PatientForm(
                saveLabel: 'Save to my family list',
                onSave: (p) async {
                  final id = await savePatientForFamily(ref, p);
                  _set((d) => d.copyWith(patientId: id));
                  if (mounted) setState(() => _addingNew = false);
                },
              ),
            ]),
          ),
        ],
        const Gap(22),
        const SectionTitle('Where'),
        const Text('Pick up from', style: CwText.label),
        const Gap(8),
        for (final p in pickups)
          _OptionRow(
            label: p.label,
            selected: draft.pickup?.label == p.label,
            onTap: () => _set((d) => d.copyWith(pickup: p)),
          ),
        const Gap(14),
        const Text('Going to', style: CwText.label),
        const Gap(8),
        for (final h in hospitals)
          _OptionRow(
            label: h.name,
            selected: draft.hospitalId == h.id,
            onTap: () => _set((d) => d.copyWith(hospitalId: h.id)),
          ),
        const Gap(14),
        const Text('Clinic or department', style: CwText.label),
        const Gap(8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in clinicDepartments)
            CwChip(label: c, selected: draft.clinic == c, onTap: () => _set((d) => d.copyWith(clinic: c))),
        ]),
        const Gap(22),
        const SectionTitle('Appointment date'),
        _Calendar(
          month: _month,
          now: now,
          selected: draft.date,
          onMonth: (m) => setState(() => _month = m),
          onPick: (d) => _set((x) => x.copyWith(date: d)),
        ),
        const Gap(6),
        const Text('Greyed-out dates are less than 24 hours away.', style: CwText.small),
        const Gap(22),
        const SectionTitle('Appointment time'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in appointmentSlots)
            CwChip(label: slotLabel(m), selected: draft.minutes == m, onTap: () => _set((d) => d.copyWith(minutes: m))),
        ]),
        const Gap(10),
        const Text('Book at least 24 hours ahead so we can match neighbours going to the same clinic.', style: CwText.small),
      ],
    );
  }
}

class _PatientChip extends StatelessWidget {
  const _PatientChip({required this.initials, required this.title, required this.sub, required this.selected, required this.onTap});
  final String initials;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 160,
        child: CwCard(
          selected: selected,
          onTap: onTap,
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Avatar(initials, size: 36, background: CwColors.pinkSoft, color: CwColors.pink),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: CwText.bodyBold),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: CwText.small),
              ]),
            ),
          ]),
        ),
      );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CwCard(
          selected: selected,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? CwColors.primary : CwColors.muted, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: CwText.bodyBold)),
          ]),
        ),
      );
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.month, required this.now, required this.selected, required this.onMonth, required this.onPick});
  final DateTime month;
  final DateTime now;
  final DateTime? selected;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final offset = (first.weekday + 6) % 7; // Monday first
    final days = DateTime(month.year, month.month + 1, 0).day;
    final localNow = now.toLocal();
    final canGoBack = DateTime(localNow.year, localNow.month).isBefore(first);
    return CwCard(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: canGoBack ? () => onMonth(DateTime(month.year, month.month - 1)) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(child: Text(DateFormat('MMMM yyyy').format(first), textAlign: TextAlign.center, style: CwText.h3)),
          IconButton(
            tooltip: 'Next month',
            onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        Row(children: [
          for (final d in const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
            Expanded(child: Text(d, textAlign: TextAlign.center, style: CwText.small)),
        ]),
        const SizedBox(height: 4),
        for (var week = 0; week * 7 < offset + days; week++)
          Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(child: _cell(week * 7 + i - offset + 1, days)),
          ]),
      ]),
    );
  }

  Widget _cell(int day, int days) {
    if (day < 1 || day > days) return const SizedBox(height: 44);
    final date = DateTime(month.year, month.month, day);
    final enabled = dayBookable(date, now);
    final isSel = selected != null && selected!.year == date.year && selected!.month == date.month && selected!.day == day;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: isSel ? CwColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('day-${date.year}-${date.month}-${date.day}'),
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? () => onPick(date) : null,
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isSel ? CwColors.white : (enabled ? CwColors.ink : CwColors.muted.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
