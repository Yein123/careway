import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/step_label.dart';
import '../../data/providers.dart';
import '../home/home_screen.dart' show placeName;
import 'booking_common.dart';
import 'booking_draft.dart';
import 'submit.dart';

String _reasonLine(String? reason, String first) => switch (reason) {
      'seat-taken' => 'The group filled up before your request was confirmed.',
      'group-full' => 'This group is already full.',
      'helper-declined' => "The group's helper couldn't take $first this time.",
      'no-caregiver' => 'No qualified caregiver was free at that time.',
      _ => "We couldn't confirm this request.",
    };

/// 8 · Group not found (NotFound.dc.html). Used both for a rejected join
/// (no booking yet, [reason] from the query) and a not_matched booking.
class NotFoundScreen extends ConsumerStatefulWidget {
  const NotFoundScreen({super.key, this.bookingId, this.reason});
  final String? bookingId;
  final String? reason;

  @override
  ConsumerState<NotFoundScreen> createState() => _NotFoundScreenState();
}

class _NotFoundScreenState extends ConsumerState<NotFoundScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.bookingId == null ? null : ref.watch(bookingProvider(widget.bookingId!)).value;
    final draft = ref.watch(bookingDraftProvider);
    final patient = draftPatient(ref);
    final first = booking?.patient.name.split(' ').first ?? patient?.name.split(' ').first ?? 'your family member';
    final reason = widget.reason ?? booking?.notMatchedReason;
    final level = booking?.level ?? draft.level ?? 1;
    final appt = booking?.apptAt ?? draft.apptAt;
    final canWaitlist = (reason == 'seat-taken' || reason == 'group-full') && draft.groupId != null;

    void prepareDraft() {
      if (booking != null) {
        ref.read(bookingDraftProvider.notifier).update((d) => draftFromBooking(booking, d));
      }
    }

    return CwPage(
      title: 'Not successful',
      showBack: false,
      children: [
        Text(level == 1 ? 'No group for $first this time' : 'No escort for $first this time', style: CwText.h1),
        const SizedBox(height: 6),
        Text(_reasonLine(reason, first), style: CwText.muted),
        const SizedBox(height: 4),
        const Text('Nothing has been charged.', style: CwText.bodyBold),
        if (appt != null) ...[
          const Gap(10),
          Text('${placeName(booking?.hospitalId ?? draft.hospitalId ?? '')} · ${dayTimeLabel(appt)}', style: CwText.small),
        ],
        const Gap(20),
        const SectionTitle('What would you like to do?'),
        if (level == 1) ...[
          _Option(
            title: 'Form a new group',
            body: 'Neighbours going the same way can join $first. If no one does, they still ride, capped at RM 40.',
            onTap: () {
              prepareDraft();
              context.go('/book/groups?new=1');
            },
          ),
          const Gap(10),
        ],
        _Option(
          title: level == 1 ? 'Switch to a one-to-one escort' : 'Try again',
          body: level == 1
              ? 'A trained escort just for $first, the whole visit · RM 30 per hour'
              : 'We look again for an escort who is free and qualified.',
          badge: level == 1 ? 'SUGGESTED' : null,
          accent: CwColors.teal,
          onTap: () {
            prepareDraft();
            ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(level: 2));
            context.go('/book/escort');
          },
        ),
        if (canWaitlist) ...[
          const Gap(10),
          _Option(
            title: 'Tell me if a seat opens up',
            body: "We'll let you know if someone cancels. Nothing is charged until you confirm.",
            busy: _busy,
            onTap: () async {
              ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(waitlist: true));
              setState(() => _busy = true);
              await submitDraft(context, ref);
              if (mounted) setState(() => _busy = false);
            },
          ),
        ],
        const Gap(16),
        CwButton(label: 'Decide later', kind: CwButtonKind.secondary, onPressed: () => context.go('/home')),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.title, required this.body, required this.onTap, this.badge, this.accent = CwColors.primary, this.busy = false});
  final String title;
  final String body;
  final VoidCallback onTap;
  final String? badge;
  final Color accent;
  final bool busy;

  @override
  Widget build(BuildContext context) => CwCard(
        onTap: busy ? null : onTap,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (badge != null) ...[CwBadge(badge!, color: accent, background: accent.withValues(alpha: 0.12)), const SizedBox(height: 6)],
              Text(title, style: CwText.h3.copyWith(color: accent)),
              const SizedBox(height: 2),
              Text(body, style: CwText.small),
            ]),
          ),
          busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.chevron_right, color: accent),
        ]),
      );
}

