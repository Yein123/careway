import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/places.dart';
import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/cw_top_bar.dart';
import '../../data/api.dart';
import '../../data/models/family.dart';
import '../../data/providers.dart';
import '../../domain/pricing.dart';
import '../booking/payment_screen.dart' show methodName;

/// Pickup windows: label and start (minutes after local midnight).
const deliveryWindows = [
  ('8:00 – 10:00 AM', 8 * 60),
  ('10:00 AM – 12:00 PM', 10 * 60),
  ('2:00 – 4:00 PM', 14 * 60),
  ('4:00 – 6:00 PM', 16 * 60),
];

const _blue = CwColors.deliveryBlue;
const _blueTint = Color(0xFFEEF3FB);
const _blueLine = Color(0xFFD6E2F3);

/// 31 · Medicine delivery: request + fee (MedRun.dc.html). The fee is the
/// distance formula (spec §5); no AI is involved.
class DeliveryRequestScreen extends ConsumerStatefulWidget {
  const DeliveryRequestScreen({super.key});

  @override
  ConsumerState<DeliveryRequestScreen> createState() => _DeliveryRequestScreenState();
}

class _DeliveryRequestScreenState extends ConsumerState<DeliveryRequestScreen> {
  final _pharmText = TextEditingController();
  String? _patientId;
  String? _pharmacyId;
  int _window = 0;
  int _dayOffset = 1;
  bool _calced = false;
  final Map<String, bool> _docs = {'card': false, 'ic': false, 'letter': false};
  bool _template = false;
  bool _busy = false;

  @override
  void dispose() {
    _pharmText.dispose();
    super.dispose();
  }

  void _pickPharmacy(Place p) {
    _pharmText.text = p.name;
    setState(() {
      _pharmacyId = p.id;
      _calced = false;
    });
  }

  void _typed(String v) {
    final match = pharmacies.where((p) => p.name.toLowerCase() == v.trim().toLowerCase()).firstOrNull;
    setState(() {
      _pharmacyId = match?.id;
      _calced = false;
    });
  }

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
    final ready = _docs.values.every((v) => v);
    final day = DateTime(now.year, now.month, now.day + _dayOffset);
    final windowStart = day.add(Duration(minutes: deliveryWindows[_window].$2));
    final canSubmit = patient != null && pharmacy != null && _calced && ready;
    final method = user?.paymentMethods.firstOrNull?.type ?? 'fpx';

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
          'docs': _docs,
          'method': method,
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
            : !_calced
                ? 'Calculate the fee to continue'
                : !ready
                    ? 'Tick all 3 documents to continue'
                    : 'Pay ${formatRm(fee!.totalSen)}';

    const h = TextStyle(fontSize: 15, fontWeight: FontWeight.w800);
    const sub = TextStyle(fontSize: 12, color: CwColors.muted);

