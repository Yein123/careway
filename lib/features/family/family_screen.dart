import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/design_kit.dart';
import '../../data/models/booking.dart';
import '../../data/models/family.dart';
import '../../data/models/firestore_utils.dart' show initialsOf;
import '../../data/providers.dart';
import '../../domain/booking_status.dart';

/// 18 · Family group (Family.dc.html)
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  bool _invite = false;

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(familyProvider);
    final patients = ref.watch(patientsProvider);
    final me = ref.watch(authStateProvider).value;
    final bookings = ref.watch(familyBookingsProvider).value ?? const <Booking>[];
    final now = ref.watch(clockProvider)();
    final groupName = family.value?.name ?? 'Your family';

    (String, bool) status(Patient p) {
      final live = bookings.any((b) => b.patientId == p.id && b.status == BookingStatus.inProgress);
      if (live) return ('At hospital now', true);
      final upcoming = bookings
          .where((b) => b.patientId == p.id && !b.status.isTerminal && b.status != BookingStatus.notMatched && b.apptAt.isAfter(now))
          .toList()
        ..sort((a, b) => a.apptAt.compareTo(b.apptAt));
      return (upcoming.isEmpty ? 'No visit booked' : 'Next visit ${dayLabel(upcoming.first.apptAt)}', false);
    }

    Widget row({required int index, required Widget child, VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: index > 0 ? const Border(top: BorderSide(color: kLine)) : null),
            child: child,
          ),
        );

    final members = (family.value?.memberNames ?? const <String, String>{}).entries.toList()
      ..sort((a, b) => a.key == family.value?.adminUid ? -1 : (b.key == family.value?.adminUid ? 1 : 0));

    return Scaffold(
      backgroundColor: CwColors.surface,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Family', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: CwColors.white,
                      border: Border.all(color: CwColors.line, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(groupName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF3A2591))),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Invite to family group',
                excludeSemantics: true,
                child: Material(
                  color: CwColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _invite = !_invite),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: CwIcon('<circle cx="9" cy="8" r="3"/><path d="M3 20a6 6 0 0 1 12 0"/><path d="M18 8v6M15 11h6"/>',
                            size: 22, strokeWidth: 2.2, color: CwColors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
            if (_invite) ...[
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Invite someone to $groupName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(14)),
                    child: const Text(
                      'Invite codes are coming soon. For now, family members you add here can view visits and update profiles.',
                      style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF3A2591)),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 22),
            const SectionLabel('People we care for', size: 16),
            const SizedBox(height: 10),
            AsyncView<List<Patient>>(
              value: patients,
              onRetry: () => ref.invalidate(allPatientsProvider),
              data: (list) => Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
                child: Material(
                  color: CwColors.white,
                  child: Column(children: [
                    for (var i = 0; i < list.length; i++)
                      row(
                        index: i,
                        onTap: () => context.push('/family/patient/${list[i].id}'),
                        child: Row(children: [
                          CircleAvatarText(list[i].initials, size: 44, tone: personTone(i), fontSize: 14),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(list[i].name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Builder(builder: (_) {
                                final (text, live) = status(list[i]);
                                return Text(text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: live ? FontWeight.w800 : FontWeight.w600,
                                      color: live ? const Color(0xFF1D6B45) : CwColors.muted,
                                    ));
                              }),
                            ]),
                          ),
                          const CwIcon(CwIcons.chevronRight, size: 20, strokeWidth: 2.4, color: Color(0xFF9A96AE)),
                        ]),
                      ),
                    row(
                      index: list.length,
                      onTap: () => context.push('/family/patient/new'),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(color: CwColors.lilac, shape: BoxShape.circle),
                          child: const Center(child: CwIcon(CwIcons.plus, size: 20, strokeWidth: 2.6, color: CwColors.primary)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Add someone you care for', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SectionLabel('Family members', size: 16),
            const SizedBox(height: 10),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                for (var i = 0; i < members.length; i++)
                  row(
                    index: i,
                    child: Row(children: [
                      CircleAvatarText(
                        initialsOf(members[i].value.replaceAll(RegExp(r'\(.*\)'), '').trim()),
                        size: 44,
                        tone: [(const Color(0xFFE4DCFB), CwColors.primaryDark), (CwColors.tealSoft, CwColors.teal), (CwColors.amberSoft, CwColors.amber)][i % 3],
                        fontSize: 14,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${members[i].value}${members[i].key == me ? ' (you)' : ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          const Text('Family member', style: TextStyle(fontSize: 13, color: CwColors.muted)),
                        ]),
                      ),
                      Builder(builder: (_) {
                        final admin = members[i].key == family.value?.adminUid;
                        return Container(
                          constraints: const BoxConstraints(minWidth: 76),
                          height: 36,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: admin ? CwColors.primary : const Color(0xFFEFECF6), borderRadius: BorderRadius.circular(18)),
                          child: Text(admin ? 'Admin' : 'Member',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: admin ? CwColors.white : kInk2)),
                        );
                      }),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Everyone here can view visits and update profiles. Admins also manage members and payments.',
                style: TextStyle(fontSize: 12, height: 1.5, color: CwColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
