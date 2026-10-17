import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/places.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
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
    final groups = draft.hospitalId == null || draft.dateKey == null
        ? const AsyncValue<List<Group>>.data([])
        : ref.watch(_dayGroupsProvider((draft.hospitalId!, draft.dateKey!)));
    final list = groups.value ?? const <Group>[];
    Group? chosen;
    for (final g in list) {
      if (g.id == _pick) chosen = g;
    }
    final isNew = _pick == 'new';
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

    return CwPage(
      title: 'Pick a group',
      stepLabel: 'Step 3 of 3 · Level 1 shared ride',
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(foot, textAlign: TextAlign.center, style: CwText.small),
        const SizedBox(height: 8),
        CwButton(label: cta, loading: _busy, onPressed: _pick == null ? null : submit),
      ]),
      children: [
        Text('${placeName(draft.hospitalId ?? '')} · ${(draft.clinic ?? '').replaceAll(' specialist clinic', '')}', style: CwText.h3),
        Text(
          '${draft.apptAt == null ? '' : dayLabel(draft.apptAt!)} · ${patient?.name.split(' ').first ?? 'Your'}\'s appointment ${draft.apptAt == null ? '' : timeLabel(draft.apptAt!)}',
          style: CwText.small,
        ),
        const Gap(14),
        AsyncView<List<Group>>(
          value: groups,
          onRetry: () => ref.invalidate(_dayGroupsProvider),
          data: (gs) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              gs.isEmpty ? 'No groups going that day yet' : '${gs.length} group${gs.length == 1 ? '' : 's'} going the same way',
              style: CwText.bodyBold,
            ),
            const Text('Up to 3 riders each', style: CwText.small),
            const Gap(10),
            for (final g in gs) ...[
              _GroupCard(
                group: g,
                now: now,
                price: _price(g, now),
                selected: _pick == g.id,
                best: g == _best(gs, now),
                onTap: () => setState(() => _pick = g.id),
              ),
              const Gap(10),
            ],
          ]),
        ),
        CwCard(
          selected: isNew,
          onTap: () => setState(() => _pick = 'new'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.add_circle_outline, color: CwColors.primary),
              SizedBox(width: 10),
              Text('Start a new group', style: CwText.h3),
            ]),
            const SizedBox(height: 4),
            const Text('Neighbours can join you. If no one does, you still ride, capped at RM 40.', style: CwText.muted),
            if (isNew) ...[
              const Gap(12),
              const Text('Pickup point', style: CwText.label),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in pickupPoints)
                  CwChip(label: p.name, selected: _newPoint == p.id, onTap: () => setState(() => _newPoint = p.id)),
              ]),
              const Gap(10),
              const Text('Pickup time', style: CwText.label),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final o in _newGroupOffsets)
                  CwChip(
                    label: draft.apptAt == null ? '$o min before' : timeLabel(draft.apptAt!.subtract(Duration(minutes: o))),
                    selected: _newOffset == o,
                    onTap: () => setState(() => _newOffset = o),
                  ),
              ]),
            ],
          ]),
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
    return Opacity(
      opacity: full && !selected ? 0.7 : 1,
      child: CwCard(
        selected: selected,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(point?.name ?? group.pickupPointId, style: CwText.h3)),
            CwBadge(
              full ? 'Full · waitlist' : (best ? 'Best match' : '$left seat${left == 1 ? '' : 's'} left'),
              color: full ? CwColors.muted : (best ? CwColors.successDark : CwColors.primaryDark),
              background: full ? CwColors.surface : (best ? CwColors.successSoft : CwColors.lilac),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Pickup ${timeLabel(group.pickupAt)} · Appts ${group.apptWindow}', style: CwText.small),
          const SizedBox(height: 10),
          Row(children: [
            SeatRow(initials: group.riderInitials),
            const SizedBox(width: 6),
            Expanded(child: Text(full ? 'Full' : '$left seat${left == 1 ? '' : 's'} left', style: CwText.small)),
            Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Helper: ${group.caregiverName ?? 'to be confirmed'}${group.caregiverRating == null ? '' : ' · ${group.caregiverRating} ★'}',
            style: CwText.small,
          ),
        ]),
      ),
    );
  }
}

