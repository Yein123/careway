import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/places.dart';
import '../../core/icons.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_sheet.dart';
import '../../core/widgets/design_kit.dart';
import '../../core/widgets/fields.dart';
import '../../data/models/notification.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../booking/payment_screen.dart' show paymentMethods;
import 'account_screen.dart' show GroupLabel, ListCard, textSizes;

final receiptsProvider = StreamProvider<List<Receipt>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(receiptRepoProvider).watch(uid);
});

Future<void> _update(WidgetRef ref, Map<String, dynamic> fields) async {
  final uid = ref.read(authStateProvider).value;
  if (uid != null) await ref.read(userRepoProvider).update(uid, fields);
}

/// Sub-page shell: back + title, 16 px gaps (AccPay.dc.html and friends).
class _SubPage extends StatelessWidget {
  const _SubPage({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DesignScaffold(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [PageHeader(title: title), ...children],
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Transform.translate(offset: const Offset(0, 6), child: GroupLabel(text));
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text, style: const TextStyle(fontSize: 12, height: 1.5, color: CwColors.muted)),
      );
}

class _DashedButton extends StatelessWidget {
  const _DashedButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: CustomPaint(
          painter: _Dashes(),
          child: SizedBox(
            height: 52,
            child: Center(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: CwColors.primaryDark))),
          ),
        ),
      );
}

class _Dashes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9C4D9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)).deflate(1));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _methodTones = {
  'fpx': (Color(0xFFE4DCFB), CwColors.primaryDark),
  'tng': (CwColors.tealSoft, CwColors.tealDark),
  'duitnow': (CwColors.pinkSoft, Color(0xFFA02A4C)),
  'card': (CwColors.amberSoft, CwColors.amber),
};

/// 25 · Payment methods (simulated)
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(currentUserProvider).value?.paymentMethods ?? const <PaymentMethod>[];
    final family = ref.watch(familyProvider).value;
    Future<void> save(List<PaymentMethod> next) => _update(ref, {'paymentMethods': [for (final m in next) m.toMap()]});
    return _SubPage(title: 'Payment methods', children: [
      const _Label('Saved methods'),
      if (methods.isEmpty)
        const _Note('No saved methods yet. You can still choose one when you pay.')
      else
        Column(children: [
          for (var i = 0; i < methods.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Builder(builder: (context) {
              final m = methods[i];
              final info = paymentMethods.firstWhereOrNull((p) => p.$1 == m.type);
              final tone = _methodTones[m.type] ?? _methodTones['fpx']!;
              return SelectCard(
                on: i == 0,
                onColor: CwColors.white,
                radius: 18,
                padding: const EdgeInsets.all(14),
                onTap: () => save([m, for (var j = 0; j < methods.length; j++) if (j != i) methods[j]]),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(10)),
                    child: Text(info?.$4 ?? m.type.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tone.$2)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(info?.$3 ?? '', style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                    ]),
                  ),
                  if (i == 0) const Tag('Default', background: CwColors.primary, color: CwColors.white),
                ]),
              );
            }),
          ],
        ]),
      const _Note('Tap a method to make it your default for new bookings.'),
      _DashedButton(
        label: '+ Add payment method',
        onTap: () async {
          final picked = await showCwSheet<(String, String)>(
            context,
            builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Add payment method', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              for (final (id, name, sub, abbr, bg, fg) in paymentMethods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectCard(
                    on: false,
                    onTap: () => Navigator.pop(ctx, (id, name)),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                        child: Text(abbr, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          Text(sub, style: const TextStyle(fontSize: 11, color: CwColors.muted)),
                        ]),
                      ),
                    ]),
                  ),
                ),
            ]),
          );
          if (picked != null) save([...methods, PaymentMethod(type: picked.$1, label: picked.$2)]);
        },
      ),
      if (family != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(16)),
          child: Text('Admins of the ${family.name} group can also pay for visits booked by other members. Payments in this version are simulated.',
              style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF3A2591))),
        ),
    ]);
  }
}

