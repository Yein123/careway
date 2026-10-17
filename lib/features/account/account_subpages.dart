import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/places.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/step_label.dart';
import '../../data/models/notification.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../booking/payment_screen.dart' show paymentMethods;
import 'account_screen.dart' show textSizes;

final receiptsProvider = StreamProvider<List<Receipt>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(receiptRepoProvider).watch(uid);
});

Future<void> _update(WidgetRef ref, Map<String, dynamic> fields) async {
  final uid = ref.read(authStateProvider).value;
  if (uid != null) await ref.read(userRepoProvider).update(uid, fields);
}

/// 25 · Payment methods (simulated)
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(currentUserProvider).value?.paymentMethods ?? const <PaymentMethod>[];
    Future<void> save(List<PaymentMethod> next) => _update(ref, {'paymentMethods': [for (final m in next) m.toMap()]});
    return CwPage(
      title: 'Payment methods',
      children: [
        const StepLabel('Saved methods'),
        const Gap(8),
        if (methods.isEmpty) const Text('No saved methods yet. You can still choose one when you pay.', style: CwText.muted),
        for (var i = 0; i < methods.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CwCard(
              selected: i == 0,
              onTap: () => save([methods[i], for (var j = 0; j < methods.length; j++) if (j != i) methods[j]]),
              child: Row(children: [
                Expanded(child: Text(methods[i].label, style: CwText.bodyBold)),
                if (i == 0) const CwBadge('DEFAULT'),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline, color: CwColors.muted),
                  onPressed: () => save([for (var j = 0; j < methods.length; j++) if (j != i) methods[j]]),
                ),
              ]),
            ),
          ),
        const Text('Tap a method to make it your default for new bookings.', style: CwText.small),
        const Gap(14),
        CwButton(
          label: '+ Add payment method',
          kind: CwButtonKind.secondary,
          onPressed: () async {
            final picked = await showModalBottomSheet<(String, String)>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final (id, name, sub, _, _, _) in paymentMethods)
                    ListTile(title: Text(name), subtitle: Text(sub), onTap: () => Navigator.pop(ctx, (id, name))),
                ]),
              ),
            );
            if (picked != null) save([...methods, PaymentMethod(type: picked.$1, label: picked.$2)]);
          },
        ),
        const Gap(8),
        const Text('Payments in this version are simulated; no money moves.', style: CwText.small),
      ],
    );
  }
}

/// 26 · Receipts
class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(receiptsProvider);
    return CwPage(
      title: 'Receipts',
      children: [
        AsyncView<List<Receipt>>(
          value: receipts,
          onRetry: () => ref.invalidate(receiptsProvider),
          isEmpty: (l) => l.isEmpty,
          empty: const EmptyState(icon: Icons.receipt_long_outlined, title: 'No receipts yet'),
          data: (list) => Column(children: [
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CwCard(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.label, style: CwText.bodyBold),
                        Text(
                          [
                            switch (r.kind) { ReceiptKind.payment => 'Payment', ReceiptKind.refund => 'Refund', ReceiptKind.credit => 'CareWay credit' },
                            if (r.method.isNotEmpty) r.method,
                            if (r.createdAt != null) dayLabel(r.createdAt!),
                          ].join(' · '),
                          style: CwText.small,
                        ),
                      ]),
                    ),
                    Text(
                      formatRm(r.kind == ReceiptKind.payment ? r.amountSen : -r.amountSen),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: r.kind == ReceiptKind.payment ? CwColors.ink : CwColors.successDark,
                      ),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ],
    );
  }
}

/// 27 · Saved places
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(currentUserProvider).value?.savedPlaces ?? const <SavedPlace>[];
    Future<void> save(List<SavedPlace> next) => _update(ref, {'savedPlaces': [for (final p in next) p.toMap()]});
    return CwPage(
      title: 'Saved places',
      children: [
        for (var i = 0; i < places.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CwCard(
              child: Row(children: [
                const Icon(Icons.place_outlined, color: CwColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(places[i].label, style: CwText.bodyBold),
                    Text(places[i].address, style: CwText.small),
                  ]),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline, color: CwColors.muted),
                  onPressed: () => save([for (var j = 0; j < places.length; j++) if (j != i) places[j]]),
                ),
              ]),
            ),
          ),
        if (places.isEmpty) const Text('Save your home so pickups and medicine deliveries are one tap.', style: CwText.muted),
        const Gap(8),
        const Text('The first place is used for medicine deliveries.', style: CwText.small),
        const Gap(14),
        CwButton(
          label: '+ Add a place',
          kind: CwButtonKind.secondary,
          onPressed: () async {
            final p = await showModalBottomSheet<SavedPlace>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _AddPlaceSheet(),
            );
            if (p != null) save([...places, p]);
          },
        ),
      ],
    );
  }
}

