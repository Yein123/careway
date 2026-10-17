import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/cw_top_bar.dart';
import '../../core/widgets/step_label.dart';
import '../../data/api.dart';
import '../../data/models/booking.dart';
import '../../data/models/offer.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../home/home_screen.dart' show placeName, levelLabel;
import 'cg_providers.dart';

/// C2 · Caregiver: today (CgHome.dc.html)
class CgHomeScreen extends ConsumerStatefulWidget {
  const CgHomeScreen({super.key});

  @override
  ConsumerState<CgHomeScreen> createState() => _CgHomeScreenState();
}

class _CgHomeScreenState extends ConsumerState<CgHomeScreen> {
  /// Offers answered or found expired here, hidden before the stream catches up.
  final Set<String> _hidden = {};
  final Set<String> _busy = {};

  Future<void> _respond(Offer o, bool accept) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(o.id));
    try {
      await ref.read(careWayApiProvider).respondToOffer(o.id, accept);
      setState(() => _hidden.add(o.id));
      messenger.showSnackBar(SnackBar(
        content: Text(accept ? "${o.patientName.split(' ').first}'s visit is on your schedule. The family pays next." : 'Request declined.'),
      ));
    } on CareWayException catch (e) {
      if (e.code == 'offer-expired') setState(() => _hidden.add(o.id));
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(caregiverProfileProvider).value;
    final now = ref.watch(tickProvider).value ?? ref.watch(clockProvider)();
    final offers = (ref.watch(cgOffersProvider).value ?? const <Offer>[])
        .where((o) => !_hidden.contains(o.id) && o.expiresAt.isAfter(now))
        .toList();
    final jobs = (ref.watch(cgBookingsProvider).value ?? const <Booking>[])
        .where((b) => isActiveJob(b) && sameLocalDay(b.apptAt, now))
        .toList()
      ..sort((a, b) => a.apptAt.compareTo(b.apptAt));
    final unread = (ref.watch(notificationsProvider).value ?? const []).where((n) => !n.read).length;
    final onDuty = profile?.onDuty ?? false;

    return CwPage(
      children: [
        Row(children: [
          Avatar(profile?.initials ?? '?', color: CwColors.tealDark, background: CwColors.tealSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hi, ${profile?.displayName.split(' ').first ?? 'there'}', style: CwText.h2),
              Text('${dayLabel(now)} · ${profile?.zone ?? ''} zone', style: CwText.small),
            ]),
          ),
          SquareIconButton(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            badge: unread,
            onTap: () => context.push('/cg/notifications'),
          ),
        ]),
        const Gap(12),
        CwCard(
          color: onDuty ? CwColors.successSoft : CwColors.surface,
          borderColor: onDuty ? CwColors.successSoft : CwColors.line,
          child: Row(children: [
            Icon(Icons.circle, size: 12, color: onDuty ? CwColors.success : CwColors.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(onDuty ? 'On duty' : 'Off duty', style: CwText.bodyBold)),
            Switch(
              value: onDuty,
              onChanged: profile == null ? null : (v) => ref.read(caregiverRepoProvider).setOnDuty(profile.uid, v),
            ),
          ]),
        ),
        if (!onDuty) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Go on duty to receive new job requests.', style: CwText.small)),
        const Gap(16),
        for (final o in offers) ...[
          _OfferCard(offer: o, now: now, busy: _busy.contains(o.id), onRespond: (a) => _respond(o, a)),
          const Gap(12),
        ],
        SectionTitle("Today's jobs", trailing: Text('${jobs.length} job${jobs.length == 1 ? '' : 's'}', style: CwText.small)),
        if (jobs.isEmpty) const Text('No jobs today.', style: CwText.muted),
        for (final b in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CwCard(
              onTap: () => context.push('/cg/job/${b.id}'),
              child: Row(children: [
                Column(children: [
                  Text(timeLabel(b.pickupAt ?? b.apptAt).split(' ').first, style: CwText.h3),
                  Text(timeLabel(b.pickupAt ?? b.apptAt).split(' ').last, style: CwText.small),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (b.status == BookingStatus.inProgress)
                      const CwBadge('IN PROGRESS', color: CwColors.white, background: CwColors.success),
                    Text('${b.patient.name}, ${b.patient.age}', style: CwText.bodyBold),
                    Text('${levelLabel(b.level)} · ${placeName(b.hospitalId)} · ${timeLabel(b.apptAt)}', style: CwText.small),
                    if (b.nextStepKey != null) Text('Next: ${stepLabels[b.nextStepKey]}', style: CwText.small),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: CwColors.muted),
              ]),
            ),
          ),
        const Gap(10),
        Row(children: [
          Expanded(child: _Stat('Patients today', '${jobs.map((j) => j.patientId).toSet().length}')),
          const SizedBox(width: 10),
          Expanded(child: _Stat('Your rating', profile == null ? '–' : '${profile.rating} ★')),
        ]),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.now, required this.busy, required this.onRespond});
  final Offer offer;
  final DateTime now;
  final bool busy;
  final ValueChanged<bool> onRespond;

  @override
  Widget build(BuildContext context) {
    final mins = offer.expiresAt.difference(now).inSeconds / 60;
    final minsLeft = mins.ceil().clamp(0, 999);
    final kind = switch (offer.kind) {
      OfferKind.personal => 'Personal escort',
      OfferKind.groupJoin => 'Join your group',
      OfferKind.groupNew => 'New group (helper)',
      OfferKind.delivery => 'Medicine run',
    };
    return CwCard(
      color: CwColors.amberSoft,
      borderColor: CwColors.amber.withValues(alpha: 0.3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 4, children: [
          const Text('NEW JOB REQUEST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: CwColors.amber)),
          Text('Expires in $minsLeft min', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: CwColors.amber)),
        ]),
        const SizedBox(height: 6),
        Text(
          '${offer.patientName}${offer.patientAge > 0 ? ', ${offer.patientAge}' : ''} · $kind',
          style: CwText.h3,
        ),
        if (offer.apptAt != null) Text('${dayTimeLabel(offer.apptAt!)} · ${offer.placeName}', style: CwText.small),
        if (offer.estimateSen > 0) Text('${formatRm(offer.estimateSen)} est.', style: CwText.small),
        if (offer.needs.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final n in offer.needs) CwBadge(n, color: CwColors.amber, background: CwColors.white)]),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: CwButton(label: 'Decline', kind: CwButtonKind.secondary, color: CwColors.amber, onPressed: busy ? null : () => onRespond(false))),
          const SizedBox(width: 10),
          Expanded(child: CwButton(label: 'Accept', color: CwColors.teal, loading: busy, onPressed: () => onRespond(true))),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => CwCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: CwText.small),
          Text(value, style: CwText.h2),
        ]),
      );
}
