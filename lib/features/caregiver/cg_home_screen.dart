import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/cw_top_bar.dart';
import '../../core/widgets/design_kit.dart';
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

    final children = <Widget>[
      Row(children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: CwColors.teal, shape: BoxShape.circle),
          child: Text(profile?.initials ?? '?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CwColors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hi, ${profile?.displayName.split(' ').first ?? 'there'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CgColors.ink)),
            const SizedBox(height: 2),
            Text('${dayLabel(now)}${(profile?.zone ?? '').isEmpty ? '' : ' · ${profile!.zone} zone'}', style: const TextStyle(fontSize: 13, color: CgColors.muted)),
          ]),
        ),
        Semantics(
          toggled: onDuty,
          label: 'On duty',
          excludeSemantics: true,
          child: Material(
            color: onDuty ? CwColors.successSoft : const Color(0xFFE4EBED),
            shape: const StadiumBorder(),
            child: InkWell(
              key: const ValueKey('duty-toggle'),
              customBorder: const StadiumBorder(),
              onTap: profile == null ? null : () => ref.read(caregiverRepoProvider).setOnDuty(profile.uid, !onDuty),
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: onDuty ? CwColors.success : CgColors.faint, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(onDuty ? 'On duty' : 'Off duty',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: onDuty ? const Color(0xFF1D6B45) : CgColors.muted)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SquareIconButton(svg: CwIcons.bell, label: 'Notifications', badge: unread, color: CgColors.ink, onTap: () => context.push('/cg/notifications')),
      ]),
      if (!onDuty) const Text('Go on duty to receive new job requests.', style: TextStyle(fontSize: 12, color: CgColors.muted)),
      for (final o in offers) _OfferCard(offer: o, now: now, busy: _busy.contains(o.id), onRespond: (a) => _respond(o, a)),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        const Expanded(child: Text("Today's jobs", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CgColors.ink))),
        Text('${jobs.length} job${jobs.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CgColors.muted)),
      ]),
      if (jobs.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
          child: const Text('No jobs today.', style: TextStyle(fontSize: 13, color: CgColors.muted)),
        ),
      for (final b in jobs) b.status == BookingStatus.inProgress ? _LiveJob(b) : _JobRow(b),
      Row(children: [
        Expanded(child: _Stat('Patients today', '${jobs.map((j) => j.patientId).toSet().length}', () => context.go('/cg/patients'))),
        const SizedBox(width: 10),
        Expanded(child: _Stat('Your rating', profile == null ? '–' : '${profile.rating} ★', () => context.go('/cg/account'))),
      ]),
    ];

    return Scaffold(
      backgroundColor: CgColors.surface,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]],
          ],
        ),
      ),
    );
  }
}

class _LiveJob extends StatelessWidget {
  const _LiveJob(this.b);
  final Booking b;

  @override
  Widget build(BuildContext context) {
    final keys = b.stepKeys;
    return Material(
      color: CwColors.teal,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/cg/job/${b.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF7BE3B4), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Expanded(child: Text('IN PROGRESS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: CwColors.white))),
              Tag(levelLabel(b.level), background: const Color(0x2EFFFFFF), color: CwColors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3)),
            ]),
            const SizedBox(height: 12),
            Text('${b.patient.name}, ${b.patient.age}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CwColors.white)),
            const SizedBox(height: 3),
            Text('${placeName(b.hospitalId)}${b.clinic.isEmpty ? '' : ' · ${b.clinic}'} · ${timeLabel(b.apptAt)}',
                style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
            const SizedBox(height: 12),
            Semantics(
              label: '${b.steps.length} of ${keys.length} steps done',
              child: Row(children: [
                for (var i = 0; i < keys.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(color: i < b.steps.length ? CwColors.white : const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(b.nextStepKey == null ? 'All steps done' : 'Next: ${stepLabels[b.nextStepKey]}',
                    style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
              ),
              const Text('Update ›', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CwColors.white)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow(this.b);
  final Booking b;

  @override
  Widget build(BuildContext context) {
    final t = timeLabel(b.pickupAt ?? b.apptAt).split(' ');
    return Material(
      color: CwColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/cg/job/${b.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 52,
              height: 56,
              decoration: BoxDecoration(color: CgColors.soft, borderRadius: BorderRadius.circular(14)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(t.first, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CwColors.tealDark)),
                Text(t.last, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CwColors.tealDark)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${b.patient.name}, ${b.patient.age}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CgColors.ink)),
                const SizedBox(height: 3),
                Text('${levelLabel(b.level)} · ${placeName(b.hospitalId)} · ${b.patient.mobility.label.toLowerCase()}',
                    style: const TextStyle(fontSize: 12, color: CgColors.muted)),
              ]),
            ),
            const CwIcon(CwIcons.chevronRight, size: 20, strokeWidth: 2.4, color: CgColors.faint),
          ]),
        ),
      ),
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
    final minsLeft = (offer.expiresAt.difference(now).inSeconds / 60).ceil().clamp(0, 999);
    final kind = switch (offer.kind) {
      OfferKind.personal => 'Personal escort',
      OfferKind.groupJoin => 'Join your group',
      OfferKind.groupNew => 'New group (helper)',
      OfferKind.delivery => 'Medicine run',
    };
    const meta = TextStyle(fontSize: 13, color: CgColors.ink2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: CwColors.white, border: Border.all(color: CwColors.teal, width: 2), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('NEW JOB REQUEST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: CwColors.teal))),
          Text('Expires in $minsLeft min', style: const TextStyle(fontSize: 12, color: CgColors.muted)),
        ]),
        const SizedBox(height: 10),
        Text('${offer.patientName}${offer.patientAge > 0 ? ', ${offer.patientAge}' : ''} · $kind',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CgColors.ink)),
        if (offer.apptAt != null) ...[const SizedBox(height: 3), Text('${dayTimeLabel(offer.apptAt!)} · ${offer.placeName}', style: meta)],
        if (offer.estimateSen > 0) ...[const SizedBox(height: 3), Text('${formatRm(offer.estimateSen)} est.', style: meta)],
        if (offer.needs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final n in offer.needs) Tag(n, background: CgColors.soft, color: CwColors.tealDark, fontSize: 12),
          ]),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            flex: 10,
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: busy ? null : () => onRespond(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CgColors.ink2,
                  side: const BorderSide(color: CgColors.line, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontFamily: cwFont, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                child: const Text('Decline'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 14,
            child: BigButton(label: 'Accept', color: CwColors.teal, height: 48, fontSize: 15, radius: 14, loading: busy, onPressed: () => onRespond(true)),
          ),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.onTap);
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: CwColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CgColors.muted)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CgColors.ink)),
            ]),
          ),
        ),
      );
}
