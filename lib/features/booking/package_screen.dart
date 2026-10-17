import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/step_label.dart';
import '../../data/models/booking.dart';
import '../../data/providers.dart';
import '../../domain/pricing.dart';
import 'booking_common.dart';
import 'booking_draft.dart';

const _ticks = {
  GroupPackage.saver: ['Shared van + helper', 'Home at 12:30 or 3:30 PM', 'Free cancel 24h before'],
  GroupPackage.flex: ['Shared van + helper', 'Home as soon as done', 'Free cancel 24h before'],
};
const _tags = {GroupPackage.saver: 'Lowest price', GroupPackage.flex: 'Less waiting'};
const _notes = {
  GroupPackage.saver: 'Group Saver: cancel after 24 hours and you get CareWay credit. Waiting time is never charged.',
  GroupPackage.flex: 'Group Flex: cancel after 24 hours and you get 50% back. Waiting time is never charged.',
};

/// 7 · Group found: choose a package and add-ons (Match.dc.html).
class PackageScreen extends ConsumerWidget {
  const PackageScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return CwPage(
      title: 'Group found',
      stepLabel: 'Step 3 of 3 · Choose a package',
      showBack: false,
      children: [
        AsyncView<Booking?>(
          value: booking,
          onRetry: () => ref.invalidate(bookingProvider(bookingId)),
          isEmpty: (b) => b == null,
          empty: const EmptyState(icon: Icons.search_off, title: 'Booking not found'),
          data: (b) => _Body(b!),
        ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.b);
  final Booking b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftProvider);
    final notifier = ref.read(bookingDraftProvider.notifier);
    final group = b.groupId == null ? null : ref.watch(groupProvider(b.groupId!)).value;
    final n = ridersWithMe(group, b.id);
    final helper = b.caregiverName ?? 'your helper';
    final langs = languageOptions(b);
    final addons = {for (final a in draft.addons) if (addonAvailable(a, b)) a};
    final share = groupShareSen(draft.package, n);
    final total = share + addonsSen(addons);
    final first = b.patient.name.split(' ').first;
    final others = n - 1;

    void toggle(Addon a) {
      final next = {...draft.addons};
      next.contains(a) ? next.remove(a) : next.add(a);
      notifier.update((d) => d.copyWith(
            addons: next,
            language: () => a == Addon.language && next.contains(a) ? (d.language ?? langs.firstOrNull) : d.language,
          ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(others == 0 ? '$first starts the group' : '$first joins $others neighbour${others == 1 ? '' : 's'}', style: CwText.h2),
      Text(
        'Pickup ${b.pickupAt == null ? '' : timeLabel(b.pickupAt!)} · ${dayLabel(b.apptAt)} ${timeLabel(b.apptAt)} · Helper $helper',
        style: CwText.small,
      ),
      const Gap(16),
      const SectionTitle('Pick a package'),
      for (final p in GroupPackage.values) ...[
        CwCard(
          selected: draft.package == p,
          onTap: () => notifier.update((d) => d.copyWith(package: p)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(draft.package == p ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: draft.package == p ? CwColors.primary : CwColors.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(p.label, style: CwText.h3)),
              Text('RM ${groupShareSen(p, n) ~/ 100}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            CwBadge(_tags[p]!.toUpperCase()),
            const SizedBox(height: 6),
            for (final t in _ticks[p]!)
              Row(children: [
                const Icon(Icons.check, size: 16, color: CwColors.success),
                const SizedBox(width: 6),
                Expanded(child: Text(t, style: CwText.small)),
              ]),
          ]),
        ),
        const Gap(10),
      ],
      Text(_notes[draft.package]!, style: CwText.small),
      const Gap(8),
      Text(
        'Price for $n rider${n == 1 ? '' : 's'}. If more neighbours join before the group locks, your price drops and you get the difference back.',
        style: CwText.small,
      ),
      const Gap(18),
      const SectionTitle('Services provided', trailing: CwBadge('INCLUDED', color: CwColors.successDark, background: CwColors.successSoft)),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in ['Pre-registration', 'Help at registration', 'Queue tracking', 'Live family updates']) CwBadge(s),
      ]),
      const Gap(18),
      const SectionTitle('Add-ons', trailing: Text('Optional', style: CwText.small)),
      for (final a in Addon.values) ...[
        _AddonRow(
          addon: a,
          available: addonAvailable(a, b),
          selected: addons.contains(a),
          helper: helper,
          onTap: () => toggle(a),
        ),
        if (a == Addon.language && addons.contains(a))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final l in langs)
                CwChip(label: l, selected: draft.language == l, onTap: () => notifier.update((d) => d.copyWith(language: () => l))),
            ]),
          ),
      ],
      const Gap(12),
      CwCard(
        color: CwColors.lilac,
        borderColor: CwColors.lilac,
        child: Row(children: [
          Expanded(
            child: Text(
              '${draft.package.label}${addons.isEmpty ? '' : ' + ${addons.length} add-on${addons.length == 1 ? '' : 's'}'}',
              style: CwText.bodyBold,
            ),
          ),
          Text(formatRm(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
      ),
      const Gap(14),
      CwButton(
        label: 'Continue to payment',
        onPressed: () {
          notifier.update((d) => d.copyWith(addons: addons));
          context.push('/booking/${b.id}/pay');
        },
      ),
    ]);
  }
}

class _AddonRow extends StatelessWidget {
  const _AddonRow({required this.addon, required this.available, required this.selected, required this.helper, required this.onTap});
  final Addon addon;
  final bool available;
  final bool selected;
  final String helper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Opacity(
          opacity: available ? 1 : 0.55,
          child: CwCard(
            selected: selected,
            onTap: available ? onTap : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(selected ? Icons.check_box : Icons.check_box_outline_blank, color: selected ? CwColors.primary : CwColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(addon.label, style: CwText.bodyBold),
                  if (!available) Text('Not offered by $helper', style: CwText.small),
                ]),
              ),
              Text(formatRm(addon.sen), style: CwText.bodyBold),
            ]),
          ),
        ),
      );
}