/// 26 · Receipts
class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(receiptsProvider);
    final now = ref.watch(clockProvider)();
    return _SubPage(title: 'Receipts', children: [
      AsyncView<List<Receipt>>(
        value: receipts,
        onRetry: () => ref.invalidate(receiptsProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyState(icon: Icons.receipt_long_outlined, title: 'No receipts yet'),
        data: (list) {
          final sorted = [...list]..sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
          final byMonth = groupBy(sorted, (Receipt r) => DateFormat('MMMM yyyy').format((r.createdAt ?? now).toLocal()));
          final thisMonth = DateFormat('MMMM yyyy').format(now.toLocal());
          final current = byMonth[thisMonth] ?? const <Receipt>[];
          final net = current.fold(0, (t, r) => t + (r.kind == ReceiptKind.payment ? r.amountSen : -r.amountSen));
          final paidCount = current.where((r) => r.kind == ReceiptKind.payment).length;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: CwColors.primary, borderRadius: BorderRadius.circular(20)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(DateFormat('MMMM yyyy').format(now.toLocal()), style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
                    const SizedBox(height: 4),
                    Text(formatRm(net),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: CwColors.white, fontFeatures: [FontFeature.tabularFigures()])),
                  ]),
                ),
                Text('$paidCount payment${paidCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF))),
              ]),
            ),
            for (final entry in byMonth.entries) ...[
              const SizedBox(height: 16),
              GroupLabel(entry.key.split(' ').first),
              const SizedBox(height: 10),
              ListCard(children: [
                for (final r in entry.value)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: CwIcon(CwIcons.receipt, size: 20, strokeWidth: 2.2, color: CwColors.primaryDark)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (r.createdAt != null) DateFormat('d MMM').format(r.createdAt!.toLocal()),
                              switch (r.kind) { ReceiptKind.payment => 'Payment', ReceiptKind.refund => 'Refund', ReceiptKind.credit => 'CareWay credit' },
                              if (r.method.isNotEmpty) r.method,
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12, color: CwColors.muted),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatRm(r.kind == ReceiptKind.payment ? r.amountSen : -r.amountSen),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: r.kind == ReceiptKind.payment ? CwColors.ink : CwColors.successDark,
                        ),
                      ),
                    ]),
                  ),
              ]),
            ],
            const SizedBox(height: 16),
            const _Note('Receipts are also emailed to the person who paid. Sample amounts.'),
          ]);
        },
      ),
    ]);
  }
}

/// 27 · Saved places
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(currentUserProvider).value?.savedPlaces ?? const <SavedPlace>[];
    Future<void> save(List<SavedPlace> next) => _update(ref, {'savedPlaces': [for (final p in next) p.toMap()]});
    const tones = [
      (CwColors.lilac, CwColors.primaryDark),
      (CwColors.successSoft, Color(0xFF1D6B45)),
      (CwColors.amberSoft, CwColors.amber),
    ];
    Widget placeRow({required String icon, required (Color, Color) tone, required String title, required String sub, VoidCallback? onEdit}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: tone.$1, borderRadius: BorderRadius.circular(12)),
              child: Center(child: CwIcon(icon, size: 20, strokeWidth: 2.2, color: tone.$2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 12, height: 1.4, color: CwColors.muted)),
              ]),
            ),
            if (onEdit != null)
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(foregroundColor: CwColors.primary, minimumSize: const Size(44, 44)),
                child: const Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ),
          ]),
        );

    return _SubPage(title: 'Saved places', children: [
      const _Label('Pickup places'),
      if (places.isEmpty)
        const _Note('Save your home so pickups and medicine deliveries are one tap.')
      else
        ListCard(children: [
          for (var i = 0; i < places.length; i++)
            placeRow(
              icon: places[i].label.toLowerCase() == 'home' ? CwIcons.home : CwIcons.pinAlt,
              tone: tones[i % tones.length],
              title: places[i].label,
              sub: places[i].address,
              onEdit: () => showCwSheet<void>(
                context,
                builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(places[i].label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(places[i].address, style: const TextStyle(fontSize: 13, color: CwColors.muted)),
                  const SizedBox(height: 16),
                  BigButton(
                    label: 'Remove this place',
                    color: CwColors.pink,
                    onPressed: () {
                      save([for (var j = 0; j < places.length; j++) if (j != i) places[j]]);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  LinkButton(label: 'Keep', color: CwColors.muted, onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
            ),
        ]),
      const _Label('Hospitals and clinics'),
      ListCard(children: [
        for (final h in hospitals)
          placeRow(icon: CwIcons.hospital, tone: (CwColors.tealSoft, CwColors.tealDark), title: h.name, sub: h.area),
      ]),
      const _Note('The first pickup place is used for medicine deliveries.'),
      _DashedButton(
        label: '+ Add a place',
        onTap: () async {
          final p = await showCwSheet<SavedPlace>(context, builder: (_) => const _AddPlaceSheet());
          if (p != null) save([...places, p]);
        },
      ),
    ]);
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
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Add a place', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        LabeledField(label: 'Name', controller: _label),
        const SizedBox(height: 12),
        LabeledField(label: 'Address', controller: _address, hint: 'e.g. 12, Jalan Elmina Lakeside', onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        const Text('Nearest area (used for distance)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in pickupPoints) CwChip(label: p.area == 'Elmina' ? p.name : p.area, selected: _near == p, onTap: () => setState(() => _near = p)),
        ]),
        const SizedBox(height: 16),
        BigButton(
          label: 'Save place',
          onPressed: _address.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, SavedPlace(label: _label.text.trim(), address: _address.text.trim(), lat: _near.lat, lng: _near.lng)),
        ),
      ]);
}

Widget _switchRow({Key? key, required String label, required String sub, required bool value, required ValueChanged<bool> onChanged}) => Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12, height: 1.4, color: CwColors.muted)),
          ]),
        ),
        const SizedBox(width: 12),
        CwSwitch(key: key, value: value, label: label, onChanged: onChanged),
      ]),
    );

