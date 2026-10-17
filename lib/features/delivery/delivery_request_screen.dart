import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/places.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/step_label.dart';
import '../../data/api.dart';
import '../../data/models/family.dart';
import '../../data/providers.dart';
import '../../domain/pricing.dart';

/// Pickup windows: label and start (minutes after local midnight).
const deliveryWindows = [
  ('8:00 – 10:00 AM', 8 * 60),
  ('10:00 AM – 12:00 PM', 10 * 60),
  ('2:00 – 4:00 PM', 14 * 60),
  ('4:00 – 6:00 PM', 16 * 60),
];

/// 31 · Medicine delivery: request + fee (MedRun.dc.html). The fee is the
/// distance formula (spec §5); no AI is involved.
class DeliveryRequestScreen extends ConsumerStatefulWidget {
  const DeliveryRequestScreen({super.key});

  @override
  ConsumerState<DeliveryRequestScreen> createState() => _DeliveryRequestScreenState();
}

class _DeliveryRequestScreenState extends ConsumerState<DeliveryRequestScreen> {
  String? _patientId;
  String? _pharmacyId;
  int _window = 0;
  int _dayOffset = 1;
  bool _card = false, _ic = false, _letter = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider).value ?? const <Patient>[];
    final user = ref.watch(currentUserProvider).value;
    final now = ref.watch(clockProvider)().toLocal();
    final patient = patients.where((p) => p.id == _patientId).firstOrNull ?? patients.firstOrNull;
    final first = patient?.name.split(' ').first ?? 'the patient';
    final saved = user?.savedPlaces.firstOrNull;
    final homeLabel = saved == null ? pickupPoints.first.name : '${saved.label} · ${saved.address}';
    final homeLat = saved?.lat ?? pickupPoints.first.lat;
    final homeLng = saved?.lng ?? pickupPoints.first.lng;
    final pharmacy = pharmacies.where((p) => p.id == _pharmacyId).firstOrNull;
    final km = pharmacy == null ? null : routeKm(homeLat, homeLng, pharmacy.lat, pharmacy.lng);
    final fee = km == null ? null : deliveryFee(km);
    final ready = _card && _ic && _letter;
    final day = DateTime(now.year, now.month, now.day + _dayOffset);
    final windowStart = day.add(Duration(minutes: deliveryWindows[_window].$2));

    Future<void> submit() async {
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _busy = true);
      try {
        final id = await ref.read(careWayApiProvider).requestDelivery({
          'patientId': patient!.id,
          'pharmacyId': pharmacy!.id,
          'window': deliveryWindows[_window].$1,
          'windowStart': windowStart.toUtc().toIso8601String(),
          'docs': {'card': _card, 'ic': _ic, 'letter': _letter},
        });
        router.go('/delivery/$id');
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    final label = patient == null
        ? 'Add someone you care for first'
        : pharmacy == null
            ? 'Pick a pharmacy to continue'
            : !ready
                ? 'Tick all 3 documents to continue'
                : 'Find a helper';

    return CwPage(
      title: 'Medicine delivery',
      stepLabel: 'Repeat medicine · $first stays home',
      bottom: CwButton(
        label: label,
        color: CwColors.deliveryBlue,
        loading: _busy,
        onPressed: patient != null && pharmacy != null && ready ? submit : null,
      ),
      children: [
        if (patients.length > 1) ...[
          const SectionTitle('Who is it for?'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in patients)
              CwChip(label: p.name.split(' ').first, selected: patient?.id == p.id, onTap: () => setState(() => _patientId = p.id)),
          ]),
          const Gap(16),
        ],
        const SectionTitle('1. Pharmacy'),
        for (final p in pharmacies)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CwCard(
              selected: _pharmacyId == p.id,
              onTap: () => setState(() => _pharmacyId = p.id),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(_pharmacyId == p.id ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20, color: _pharmacyId == p.id ? CwColors.deliveryBlue : CwColors.muted),
                const SizedBox(width: 10),
                Expanded(child: Text(p.name, style: CwText.bodyBold)),
              ]),
            ),
          ),
        const Gap(14),
        const SectionTitle('2. Pickup time window'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var d = 1; d <= 5; d++)
            CwChip(
              label: d == 1 ? 'Tomorrow' : dayLabel(DateTime(now.year, now.month, now.day + d)),
              selected: _dayOffset == d,
              onTap: () => setState(() => _dayOffset = d),
            ),
        ]),
        const Gap(8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < deliveryWindows.length; i++)
            CwChip(label: deliveryWindows[i].$1, selected: _window == i, onTap: () => setState(() => _window = i)),
        ]),
        const Gap(6),
        Text('${dayLabel(day)} · the helper collects the documents from your door', style: CwText.small),
        const Gap(14),
        const SectionTitle('3. Deliver to'),
        CwCard(
          child: Row(children: [
            const Icon(Icons.home_outlined, color: CwColors.deliveryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Doorstep', style: CwText.small),
                Text(homeLabel, style: CwText.bodyBold),
              ]),
            ),
          ]),
        ),
        const Gap(14),
        const SectionTitle('4. Documents'),
        const Text("Tick each one when it's ready for the helper.", style: CwText.small),
        const Gap(6),
        CwCheckRow(
          checked: _card,
          onChanged: (v) => setState(() => _card = v),
          child: const _Doc('Appointment card or prescription slip', 'Shows the refill date.'),
        ),
        CwCheckRow(
          checked: _ic,
          onChanged: (v) => setState(() => _ic = v),
          child: _Doc("Copy of $first's IC", 'Front and back.'),
        ),
        CwCheckRow(
          checked: _letter,
          onChanged: (v) => setState(() => _letter = v),
          child: _Doc('Authorisation letter', 'Signed by $first, naming the CareWay helper.'),
        ),
        const Gap(14),
        CwCard(
          color: CwColors.deliverySoft,
          borderColor: CwColors.deliverySoft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Fee estimate', style: CwText.h3),
            const Text('Based on the route distance: home → pharmacy → home', style: CwText.small),
            const SizedBox(height: 8),
            if (fee == null)
              const Text('Pick a pharmacy to see the fee.', style: CwText.muted)
            else ...[
              KeyValueRow('Route', '$km km'),
              KeyValueRow('Base fee', formatRm(fee.baseSen)),
              KeyValueRow('Distance fee (RM 0.50/km)', formatRm(fee.distanceSen)),
              const Divider(),
              Row(children: [
                const Expanded(child: Text('Delivery fee', style: CwText.bodyBold)),
                Text(formatRm(fee.totalSen), style: CwText.h3),
              ]),
            ],
          ]),
        ),
        const Gap(8),
        const Text(
          'You pay only after a helper accepts. Free cancellation up to 24 hours before. Medicine is handed over with a signature. Sample prices.',
          style: CwText.small,
        ),
      ],
    );
  }
}

class _Doc extends StatelessWidget {
  const _Doc(this.title, this.sub);
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: CwText.bodyBold),
        Text(sub, style: CwText.small),
      ]);
}
