import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/step_label.dart';
import '../../data/models/booking.dart';
import '../../data/models/caregiver.dart';
import '../../data/models/delivery.dart';
import '../../data/providers.dart';
import '../home/home_screen.dart' show placeName, levelLabel;
import 'cg_providers.dart';

/// C6 · Caregiver: schedule (CgSchedule.dc.html)
class CgScheduleScreen extends ConsumerWidget {
  const CgScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final bookings = ref.watch(cgBookingsProvider);
    final deliveries = ref.watch(cgDeliveriesProvider).value ?? const <MedDelivery>[];
    final items = <(DateTime, Widget)>[
      for (final b in bookings.value ?? const <Booking>[])
        if (isActiveJob(b) || b.status.wire == 'awaiting_payment')
          (
            b.pickupAt ?? b.apptAt,
            _Row(
              time: b.pickupAt ?? b.apptAt,
              title: b.patient.name,
              sub: '${placeName(b.hospitalId)}${b.status.wire == 'in_progress' ? ' · in progress' : b.status.wire == 'awaiting_payment' ? ' · waiting for payment' : ''}',
              tag: levelLabel(b.level),
              onTap: () => context.push('/cg/job/${b.id}'),
            )
          ),
      for (final d in deliveries)
        if (d.date != null && deliveryStageKeys.contains(d.status.wire) && d.status != DeliveryStatus.delivered)
          (d.date!, _Row(time: d.date!, title: 'Medicine run · ${d.patientName}', sub: '${d.pharmacyName} · ${d.window}', tag: 'Delivery')),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final byDay = <String, List<Widget>>{};
    for (final (t, w) in items) {
      if (t.isBefore(DateTime(now.year, now.month, now.day))) continue;
      final key = sameLocalDay(t, now) ? 'TODAY · ${DateFormat('EEE d MMM').format(t.toLocal()).toUpperCase()}' : DateFormat('EEE d MMM').format(t.toLocal()).toUpperCase();
      byDay.putIfAbsent(key, () => []).add(w);
    }
    return CwPage(
      title: 'Schedule',
      showBack: false,
      children: [
        AsyncView<List<Booking>>(
          value: bookings,
          onRetry: () => ref.invalidate(cgBookingsProvider),
          data: (_) => byDay.isEmpty
              ? const EmptyState(icon: Icons.event_available, title: 'Nothing scheduled', message: 'Accepted jobs show up here.')
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final e in byDay.entries) ...[
                    StepLabel(e.key, color: CwColors.teal),
                    const Gap(8),
                    ...e.value,
                    const Gap(12),
                  ],
                ]),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.time, required this.title, required this.sub, required this.tag, this.onTap});
  final DateTime time;
  final String title;
  final String sub;
  final String tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CwCard(
          onTap: onTap,
          child: Row(children: [
            SizedBox(
              width: 56,
              child: Column(children: [
                Text(timeLabel(time).split(' ').first, style: CwText.h3),
                Text(timeLabel(time).split(' ').last, style: CwText.small),
              ]),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: CwText.bodyBold),
                Text(sub, style: CwText.small),
              ]),
            ),
            CwBadge(tag.toUpperCase(), color: CwColors.tealDark, background: CwColors.tealSoft),
          ]),
        ),
      );
}

/// C7 · Caregiver: patients (recent patients from jobs).
class CgPatientsScreen extends ConsumerWidget {
  const CgPatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(cgBookingsProvider);
    return CwPage(
      title: 'Patients',
      showBack: false,
      children: [
        AsyncView<List<Booking>>(
          value: bookings,
          onRetry: () => ref.invalidate(cgBookingsProvider),
          isEmpty: (l) => l.isEmpty,
          empty: const EmptyState(icon: Icons.people_outline, title: 'No patients yet', message: 'Patients from your jobs show up here.'),
          data: (list) {
            final latest = <String, Booking>{};
            for (final b in [...list]..sort((a, b) => b.apptAt.compareTo(a.apptAt))) {
              latest.putIfAbsent('${b.familyId}/${b.patientId}', () => b);
            }
            return Column(children: [
              for (final b in latest.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CwCard(
                    onTap: () => context.push('/cg/job/${b.id}'),
                    child: Row(children: [
                      Avatar(b.patient.initials, background: CwColors.pinkSoft, color: CwColors.pink),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${b.patient.name}, ${b.patient.age}', style: CwText.bodyBold),
                          Text('${b.patient.mobility.label} · last visit ${dayLabel(b.apptAt)}', style: CwText.small),
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: CwColors.muted),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

/// C8 · Caregiver: account (CgAccount.dc.html)
class CgAccountScreen extends ConsumerWidget {
  const CgAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(caregiverProfileProvider);
    final now = ref.watch(clockProvider)();
    return CwPage(
      title: 'Account',
      showBack: false,
      children: [
        AsyncView<CaregiverProfile?>(
          value: profile,
          onRetry: () => ref.invalidate(caregiverProfileProvider),
          isEmpty: (p) => p == null,
          empty: const EmptyState(icon: Icons.badge_outlined, title: 'Caregiver profile not set up', message: 'Ask your agency to finish your profile.'),
          data: (p) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CwCard(
              child: Row(children: [
                Avatar(p!.initials, size: 56, color: CwColors.tealDark, background: CwColors.tealSoft),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.displayName, style: CwText.h3),
                    Text(p.agency, style: CwText.small),
                    Text('${p.rating} ★ · ${p.ratingCount} visits', style: CwText.small),
                  ]),
                ),
              ]),
            ),
            const Gap(16),
            const SectionTitle('Certificates'),
            for (final c in p.certificates)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CwCard(
                  child: Row(children: [
                    Icon(c.isValidOn(now) ? Icons.verified_outlined : Icons.error_outline,
                        color: c.isValidOn(now) ? CwColors.success : CwColors.pink),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.type.label, style: CwText.bodyBold),
                        Text(
                          '${c.verified ? 'Verified' : 'Not verified yet'} · Expires ${DateFormat('d MMM yyyy').format(c.expiresAt.toLocal())}',
                          style: CwText.small,
                        ),
                      ]),
                    ),
                    if (!c.expiresAt.isAfter(now)) const CwBadge('Expired', color: CwColors.white, background: CwColors.pink),
                  ]),
                ),
              ),
            const Text('Expired or unverified certificates stop matching for jobs that need them. Your agency renews them.',
                style: CwText.small),
            const Gap(16),
            const SectionTitle('Services I offer'),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final s in p.skills) CwBadge(s.label, color: CwColors.tealDark, background: CwColors.tealSoft)]),
            const Gap(16),
            KeyValueRow('Languages', p.languages.join(', ')),
            KeyValueRow('Work zone', p.zone),
            const Gap(16),
            CwCard(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call the CareWay coordinator to report a fall, injury or problem.')),
              ),
              child: const Row(children: [
                Icon(Icons.report_gmailerrorred_outlined, color: CwColors.pink),
                SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Safety and incident report', style: CwText.bodyBold),
                    Text('Report a fall, injury or problem', style: CwText.small),
                  ]),
                ),
              ]),
            ),
            const Gap(16),
            CwButton(label: 'Sign out', kind: CwButtonKind.secondary, color: CwColors.pink, onPressed: () => ref.read(authRepoProvider).signOut()),
          ]),
        ),
      ],
    );
  }
}