/// 28 · Notification settings
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(currentUserProvider).value?.settings ?? const UserSettings();
    Widget toggle(String key, String label, String sub, bool value) => _switchRow(
          key: ValueKey('notif-$key'),
          label: label,
          sub: sub,
          value: value,
          onChanged: (v) => _update(ref, {'settings.notif.$key': v}),
        );
    return _SubPage(title: 'Notifications', children: [
      const _Label('Send me'),
      ListCard(children: [
        toggle('visitUpdates', 'Visit updates', 'Pickup, arrival, with the doctor, ride home', s.visitUpdates),
        toggle('reminders', 'Visit reminders', 'The evening before each visit', s.reminders),
        toggle('promos', 'Health events', 'Screenings and vaccinations near you', s.promos),
      ]),
      const _Note('Safety alerts, like a change of helper or a cancelled ride, are always sent.'),
    ]);
  }
}

/// 29 · Language and text size
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(currentUserProvider).value?.settings ?? const UserSettings();
    const langs = [('English', 'English'), ('Bahasa Melayu', 'Malay'), ('中文', 'Chinese (Simplified)'), ('தமிழ்', 'Tamil')];
    return _SubPage(title: 'Language and text size', children: [
      const _Label('App language'),
      ListCard(children: [
        for (final (name, sub) in langs)
          Semantics(
            selected: s.language == name,
            button: true,
            child: InkWell(
              onTap: () => _update(ref, {'settings.language': name}),
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(sub, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                    ]),
                  ),
                  RadioDot(on: s.language == name),
                ]),
              ),
            ),
          ),
      ]),
      const _Note('Screens are in English in this version; your choice is saved for when translations arrive.'),
      const _Label('Text size'),
      Row(children: [
        for (var i = 0; i < textSizes.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: SelectCard(
              on: s.textScale == textSizes[i].$2,
              onTap: () => _update(ref, {'settings.textScale': textSizes[i].$2}),
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 80,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Aa', textScaler: TextScaler.noScaling, style: TextStyle(fontSize: [15.0, 18.0, 22.0][i], fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(textSizes[i].$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ],
      ]),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(16)),
        child: const Text.rich(TextSpan(text: 'Preview: ', style: TextStyle(fontSize: 13, color: CwColors.muted), children: [
          TextSpan(text: 'Ride home is 5 min away', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CwColors.ink)),
        ])),
      ),
    ]);
  }
}

/// 30 · Privacy
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void info(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Widget infoRow(String title, String sub) => Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 12, height: 1.4, color: CwColors.muted)),
              ]),
            ),
          ]),
        );
    Widget actionRow(String title, String sub, String action, Color color, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color == CwColors.primary ? CwColors.ink : color)),
                  Text(sub, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                ]),
              ),
              Text(action, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            ]),
          ),
        );
    return _SubPage(title: 'Privacy', children: [
      const _Label('Sharing'),
      ListCard(children: [
        infoRow('Patient profile to assigned helper only', 'Helpers see medical notes only for their own visit. Set per patient in their profile.'),
        infoRow('Show initials to co-riders', 'Neighbours in a shared ride see only initials and the shared destination.'),
      ]),
      const _Label('Your data'),
      ListCard(children: [
        actionRow('Request a copy of my data', 'Sent to your email within 7 days', 'Request', CwColors.primary,
            () => info("We'll email a copy of your data within 7 days.")),
      ]),
      const _Note("CareWay follows Malaysia's Personal Data Protection Act 2010."),
    ]);
  }
}