    return Scaffold(
      backgroundColor: CwColors.surface,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              children: [
                Row(children: [
                  SquareIconButton(
                    svg: CwIcons.back,
                    label: 'Back',
                    onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Medicine delivery', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Repeat medicine · $first stays home',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CwColors.muted)),
                    ]),
                  ),
                ]),
                if (patients.length > 1) ...[
                  const SizedBox(height: 14),
                  const Text("Who is it for?", style: h),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final p in patients)
                      _Pill(label: p.name.split(' ').first, on: patient?.id == p.id, onTap: () => setState(() => _patientId = p.id)),
                  ]),
                ],
                const SizedBox(height: 14),
                const Text('1. Pharmacy', style: h),
                const SizedBox(height: 8),
                TextField(
                  controller: _pharmText,
                  onChanged: _typed,
                  style: const TextStyle(fontSize: 14, color: CwColors.ink),
                  decoration: const InputDecoration(
                    hintText: 'Type a pharmacy, clinic or hospital',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Recent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CwColors.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final p in pharmacies) _Pill(label: p.name, on: _pharmacyId == p.id, recent: true, onTap: () => _pickPharmacy(p)),
                ]),
                const SizedBox(height: 14),
                const Text('2. Pickup time window', style: h),
                const SizedBox(height: 4),
                Text('${dayLabel(day)} · the helper collects the documents from your door', style: sub),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final d = i + 1;
                      return _Pill(
                        label: d == 1 ? 'Tomorrow' : dayLabel(DateTime(now.year, now.month, now.day + d)),
                        on: _dayOffset == d,
                        recent: true,
                        onTap: () => setState(() => _dayOffset = d),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 165 / 46,
                  children: [
                    for (var i = 0; i < deliveryWindows.length; i++)
                      _WindowChip(label: deliveryWindows[i].$1, on: _window == i, onTap: () => setState(() => _window = i)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('3. Deliver to', style: h),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CwColors.white,
                    border: Border.all(color: CwColors.line, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: _blueTint, borderRadius: BorderRadius.circular(10)),
                      child: const Center(
                        child: CwIcon('<path d="M3 11 12 4l9 7"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>',
                            size: 19, strokeWidth: 2.2, color: _blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Doorstep', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 1),
                        Text(homeLabel, style: sub),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                const Text('4. Documents', style: h),
                const SizedBox(height: 4),
                const Text("Tick each one when it's ready for the helper.", style: sub),
                const SizedBox(height: 8),
                for (final (id, name, note) in [
                  ('card', 'Appointment card or prescription slip', 'Shows the refill date.'),
                  ('ic', "Copy of $first's IC", 'Front and back.'),
                  ('letter', 'Authorisation letter', 'Signed by $first, naming the CareWay helper.'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DocRow(
                      key: ValueKey('doc-$id'),
                      title: name,
                      sub: note,
                      checked: _docs[id]!,
                      onTap: () => setState(() => _docs[id] = !_docs[id]!),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _template = true),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: CwColors.lilac,
                      foregroundColor: CwColors.primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontFamily: cwFont, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    child: Text(_template ? 'Template saved to your phone' : 'Download authorisation letter template'),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CwColors.white,
                    border: Border.all(color: _blueLine, width: 2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: CwColors.deliverySoft, borderRadius: BorderRadius.circular(10)),
                        child: const Center(
                          child: CwIcon(
                            '<path d="M12 3l1.8 4.7L18.5 9.5l-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8z"/><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/>',
                            size: 17,
                            strokeWidth: 2.2,
                            color: _blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Fee estimate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          SizedBox(height: 1),
                          Text('Based on the route distance', style: TextStyle(fontSize: 11, color: CwColors.muted)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: pharmacy == null ? null : () => setState(() => _calced = true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          disabledBackgroundColor: const Color(0xFFEFECF6),
                          disabledForegroundColor: CwColors.muted,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontFamily: cwFont, fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        child: Text(_calced ? 'Recalculate fee' : 'Calculate fee'),
                      ),
                    ),
                    if (_calced && fee != null) ...[
                      const SizedBox(height: 10),
                      _FeeRow('Route: home → pharmacy → home', '$km km'),
                      _FeeRow('Base fee', formatRm(fee.baseSen)),
                      _FeeRow('Distance fee', formatRm(fee.distanceSen)),
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 2),
                        child: Row(children: [
                          const Expanded(child: Text('Delivery fee', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                          Text(formatRm(fee.totalSen), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _blue)),
                        ]),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Free cancellation up to 24 hours before. Medicine is handed over with a signature. Sample prices.',
                  style: TextStyle(fontSize: 11, height: 1.45, color: CwColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            decoration: const BoxDecoration(
              color: CwColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: 58,
                child: FilledButton(
                  onPressed: canSubmit && !_busy ? submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    disabledBackgroundColor: _busy ? _blue : const Color(0xFFEFECF6),
                    disabledForegroundColor: _busy ? CwColors.white : CwColors.muted,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontFamily: cwFont, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: CwColors.white))
                      : Text(label),
                ),
              ),
              const SizedBox(height: 8),
              Text('Paying with ${methodName(method)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: CwColors.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.on, required this.onTap, this.recent = false});
  final String label;
  final bool on;
  final bool recent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = on ? _blue : (recent ? _blueTint : CwColors.white);
    final fg = on ? CwColors.white : (recent ? _blue : CwColors.ink);
    final border = on ? _blue : (recent ? _blueLine : CwColors.line);
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(widthFactor: 1, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg))),
          ),
        ),
      ),
    );
  }
}

class _WindowChip extends StatelessWidget {
  const _WindowChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        child: Material(
          color: on ? _blue : CwColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: on ? _blue : CwColors.line, width: 2)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: on ? CwColors.white : CwColors.ink)),
              ),
            ),
          ),
        ),
      );
}

class _DocRow extends StatelessWidget {
  const _DocRow({super.key, required this.title, required this.sub, required this.checked, required this.onTap});
  final String title;
  final String sub;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        checked: checked,
        child: Material(
          color: checked ? _blueTint : CwColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: checked ? _blue : CwColors.line, width: 2)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: checked ? _blue : CwColors.white,
                    border: Border.all(color: checked ? _blue : const Color(0xFFC9C4D9), width: 2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: checked ? const Center(child: CwIcon(CwIcons.check, size: 13, strokeWidth: 3.4, color: CwColors.white)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(sub, style: const TextStyle(fontSize: 11, height: 1.35, color: CwColors.muted)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _FeeRow extends StatelessWidget {
  const _FeeRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEFECF6)))),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: CwColors.muted))),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      );
}
