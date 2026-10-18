import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/design_kit.dart';
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

    void toEscort() {
      prepareDraft();
      ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(level: 2));
      context.go('/book/escort');
    }

    return DesignScaffold(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        PageHeader(title: 'Not successful', help: true, onBack: () => context.go('/home')),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: CwColors.amberSoft, shape: BoxShape.circle),
              child: const Center(
                child: CwIcon('<circle cx="9" cy="8" r="3"/><path d="M3 20a6 6 0 0 1 12 0"/><path d="m16 8 5 5M21 8l-5 5"/>', size: 34, color: CwColors.amber),
              ),
            ),
            const SizedBox(height: 10),
            Text(level == 1 ? 'No group for $first this time' : 'No escort for $first this time',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('${_reasonLine(reason, first)} Nothing has been charged.',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.5, color: CwColors.muted)),
            if (appt != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: CwColors.surface, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${placeName(booking?.hospitalId ?? draft.hospitalId ?? '')} · ${dayLabel(appt)} · ${timeLabel(appt)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kInk2),
                ),
              ),
            ],
          ]),
        ),
        const SectionLabel('What would you like to do?'),
        if (level == 1)
          _Option(
            icon: '<circle cx="9" cy="8" r="3"/><path d="M3 20a6 6 0 0 1 12 0"/><path d="M18 8v6M15 11h6"/>',
            tone: (CwColors.lilac, CwColors.primary),
            title: 'Form a new group',
            body: 'Neighbours going the same way can join $first. If no one does, $first still rides, capped at RM 40.',
            badge: 'Suggested',
            highlight: true,
            onTap: () {
              prepareDraft();
              context.go('/book/groups?new=1');
            },
          ),
        _Option(
          icon: '<circle cx="8" cy="7" r="2.6"/><circle cx="16" cy="7" r="2.6"/><path d="M3 20a5 5 0 0 1 10 0M11 20a5 5 0 0 1 10 0"/>',
          tone: (CwColors.tealSoft, CwColors.teal),
          overline: 'LEVEL 2',
          title: level == 1 ? 'Switch to a one-to-one escort' : 'Try again',
          body: level == 1
              ? 'A trained escort just for $first, the whole visit · RM 30 per hour'
              : 'We look again for an escort who is free and qualified.',
          highlight: level != 1,
          onTap: toEscort,
        ),
        if (canWaitlist)
          Semantics(
            button: true,
            child: InkWell(
              onTap: _busy
                  ? null
                  : () async {
                      ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(waitlist: true));
                      setState(() => _busy = true);
                      await submitDraft(context, ref);
                      if (mounted) setState(() => _busy = false);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Tell me if a seat opens up', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text("We'll move $first into the group if someone cancels.", style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Container(
                          width: 50,
                          height: 30,
                          padding: const EdgeInsets.all(3),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(color: const Color(0xFFD6D3E0), borderRadius: BorderRadius.circular(15)),
                          child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: CwColors.white, shape: BoxShape.circle)),
                        ),
                ]),
              ),
            ),
          ),
        LinkButton(label: 'Decide later', color: CwColors.muted, onPressed: () => context.go('/home')),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.onTap,
    this.overline,
    this.badge,
    this.highlight = false,
  });
  final String icon;
  final (Color, Color) tone;
  final String? overline;
  final String title;
  final String body;
  final String? badge;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: CwColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: highlight ? CwColors.primary : CwColors.line, width: 2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(12)),
                child: Center(child: CwIcon(icon, size: 22, strokeWidth: 2.2, color: tone.$2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (overline != null) ...[
                    Text(overline!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: CwColors.tealDark)),
                    const SizedBox(height: 2),
                  ],
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(body, style: const TextStyle(fontSize: 12, height: 1.4, color: CwColors.muted)),
                ]),
              ),
              if (badge != null) ...[const SizedBox(width: 12), Tag(badge!, background: CwColors.primary, color: CwColors.white)],
            ]),
          ),
        ),
      );
}
