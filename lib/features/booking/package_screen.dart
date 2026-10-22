import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/design_kit.dart';
import '../../core/widgets/fields.dart';
import '../../data/models/booking.dart';
import '../../data/providers.dart';
import '../../domain/pricing.dart';
import '../home/home_screen.dart' show placeName;
import 'booking_common.dart';
import 'booking_draft.dart';
import 'confirmed_screen.dart';
import 'payment_screen.dart' show isPaid;

const _ticks = {
  GroupPackage.saver: ['Shared van + helper', 'Home at 12:30 or 3:30 PM', 'Free cancel 24h before'],
  GroupPackage.flex: ['Shared van + helper', 'Home as soon as done', 'Free cancel 24h before'],
};
const _tags = {GroupPackage.saver: 'Lowest price', GroupPackage.flex: 'Less waiting'};
const _tagTones = {
  GroupPackage.saver: (CwColors.tealSoft, CwColors.tealDark),
  GroupPackage.flex: (CwColors.amberSoft, CwColors.amber),
};
const _notes = {
  GroupPackage.saver: 'Group Saver: cancel after 24 hours and you get CareWay credit. Waiting time is never charged.',
  GroupPackage.flex: 'Group Flex: cancel after 24 hours and you get 50% back. Waiting time is never charged.',
};
const _green = CwColors.successDark;
const _greenSoft = Color(0xFFDDF5EC);

