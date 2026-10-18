import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/design_kit.dart';
import '../../domain/pricing.dart';
import '../home/home_screen.dart' show placeName;
import 'booking_draft.dart';
import 'submit.dart';

/// 14 · Review escort (Escort.dc.html). The escort is matched after this step.
class EscortReviewScreen extends ConsumerStatefulWidget {
  const EscortReviewScreen({super.key});

  @override
  ConsumerState<EscortReviewScreen> createState() => _EscortReviewScreenState();
}

class _EscortReviewScreenState extends ConsumerState<EscortReviewScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final patient = draftPatient(ref);
    final first = patient?.name.split(' ').first ?? 'your family member';
    final appt = draft.apptAt;
    final escort = escortHourlySen * defaultEscortHours.toInt();
    const sub = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CwColors.muted);
    const strong = TextStyle(fontSize: 15, fontWeight: FontWeight.w800);

    return DesignScaffold(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        const PageHeader(title: 'Review your visit', subtitle: 'Step 3 of 3 · Confirm', help: true),
        Transform.translate(offset: const Offset(0, -4), child: const StepBars(count: 3, filled: 3)),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: CwColors.teal, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: CwColors.white, shape: BoxShape.circle),
              child: const Center(
                child: CwIcon('<circle cx="8" cy="7" r="2.6"/><circle cx="16" cy="7" r="2.6"/><path d="M3 20a5 5 0 0 1 10 0M11 20a5 5 0 0 1 10 0"/>',
                    size: 28, strokeWidth: 2.2, color: CwColors.teal),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('LEVEL 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xD9FFFFFF))),
                const SizedBox(height: 4),
                const Text('One-to-one escort', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: CwColors.white)),
                const SizedBox(height: 4),
                Text("An escort stays with $first for the whole visit, including the doctor's room.",
                    style: const TextStyle(fontSize: 13, height: 1.45, color: CwColors.white)),
              ]),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (appt != null)
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(children: [
                      Container(width: 12, height: 12, decoration: const BoxDecoration(color: CwColors.primary, shape: BoxShape.circle)),
                      Expanded(child: Container(width: 2, color: CwColors.lilacLine)),
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: CwColors.teal, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 22),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pickup · ${timeLabel(appt.subtract(const Duration(hours: 1)))} · private ride', style: sub),
                      const SizedBox(height: 2),
                      Text(draft.pickup?.label ?? '', style: strong),
                      const SizedBox(height: 22),
                      Text('Appointment · ${timeLabel(appt)}, ${dayLabel(appt)}', style: sub),
                      const SizedBox(height: 2),
                      Text('${placeName(draft.hospitalId ?? '')} · ${(draft.clinic ?? '').replaceAll(' specialist clinic', '')}', style: strong),
                    ]),
                  ),
                ]),
              ),
            const SizedBox(height: 14),
            Container(height: 1, color: kLine),
            const SizedBox(height: 14),
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: CwColors.tealSoft, shape: BoxShape.circle),
                child: const Center(child: CwIcon(CwIcons.person, size: 22, strokeWidth: 2.2, color: CwColors.teal)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Your escort', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Trained caregiver · matched after you confirm', style: TextStyle(fontSize: 12, color: CwColors.muted)),
                ]),
              ),
              const Tag('Partner', background: CwColors.tealSoft, color: CwColors.tealDark, padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5)),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: BoxDecoration(color: CwColors.surface, borderRadius: BorderRadius.circular(14)),
              child: const Text(
                "We match an escort with the right skills and certificates. They have 18 minutes to accept, and you pay only after they do. You'll get their name and number then.",
                style: TextStyle(fontSize: 12, height: 1.45, color: CwColors.muted),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Your escort will', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            for (final t in [
              "Go into the doctor's room and note the instructions",
              'Help with transfers, toilet and wheelchair',
              'Send you a visit summary afterwards',
            ]) ...[
              const SizedBox(height: 6),
              Row(children: [
                const CwIcon(CwIcons.check, size: 16, strokeWidth: 2.6, color: CwColors.teal),
                const SizedBox(width: 8),
                Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
              ]),
            ],
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Expanded(child: Text('Estimated price', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              Text('Sample prices', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CwColors.muted)),
            ]),
            const SizedBox(height: 10),
            for (final (k, v) in [
              ('Escort · RM 30 × est. ${defaultEscortHours.toInt()} hours', formatRm(escort)),
              ('Private ride, both ways', formatRm(privateRideSen)),
            ]) ...[
              Row(children: [
                Expanded(child: Text(k, style: const TextStyle(fontSize: 14, color: CwColors.muted))),
                Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
            ],
            Container(height: 1, color: kLine),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              const Expanded(child: Text('Estimated total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              Text(formatRm(escortEstimateSen()), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CwColors.tealDark)),
            ]),
            const SizedBox(height: 10),
            const Text('Charged by actual time. Shorter visit, you get the difference back. We ask you before adding time.',
                style: TextStyle(fontSize: 12, height: 1.45, color: CwColors.muted)),
          ]),
        ),
        Row(children: [
          SizedBox(
            width: 104,
            height: 58,
            child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: CwColors.ink,
                backgroundColor: CwColors.white,
                side: const BorderSide(color: CwColors.line, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontFamily: cwFont, fontSize: 15, fontWeight: FontWeight.w800),
              ),
              child: const Text('Change'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BigButton(
              label: 'Find my escort',
              trailingIcon: CwIcons.arrowRight,
              height: 58,
              loading: _busy,
              onPressed: appt == null
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await submitDraft(context, ref);
                      if (mounted) setState(() => _busy = false);
                    },
            ),
          ),
        ]),
      ],
    );
  }
}
