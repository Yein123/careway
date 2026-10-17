import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../domain/needs.dart';
import 'booking_draft.dart';
import 'submit.dart';

/// 4 · Choose help (Assist.dc.html)
class ChooseHelpScreen extends ConsumerWidget {
  const ChooseHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);
    final patient = draftPatient(ref);
    final notifier = ref.read(bookingDraftProvider.notifier);
    final first = patient?.name.split(' ').first ?? 'them';
    final allowed1 = patient == null || level1Allowed(patient.mobility, patient.age);
    final needs2 = draft.needsConsult || draft.needsTransfer || !allowed1;
    final level = needs2 ? 2 : (draft.level ?? draft.preferredLevel ?? 1);
    final blockedReason = patient == null
        ? null
        : patient.age < 18
            ? 'Children under 18 always get Level 2.'
            : patient.mobility == Mobility.transfer
                ? 'Lifting and transfer help needs Level 2.'
                : null;

    Widget question(int n, String title, String body, bool yes, ValueChanged<bool> set) => CwCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 12, backgroundColor: CwColors.lilac,
                  child: Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: CwColors.primaryDark))),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: CwText.h3)),
            ]),
            const SizedBox(height: 6),
            Text(body, style: CwText.muted),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              CwChip(label: 'No, $first can manage', selected: !yes, onTap: () => set(false)),
              CwChip(label: 'Yes, needs someone', selected: yes, onTap: () => set(true)),
            ]),
          ]),
        );

    return CwPage(
      title: 'Choose help',
      stepLabel: 'Step 2 of 3 · $first${draft.apptAt == null ? '' : ' · ${dayTimeLabel(draft.apptAt!)}'}',
      bottom: CwButton(
        label: level == 2 ? 'Next: review' : 'Find a group',
        onPressed: () {
          notifier.update((d) => d.copyWith(level: level));
          context.push(level == 2 ? '/book/escort' : '/book/groups');
        },
      ),
      children: [
        Text('Does $first need someone with them?', style: CwText.h2),
        const SizedBox(height: 4),
        const Text('Two questions so we suggest the right help.', style: CwText.muted),
        const Gap(14),
        question(1, "In the doctor's room",
            'Does $first need someone to go in with them, listen to the doctor and explain the instructions after?',
            draft.needsConsult, (v) => notifier.update((d) => d.copyWith(needsConsult: v))),
        const Gap(10),
        question(2, 'Moving around',
            'Does $first need someone to lift them, or help them move between wheelchair, car, bed or toilet?',
            draft.needsTransfer, (v) => notifier.update((d) => d.copyWith(needsTransfer: v))),
        const Gap(14),
        CwCard(
          color: needs2 ? CwColors.tealSoft : CwColors.lilac,
          borderColor: needs2 ? CwColors.tealSoft : CwColors.lilac,
          child: Text(
            blockedReason ??
                (needs2
                    ? 'We suggest Level 2: a one-to-one escort stays with $first the whole visit.'
                    : 'We suggest Level 1: shared ride with a helper to guide $first in and out.'),
            style: CwText.bodyBold,
          ),
        ),
        const Gap(14),
        _LevelCard(
          inkKey: const ValueKey('level-1'),
          tag: 'LEVEL 1',
          badge: needs2 ? 'Not suitable' : 'Suggested',
          title: 'Shared ride + guidance',
          body: 'Up to 3 neighbours share one helper. Help in and out of the van, wheelchair pushing, walk to registration and back from the pharmacy.',
          note: 'Not included: lifting, toilet help. Joining the consultation is an add-on.',
          price: 'From RM 22 · Group Saver or Group Flex',
          accent: CwColors.primary,
          selected: level == 1,
          onTap: needs2 ? null : () => notifier.update((d) => d.copyWith(level: 1)),
        ),
        const Gap(10),
        _LevelCard(
          inkKey: const ValueKey('level-2'),
          tag: 'LEVEL 2',
          badge: needs2 ? 'Suggested' : 'Optional',
          title: 'One-to-one escort',
          body: "A trained escort from a partner agency for the whole visit, including the consultation and the doctor's instructions.",
          note: 'Children under 18 always get Level 2.',
          price: 'RM 30 per hour',
          accent: CwColors.teal,
          selected: level == 2,
          onTap: () => notifier.update((d) => d.copyWith(level: 2)),
        ),
        const Gap(8),
        const Text('Sample prices', style: CwText.small),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.inkKey,
    required this.tag,
    required this.badge,
    required this.title,
    required this.body,
    required this.note,
    required this.price,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final Key inkKey;
  final String tag;
  final String badge;
  final String title;
  final String body;
  final String note;
  final String price;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: selected ? accent.withValues(alpha: 0.08) : CwColors.white,
        borderRadius: radius,
        child: InkWell(
          key: inkKey,
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: selected ? accent : CwColors.line, width: 2),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: accent)),
                const Spacer(),
                CwBadge(badge.toUpperCase(), color: accent, background: accent.withValues(alpha: 0.12)),
              ]),
              const SizedBox(height: 6),
              Text(title, style: CwText.h3),
              const SizedBox(height: 4),
              Text(body, style: CwText.muted),
              const SizedBox(height: 6),
              Text(note, style: CwText.small),
              const SizedBox(height: 8),
              Text(price, style: TextStyle(fontWeight: FontWeight.w800, color: accent)),
            ]),
          ),
        ),
      ),
    );
  }
}
