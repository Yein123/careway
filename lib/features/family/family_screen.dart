import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/safety_button.dart';
import '../../core/widgets/step_label.dart';
import '../../data/models/booking.dart';
import '../../data/models/family.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';

/// 18 · Family group (Family.dc.html)
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProvider);
    final patients = ref.watch(patientsProvider);
    final bookings = ref.watch(familyBookingsProvider).value ?? const <Booking>[];
    final now = ref.watch(clockProvider)();

    String nextVisit(Patient p) {
      final upcoming = bookings
          .where((b) => b.patientId == p.id && !b.status.isTerminal && b.status != BookingStatus.notMatched && b.apptAt.isAfter(now))
          .toList()
        ..sort((a, b) => a.apptAt.compareTo(b.apptAt));
      return upcoming.isEmpty ? 'No visit booked' : 'Next visit ${dayLabel(upcoming.first.apptAt)}';
    }

    return CwPage(
      title: 'Family',
      showBack: false,
      action: const SafetyButton(),
      children: [
        CwCard(
          color: CwColors.lilac,
          borderColor: CwColors.lilacLine,
          child: Row(children: [
            const Icon(Icons.groups_rounded, color: CwColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(family.value?.name ?? 'Your family', style: CwText.h3)),
          ]),
        ),
        const Gap(20),
        const SectionTitle('People we care for'),
        AsyncView<List<Patient>>(
          value: patients,
          onRetry: () => ref.invalidate(patientsProvider),
          data: (list) => Column(children: [
            for (final p in list) ...[
              CwCard(
                onTap: () => context.push('/family/patient/${p.id}'),
                child: Row(children: [
                  Avatar(p.initials, background: CwColors.pinkSoft, color: CwColors.pink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${p.name}, ${p.age}', style: CwText.bodyBold),
                      Text(nextVisit(p), style: CwText.small),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: CwColors.muted),
                ]),
              ),
              const Gap(10),
            ],
            CwCard(
              onTap: () => context.push('/family/patient/new'),
              borderColor: CwColors.lilacLine,
              child: const Row(children: [
                Icon(Icons.add_circle_outline, color: CwColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Add someone you care for', style: TextStyle(fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
                ),
              ]),
            ),
          ]),
        ),
        const Gap(24),
        const SectionTitle('Family members'),
        for (final entry in (family.value?.memberNames ?? const {}).entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CwCard(
              child: Row(children: [
                Avatar(_initials(entry.value)),
                const SizedBox(width: 12),
                Expanded(child: Text(entry.value, style: CwText.bodyBold)),
                CwBadge(entry.key == family.value?.adminUid ? 'ADMIN' : 'MEMBER'),
              ]),
            ),
          ),
        const Text(
          'Everyone here can view visits and update profiles. Admins also manage members and payments.',
          style: CwText.small,
        ),
      ],
    );
  }

  static String _initials(String name) {
    final w = name.replaceAll(RegExp(r'\(.*\)'), '').trim().split(RegExp(r'\s+'));
    return w.isEmpty || w.first.isEmpty ? '?' : w.map((e) => e[0]).take(2).join().toUpperCase();
  }
}
