import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/step_label.dart';
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
    return CwPage(
      title: 'Review your visit',
      stepLabel: 'Step 3 of 3 · Confirm',
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        CwButton(
          label: 'Find my escort',
          color: CwColors.teal,
          loading: _busy,
          onPressed: appt == null
              ? null
              : () async {
                  setState(() => _busy = true);
                  await submitDraft(context, ref);
                  if (mounted) setState(() => _busy = false);
                },
        ),
        CwButton(label: 'Change', kind: CwButtonKind.text, onPressed: () => context.pop()),
      ]),
      children: [
        CwCard(
          color: CwColors.tealSoft,
          borderColor: CwColors.tealSoft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CwBadge('LEVEL 2', color: CwColors.tealDark, background: CwColors.white),
            const SizedBox(height: 6),
            const Text('One-to-one escort', style: CwText.h3),
            Text("An escort stays with $first for the whole visit, including the doctor's room.", style: CwText.muted),
          ]),
        ),
        const Gap(14),
        CwCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (appt != null) ...[
              Text('Pickup · ${timeLabel(appt.subtract(const Duration(hours: 1)))} · private ride', style: CwText.small),
              Text(draft.pickup?.label ?? '', style: CwText.bodyBold),
              const SizedBox(height: 10),
              Text('Appointment · ${dayTimeLabel(appt)}', style: CwText.small),
              Text('${placeName(draft.hospitalId ?? '')} · ${draft.clinic ?? ''}', style: CwText.bodyBold),
            ],
          ]),
        ),
        const Gap(14),
        const SectionTitle('Your escort will'),
        for (final t in [
          "Go into the doctor's room and note the instructions",
          'Help with transfers, toilet and wheelchair',
          'Send you a visit summary afterwards',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle, size: 18, color: CwColors.teal),
              const SizedBox(width: 8),
              Expanded(child: Text(t, style: CwText.body)),
            ]),
          ),
        const Gap(8),
        const Text('We match a trained escort with the right skills and certificates. They have 18 minutes to accept; you pay only after they do.',
            style: CwText.small),
        const Gap(16),
        const SectionTitle('Estimated price'),
        CwCard(
          child: Column(children: [
            KeyValueRow('Escort · RM 30 × est. ${defaultEscortHours.toInt()} hours', formatRm(escort)),
            KeyValueRow('Private ride, both ways', formatRm(privateRideSen)),
            const Divider(),
            KeyValueRow('Estimated total', formatRm(escortEstimateSen()), bold: true),
          ]),
        ),
        const Gap(8),
        const Text('Charged by actual time. Shorter visit, you get the difference back. We ask you before adding time. Sample prices.',
            style: CwText.small),
      ],
    );
  }
}
