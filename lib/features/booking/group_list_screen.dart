import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/places.dart';
import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/design_kit.dart';
import '../../core/widgets/seat_row.dart';
import '../../data/models/group.dart';
import '../../data/providers.dart';
import '../../domain/pricing.dart';
import '../home/home_screen.dart' show placeName;
import 'booking_draft.dart';
import 'submit.dart';

final _dayGroupsProvider = StreamProvider.family<List<Group>, (String, String)>(
  (ref, k) => ref.watch(groupRepoProvider).watchForDay(hospitalId: k.$1, date: k.$2),
);

/// Pickup offsets offered when starting a new group (minutes before the appointment).
const _newGroupOffsets = [90, 75, 60];

/// 5 · Group list (Groups.dc.html)
class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key, this.startNew = false});

  /// Preselect "Start a new group" (from Group not found).
  final bool startNew;

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  late String? _pick = widget.startNew ? 'new' : null; // group id or 'new'
  String _newPoint = pickupPoints.first.id;
  int _newOffset = 75;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final patient = draftPatient(ref);
    final now = ref.watch(clockProvider)();
    final allGroups = draft.hospitalId == null || draft.dateKey == null
        ? const AsyncValue<List<Group>>.data([])
        : ref.watch(_dayGroupsProvider((draft.hospitalId!, draft.dateKey!)));
    // A group whose pickup time has passed can no longer be joined.
    final groups = allGroups.whenData((l) => [for (final g in l) if (g.pickupAt.isAfter(now)) g]);
    final list = groups.value ?? const <Group>[];
    final best = _best(list, now);
    // Preselect the best match the first time groups arrive.
    final pick = _pick ?? best?.id;
    Group? chosen;
    for (final g in list) {
      if (g.id == pick) chosen = g;
    }
    final isNew = pick == 'new';
    final full = chosen != null && chosen.isFull(now);

    final cta = isNew ? 'Start my group' : (full ? 'Join the waitlist' : 'Request to join');
    final foot = isNew
        ? 'Up to RM 40 · waiting is not charged'
        : chosen == null
            ? 'Pick a group or start your own.'
            : full
                ? 'We hold your place if someone cancels'
                : 'Estimated ${_price(chosen, now)} · final price shown before you confirm';

    Future<void> submit() async {
      final appt = draft.apptAt!;
      ref.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
            groupId: () => isNew ? null : chosen!.id,
            newGroup: () => isNew
                ? NewGroupChoice(pickupPointId: _newPoint, pickupAt: appt.subtract(Duration(minutes: _newOffset)))
                : null,
            waitlist: full,
          ));
      setState(() => _busy = true);
      await submitDraft(context, ref);
      if (mounted) setState(() => _busy = false);
    }

    return DesignScaffold(
      gap: 14,
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(foot, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
        const SizedBox(height: 8),
        BigButton(label: cta, trailingIcon: CwIcons.arrowRight, height: 58, loading: _busy, onPressed: pick == null ? null : submit),
      ]),
      children: [
        const PageHeader(title: 'Pick a group', subtitle: 'Step 3 of 3 · Level 1 shared ride', help: true),
        const StepBars(count: 3, filled: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const CwIcon(CwIcons.hospital, size: 20, strokeWidth: 2.2, color: CwColors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${placeName(draft.hospitalId ?? '')} · ${(draft.clinic ?? '').replaceAll(' specialist clinic', '')}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 1),
                Text(
                  "${draft.apptAt == null ? '' : dayLabel(draft.apptAt!)} · ${patient?.name.split(' ').first ?? 'Your'}'s appointment ${draft.apptAt == null ? '' : timeLabel(draft.apptAt!)}",
                  style: const TextStyle(fontSize: 12, color: CwColors.muted),
                ),
              ]),
            ),
          ]),
        ),
        AsyncView<List<Group>>(
          value: groups,
          onRetry: () => ref.invalidate(_dayGroupsProvider),
          data: (gs) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Expanded(
                child: Text(
                  gs.isEmpty ? 'No groups going that day yet' : '${gs.length} group${gs.length == 1 ? '' : 's'} going the same way',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              const Text('Up to 3 riders each', style: TextStyle(fontSize: 11, color: CwColors.muted)),
            ]),
            for (final g in gs) ...[
              const SizedBox(height: 14),
              _GroupCard(
                group: g,
                now: now,
                price: _price(g, now),
                selected: pick == g.id,
                best: g == best,
                onTap: () => setState(() => _pick = g.id),
              ),
            ],
          ]),
        ),
        Semantics(
          button: true,
          selected: isNew,
          child: Material(
            color: isNew ? CwColors.lilac : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _pick = 'new'),
              child: CustomPaint(
                painter: isNew ? null : _DashedBorder(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: isNew
                      ? BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: CwColors.primary, width: 2))
                      : null,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: isNew ? CwColors.white : CwColors.lilac, borderRadius: BorderRadius.circular(12)),
                        child: const Text('+', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CwColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Start a new group', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text('Neighbours can join you. If no one does, you still ride, capped at RM 40.',
                              style: TextStyle(fontSize: 12, height: 1.4, color: CwColors.muted)),
                        ]),
                      ),
                    ]),
                    if (isNew) ...[
                      const SizedBox(height: 12),
                      const Text('Pickup point', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final p in pickupPoints) _Choice(label: p.name, on: _newPoint == p.id, onTap: () => setState(() => _newPoint = p.id)),
                      ]),
                      const SizedBox(height: 10),
                      const Text('Pickup time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final o in _newGroupOffsets)
                          _Choice(
                            label: draft.apptAt == null ? '$o min before' : timeLabel(draft.apptAt!.subtract(Duration(minutes: o))),
                            on: _newOffset == o,
                            onTap: () => setState(() => _newOffset = o),
                          ),
                      ]),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _price(Group g, DateTime now) {
    final n = (g.riders + 1).clamp(1, groupCapacity);
    return 'RM ${groupShareSen(GroupPackage.saver, n) ~/ 100}';
  }

  /// The open group with the most riders (cheapest share).
  static Group? _best(List<Group> gs, DateTime now) {
    final open = gs.where((g) => !g.isFull(now)).toList()..sort((a, b) => b.riders.compareTo(a.riders));
    return open.isEmpty ? null : open.first;
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.on, required this.onTap});
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
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? CwColors.white : CwColors.ink)),
              ),
            ),
          ),
        ),
      );
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9C4D9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)).deflate(1));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.now, required this.price, required this.selected, required this.best, required this.onTap});
  final Group group;
  final DateTime now;
  final String price;
  final bool selected;
  final bool best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final full = group.isFull(now);
    final left = group.seatsLeft(now);
    final point = pickupPoints.where((p) => p.id == group.pickupPointId).firstOrNull;
    final badgeTone = full
        ? (const Color(0xFFEFECF6), CwColors.muted)
        : best
            ? (CwColors.primary, CwColors.white)
            : (CwColors.tealSoft, CwColors.tealDark);
    const meta = TextStyle(fontSize: 12, color: kInk2);
    return Opacity(
      opacity: full && !selected ? 0.7 : 1,
      child: SelectCard(
        on: selected,
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(point?.name ?? group.pickupPointId, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            Tag(full ? 'Full · waitlist' : (best ? 'Best match' : '$left seat${left == 1 ? '' : 's'} left'), background: badgeTone.$1, color: badgeTone.$2),
          ]),
          const SizedBox(height: 9),
          Wrap(spacing: 14, runSpacing: 4, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const CwIcon(CwIcons.clock, size: 14, strokeWidth: 2.4, color: CwColors.primary),
              const SizedBox(width: 4),
              Text('Pickup ${timeLabel(group.pickupAt)}', style: meta),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const CwIcon('<path d="M4 10h16M7 4v4M17 4v4"/><rect x="4" y="6" width="16" height="14" rx="3"/>', size: 14, strokeWidth: 2.4, color: CwColors.primary),
              const SizedBox(width: 4),
              Text('Appts ${group.apptWindow}', style: meta),
            ]),
          ]),
          const SizedBox(height: 9),
          Row(children: [
            SeatRow(initials: group.riderInitials),
            const SizedBox(width: 10),
            Expanded(child: Text(full ? 'Full' : '$left seat${left == 1 ? '' : 's'} left', style: const TextStyle(fontSize: 12, color: CwColors.muted))),
            Text(price, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
          ]),
          const SizedBox(height: 9),
          Text(
            'Helper: ${group.caregiverName ?? 'to be confirmed'}${group.caregiverRating == null ? '' : ' · ${group.caregiverRating} ★'}',
            style: const TextStyle(fontSize: 12, color: CwColors.muted),
          ),
        ]),
      ),
    );
  }
}
