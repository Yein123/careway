import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/design_kit.dart';
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
    final rec = needs2 || draft.preferredLevel == 2 ? 2 : 1;
    final level = needs2 ? 2 : (draft.level ?? rec);
    final blockedReason = patient == null
        ? null
        : patient.age < 18
            ? 'Children under 18 always get Level 2.'
            : patient.mobility == Mobility.transfer
                ? 'Lifting and transfer help needs Level 2.'
                : null;

    Widget question(int n, String title, String body, bool yes, ValueChanged<bool> set) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: CwColors.lilac, shape: BoxShape.circle),
                child: Text('$n', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(body, style: const TextStyle(fontSize: 13, height: 1.4, color: kInk2)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Segment(label: 'No, can manage', on: !yes, onTap: () => set(false))),
              const SizedBox(width: 8),
              Expanded(child: _Segment(label: 'Yes, needs someone', on: yes, onTap: () => set(true))),
            ]),
          ]),
        );

    const badgeMuted = (Color(0xFFEFECF6), CwColors.muted);
    final l1Badge = needs2 ? 'Not enough help' : (rec == 1 ? 'Recommended' : (level == 1 ? 'Selected' : 'Optional'));
    final l1Tone = needs2 ? badgeMuted : (rec == 1 || level == 1 ? (CwColors.primary, CwColors.white) : badgeMuted);
    final l2Badge = rec == 2 ? 'Recommended' : (level == 2 ? 'Selected' : 'Optional');
    final l2Tone = rec == 2 || level == 2 ? (CwColors.teal, CwColors.white) : badgeMuted;
    final suggestFg = needs2 ? CwColors.tealDark : const Color(0xFF3A2591);

    return DesignScaffold(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(
          title: 'Choose help',
          subtitle: 'Step 2 of 3 · $first${draft.apptAt == null ? '' : ' · ${dayTimeLabel(draft.apptAt!)}'}',
          help: true,
        ),
        const StepBars(count: 3, filled: 2),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Does $first need someone with them?', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('Two questions so we suggest the right help.', style: TextStyle(fontSize: 12, color: CwColors.muted)),
          const SizedBox(height: 10),
          question(1, "In the doctor's room",
              'Does $first need someone to go in with them, listen to the doctor and explain the instructions after?',
              draft.needsConsult, (v) => notifier.update((d) => d.copyWith(needsConsult: v))),
          const SizedBox(height: 10),
          question(2, 'Moving around',
              'Does $first need someone to lift them, or help them move between wheelchair, car, bed or toilet?',
              draft.needsTransfer, (v) => notifier.update((d) => d.copyWith(needsTransfer: v))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: needs2 ? CwColors.tealSoft : CwColors.lilac, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              CwIcon(CwIcons.check, size: 18, strokeWidth: 2.4, color: suggestFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  blockedReason ??
                      (needs2
                          ? 'We suggest Level 2: a one-to-one escort stays with $first the whole visit.'
                          : 'We suggest Level 1: shared ride with a helper to guide $first in and out.'),
                  style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w700, color: suggestFg),
                ),
              ),
            ]),
          ),
        ]),
        _LevelCard(
          inkKey: const ValueKey('level-1'),
          tag: 'LEVEL 1',
          tagColor: CwColors.primaryDark,
          badge: l1Badge,
          badgeTone: l1Tone,
          title: 'Shared ride + guidance',
          lines: const [
            'Up to 3 neighbours share one helper. Help in and out of the van, wheelchair pushing, walk to registration and back from the pharmacy.',
            'Not included: lifting, toilet help. Joining the consultation is an add-on.',
          ],
          price: 'From RM 22 · Group Saver or Group Flex',
          accent: CwColors.primary,
          onColor: CwColors.lilac,
          selected: level == 1,
          onTap: needs2 ? null : () => notifier.update((d) => d.copyWith(level: 1)),
        ),
        _LevelCard(
          inkKey: const ValueKey('level-2'),
          tag: 'LEVEL 2',
          tagColor: CwColors.tealDark,
          badge: l2Badge,
          badgeTone: l2Tone,
          title: 'One-to-one escort',
          lines: const ["A trained escort from a partner agency for the whole visit, including the consultation and the doctor's instructions."],
          price: 'RM 30 per hour',
          accent: CwColors.teal,
          onColor: CwColors.tealSoft,
          selected: level == 2,
          onTap: () => notifier.update((d) => d.copyWith(level: 2)),
        ),
        const Row(children: [
          Expanded(child: Text('Children under 18 always get Level 2.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CwColors.muted))),
          Text('Sample prices', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CwColors.muted)),
        ]),
        BigButton(
          label: level == 2 ? 'Next: review' : 'Find a group',
          trailingIcon: CwIcons.arrowRight,
          onPressed: () {
            notifier.update((d) => d.copyWith(level: level));
            context.push(level == 2 ? '/book/escort' : '/book/groups');
          },
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        child: Material(
          color: on ? CwColors.primary : CwColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: on ? CwColors.primary : CwColors.line, width: 2)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w800 : FontWeight.w700, color: on ? CwColors.white : CwColors.ink)),
            ),
          ),
        ),
      );
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.inkKey,
    required this.tag,
    required this.tagColor,
    required this.badge,
    required this.badgeTone,
    required this.title,
    required this.lines,
    required this.price,
    required this.accent,
    required this.onColor,
    required this.selected,
    required this.onTap,
  });

  final Key inkKey;
  final String tag;
  final Color tagColor;
  final String badge;
  final (Color, Color) badgeTone;
  final String title;
  final List<String> lines;
  final String price;
  final Color accent;
  final Color onColor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? onColor : CwColors.white,
          shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: selected ? accent : CwColors.line, width: 2)),
          child: InkWell(
            key: inkKey,
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: tagColor))),
                  Tag(badge, background: badgeTone.$1, color: badgeTone.$2),
                ]),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                for (final l in lines) ...[
                  const SizedBox(height: 6),
                  Text(l, style: const TextStyle(fontSize: 12, height: 1.5, color: CwColors.muted)),
                ],
                const SizedBox(height: 6),
                Text(price, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tagColor)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