class _AddPlaceSheet extends StatefulWidget {
  const _AddPlaceSheet();

  @override
  State<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<_AddPlaceSheet> {
  final _label = TextEditingController(text: 'Home');
  final _address = TextEditingController();
  Place _near = pickupPoints.first;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Add a place', style: CwText.h2),
          const SizedBox(height: 12),
          LabeledField(label: 'Name', controller: _label),
          const SizedBox(height: 12),
          LabeledField(label: 'Address', controller: _address, hint: 'e.g. 12, Jalan Elmina Lakeside', onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          const Text('Nearest area (used for distance)', style: CwText.label),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in pickupPoints) CwChip(label: p.area == 'Elmina' ? p.name : p.area, selected: _near == p, onTap: () => setState(() => _near = p)),
          ]),
          const SizedBox(height: 16),
          CwButton(
            label: 'Save place',
            onPressed: _address.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, SavedPlace(label: _label.text.trim(), address: _address.text.trim(), lat: _near.lat, lng: _near.lng)),
          ),
        ]),
      );
}

/// 28 · Notification settings
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(currentUserProvider).value?.settings ?? const UserSettings();
    Widget toggle(String key, String label, String sub, bool value) => SwitchListTile(
          key: ValueKey('notif-$key'),
          contentPadding: EdgeInsets.zero,
          value: value,
          onChanged: (v) => _update(ref, {'settings.notif.$key': v}),
          title: Text(label, style: CwText.bodyBold),
          subtitle: Text(sub, style: CwText.small),
        );
    return CwPage(
      title: 'Notifications',
      children: [
        const StepLabel('Send me'),
        toggle('visitUpdates', 'Visit updates', 'Pickup, arrival, with the doctor, home safe', s.visitUpdates),
        toggle('reminders', 'Reminders', 'The evening before a visit', s.reminders),
        toggle('promos', 'News and offers', 'Health events and new services near you', s.promos),
        const Gap(10),
        const Text('Safety alerts, like a change of helper or a cancelled ride, are always sent.', style: CwText.small),
      ],
    );
  }
}

/// 29 · Language and text size
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(currentUserProvider).value?.settings ?? const UserSettings();
    return CwPage(
      title: 'Language and text size',
      children: [
        const StepLabel('App language'),
        const Gap(8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in const ['English', 'Bahasa Melayu', '中文'])
            CwChip(label: l, selected: s.language == l, onTap: () => _update(ref, {'settings.language': l})),
        ]),
        const Gap(6),
        const Text('Screens are in English in this version; your choice is saved for when translations arrive.', style: CwText.small),
        const Gap(20),
        const StepLabel('Text size'),
        const Gap(8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (name, scale) in textSizes)
            CwChip(label: name, selected: s.textScale == scale, onTap: () => _update(ref, {'settings.textScale': scale})),
        ]),
        const Gap(14),
        const CwCard(
          child: Text.rich(TextSpan(text: 'Preview: ', style: CwText.small, children: [
            TextSpan(text: 'Ride home is 5 min away', style: CwText.bodyBold),
          ])),
        ),
      ],
    );
  }
}

/// 30 · Privacy
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void info(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    return CwPage(
      title: 'Privacy',
      children: [
        const StepLabel('Sharing'),
        const Gap(8),
        const CwCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Patient profiles', style: CwText.bodyBold),
            Text('Only the helper assigned to a visit can read the profile, and only while that visit is active. Set per patient in their profile.',
                style: CwText.small),
            SizedBox(height: 10),
            Text('Co-riders', style: CwText.bodyBold),
            Text('Neighbours in a shared ride see only initials and the shared destination.', style: CwText.small),
          ]),
        ),
        const Gap(20),
        const StepLabel('Your data'),
        const Gap(8),
        CwCard(
          onTap: () => info("We'll email a copy of your data within 7 days."),
          child: const Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Request a copy of my data', style: CwText.bodyBold),
                Text('Sent to your email within 7 days', style: CwText.small),
              ]),
            ),
            Text('Request', style: TextStyle(fontWeight: FontWeight.w800, color: CwColors.primary)),
          ]),
        ),
        const Gap(8),
        CwCard(
          onTap: () => info('To delete your account, contact the CareWay coordinator. Family group admins are told first.'),
          child: const Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Delete my account', style: CwText.bodyBold),
                Text('Family group admins are told first', style: CwText.small),
              ]),
            ),
            Text('Delete', style: TextStyle(fontWeight: FontWeight.w800, color: CwColors.pink)),
          ]),
        ),
        const Gap(14),
        const Text("CareWay follows Malaysia's Personal Data Protection Act 2010.", style: CwText.small),
      ],
    );
  }
}