/// 7 · Group found: choose a package and add-ons (Match.dc.html).
class PackageScreen extends ConsumerWidget {
  const PackageScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return booking.when(
      loading: () => const Scaffold(backgroundColor: CwColors.surface, body: Center(child: CircularProgressIndicator())),
      error: (_, _) => DesignScaffold(children: [
        const PageHeader(title: 'Group found', subtitle: 'Step 3 of 3 · Choose a package', help: true),
        AsyncView<Booking?>(value: booking, onRetry: () => ref.invalidate(bookingProvider(bookingId)), data: (_) => const SizedBox()),
      ]),
      data: (b) => b == null
          ? const DesignScaffold(children: [
              PageHeader(title: 'Group found', subtitle: 'Step 3 of 3 · Choose a package', help: true),
              EmptyState(icon: Icons.search_off, title: 'Booking not found'),
            ])
          // Opened from an old "pay to confirm" notification after paying.
          : isPaid(b)
              ? ConfirmedScreen(bookingId: bookingId)
              : _Body(b),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(color: _greenSoft, shape: BoxShape.circle),
          child: const Center(child: CwIcon(CwIcons.check, size: 11, strokeWidth: 3.6, color: _green)),
        ),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.35))),
      ]);
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
    final addons = draft.addons;
    final share = groupShareSen(draft.package, n);
    final total = share + addonsSen(addons);
    final first = b.patient.name.split(' ').first;
    final others = n - 1;

    void toggle(Addon a) {
      final next = {...draft.addons};
      next.contains(a) ? next.remove(a) : next.add(a);
      notifier.update((d) => d.copyWith(addons: next));
    }

    return DesignScaffold(
      gap: 14,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      bottom: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${draft.package.label}${addons.isEmpty ? '' : ' + ${addons.length} add-on${addons.length == 1 ? '' : 's'}'}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CwColors.muted),
          ),
          const SizedBox(height: 1),
          Text(formatRm(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: BigButton(
            label: 'Continue to payment',
            trailingIcon: CwIcons.arrowRight,
            height: 54,
            fontSize: 16,
            onPressed: () {
              if (addons.contains(Addon.language) && (draft.language ?? '').trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Type the language needed for Language help.')),
                );
                return;
              }
              context.push('/booking/${b.id}/pay');
            },
          ),
        ),
      ]),
      children: [
        const PageHeader(title: 'Group found', subtitle: 'Step 3 of 3 · Choose a package', help: true),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: CwColors.primary, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: CwColors.white, shape: BoxShape.circle),
              child: const Center(child: CwIcon(CwIcons.check, size: 22, strokeWidth: 3, color: CwColors.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(others == 0 ? '$first starts the group' : '$first joins $others neighbour${others == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CwColors.white)),
                const SizedBox(height: 3),
                Text(
                  'Pickup ${b.pickupAt == null ? '' : timeLabel(b.pickupAt!)} · ${placeName(b.hospitalId)} ${timeLabel(b.apptAt)} · Helper $helper',
                  style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xEBFFFFFF)),
                ),
              ]),
            ),
          ]),
        ),
        const SectionLabel('Pick a package', size: 16),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final p in GroupPackage.values) ...[
              if (p != GroupPackage.values.first) const SizedBox(width: 10),
              Expanded(
                child: SelectCard(
                  on: draft.package == p,
                  radius: 18,
                  padding: const EdgeInsets.all(12),
                  onTap: () => notifier.update((d) => d.copyWith(package: p)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(color: _tagTones[p]!.$1, borderRadius: BorderRadius.circular(8)),
                            child: Text(_tags[p]!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _tagTones[p]!.$2)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Transform.scale(scale: 20 / 22, child: RadioDot(on: draft.package == p)),
                    ]),
                    const SizedBox(height: 10),
                    Text(p.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('RM ${groupShareSen(p, n) ~/ 100}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
                    const SizedBox(height: 10),
                    for (final t in _ticks[p]!) Padding(padding: const EdgeInsets.only(bottom: 7), child: _Tick(t)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Text(
            '${_notes[draft.package]!} Price for $n rider${n == 1 ? '' : 's'}; if more neighbours join before the group locks, you get the difference back.',
            style: const TextStyle(fontSize: 11, height: 1.4, color: CwColors.muted),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Expanded(child: Text('Services provided', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              Text('Included', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _green)),
            ]),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) => Wrap(spacing: 10, runSpacing: 8, children: [
                for (final s in ['Pre-registration', 'Help at registration', 'Queue tracking', 'Live family updates'])
                  SizedBox(width: (c.maxWidth - 10) / 2, child: _Tick(s)),
              ]),
            ),
          ]),
        ),
        const Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text('Add-ons', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          Text('Optional', style: TextStyle(fontSize: 12, color: CwColors.muted)),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final a in Addon.values) ...[
            _AddonRow(addon: a, selected: addons.contains(a), onTap: () => toggle(a)),
            if (a == Addon.language && addons.contains(a))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LanguageField(
                  initial: draft.language ?? '',
                  onChanged: (v) => notifier.update((d) => d.copyWith(language: () => v.trim().isEmpty ? null : v.trim())),
                ),
              ),
          ],
        ]),
      ],
    );
  }
}

/// Free-text language for the "Language help" add-on.
class _LanguageField extends StatefulWidget {
  const _LanguageField({required this.initial, required this.onChanged});
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_LanguageField> createState() => _LanguageFieldState();
}

class _LanguageFieldState extends State<_LanguageField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LabeledField(
        label: 'What language is needed?',
        controller: _controller,
        hint: 'e.g. Tamil, Cantonese, sign language',
        textInputAction: TextInputAction.done,
        onChanged: (v) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          widget.onChanged(v);
        },
      );
}

class _AddonRow extends StatelessWidget {
  const _AddonRow({required this.addon, required this.selected, required this.onTap});
  final Addon addon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
            checked: selected,
            child: SelectCard(
              on: selected,
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? CwColors.primary : CwColors.white,
                      border: Border.all(color: selected ? CwColors.primary : const Color(0xFFC9C4D9), width: 2),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: selected ? const Center(child: CwIcon(CwIcons.check, size: 13, strokeWidth: 3.4, color: CwColors.white)) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(addon.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Text(formatRm(addon.sen), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
                ]),
              ),
            ),
          ),
      );
}
