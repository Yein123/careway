import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/cw_top_bar.dart';
import '../../data/api.dart';
import '../../data/models/booking.dart' show Rating;
import '../../data/models/delivery.dart';
import '../../data/models/firestore_utils.dart' show initialsOf;
import '../../data/providers.dart';
import '../booking/confirmed_screen.dart' show bookingRef;
import '../booking/payment_screen.dart';
import '../visits/live_visit_screen.dart' show callNumber;

const deliveryRatingTags = ['On time', 'Friendly', 'Medicine checked', 'Kept me updated', 'Careful handover', 'Easy to book'];
const deliveryLowRatingTags = ['Late', 'Hard to reach', 'Wrong item', 'Few updates', 'Rushed handover', 'Fee too high'];
const _ratingWords = ['', 'Poor', 'Not great', 'Okay', 'Good', 'Excellent'];

const _blue = CwColors.deliveryBlue;
const _green = CwColors.successDark;
const _gold = Color(0xFFB07A10);

String _first(String name) => name.split(' ').first;

/// Primary blue action (56 px, radius 16) used across the delivery screens.
class _BlueButton extends StatelessWidget {
  const _BlueButton({required this.label, this.onPressed, this.loading = false, this.leading});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: CwColors.white,
            disabledBackgroundColor: loading ? _blue : const Color(0xFFEFECF6),
            disabledForegroundColor: loading ? CwColors.white : CwColors.muted,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontFamily: cwFont, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: CwColors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ]),
        ),
      );
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onPressed, this.color = _blue, this.height = 48});
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontFamily: cwFont, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          child: Text(label),
        ),
      );
}

/// Header row: back, title + subtitle, optional trailing pill.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle, this.trailing, this.onBack});
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(children: [
        SquareIconButton(svg: CwIcons.back, label: 'Back', onTap: onBack ?? () => context.canPop() ? context.pop() : context.go('/home')),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CwColors.muted)),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ]);
}

/// Screen shell: surface background, 20 px padding, scrolling column.
class _Screen extends StatelessWidget {
  const _Screen({required this.children, this.gap = 14, this.fill = false});
  final List<Widget> children;
  final double gap;

  /// Lets the last child sit at the bottom (margin-top: auto in the design).
  final bool fill;

  Widget get column => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0 && !(children[i] is Spacer || children[i - 1] is Spacer)) SizedBox(height: gap),
          children[i],
        ],
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: CwColors.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: fill ? c.maxHeight - 40 : 0),
                child: fill ? IntrinsicHeight(child: column) : column,
              ),
            ),
          ),
        ),
      );
}

/// 32–34 · Medicine delivery after the request: finding a helper, pay,
/// booked, live progress and delivered — driven by the live status.
class DeliveryStatusScreen extends ConsumerWidget {
  const DeliveryStatusScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(deliveryProvider(deliveryId));
    return d.when(
      loading: () => const Scaffold(backgroundColor: CwColors.surface, body: Center(child: CircularProgressIndicator())),
      error: (_, _) => CwPage(
        title: 'Medicine delivery',
        children: [AsyncView<MedDelivery?>(value: d, onRetry: () => ref.invalidate(deliveryProvider(deliveryId)), data: (_) => const SizedBox())],
      ),
      data: (x) => x == null
          ? const CwPage(title: 'Medicine delivery', children: [EmptyState(icon: Icons.search_off, title: 'Delivery not found')])
          : switch (x.status) {
              DeliveryStatus.pendingCaregiver || DeliveryStatus.awaitingPayment => _BeforePayment(x),
              DeliveryStatus.notMatched || DeliveryStatus.expired || DeliveryStatus.cancelled => _Closed(x),
              DeliveryStatus.booked => _Booked(x),
              _ => _Progress(x),
            },
    );
  }
}

class _BeforePayment extends ConsumerStatefulWidget {
  const _BeforePayment(this.d);
  final MedDelivery d;

  @override
  ConsumerState<_BeforePayment> createState() => _BeforePaymentState();
}

class _BeforePaymentState extends ConsumerState<_BeforePayment> {
  String _method = 'fpx';
  bool _busy = false;

  Future<void> _pay() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(careWayApiProvider).payDelivery(widget.d.id, _method);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final waiting = d.status == DeliveryStatus.pendingCaregiver;
    return _Screen(fill: true, children: [
      _Header(title: 'Medicine delivery', subtitle: "${_first(d.patientName)}'s medicine · ${bookingRef(d.id)}"),
      _SummaryCard(d, rows: [
        ('Pharmacy', d.pharmacyName),
        ('Pickup window', '${d.date == null ? '' : '${dayLabel(d.date!)} · '}${d.window}'),
        ('Deliver to', d.deliverTo),
        ('Delivery fee', formatRm(d.totalSen)),
      ]),
      if (waiting)
        _NowCard(
          title: d.offerCaregiverName == null ? 'Finding a helper' : 'Waiting for ${d.offerCaregiverName} to accept',
          text: d.offerExpiresAt == null
              ? "We're asking helpers near you. You won't be charged until one accepts."
              : "The request expires at ${timeLabel(d.offerExpiresAt!)}. You won't be charged until a helper accepts.",
        )
      else ...[
        _NowCard(title: '${d.caregiverName ?? 'A helper'} accepted', text: 'Pay to confirm the delivery.'),
        const Text('Pay with', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        PaymentMethodPicker(selected: _method, onPick: (m) => setState(() => _method = m), accent: _blue),
      ],
      const Spacer(),
      if (!waiting) _BlueButton(label: 'Pay ${formatRm(d.totalSen)}', loading: _busy, onPressed: _pay),
    ]);
  }
}

class _Closed extends StatelessWidget {
  const _Closed(this.d);
  final MedDelivery d;

  @override
  Widget build(BuildContext context) => _Screen(fill: true, children: [
        _Header(title: 'Medicine delivery', subtitle: "${_first(d.patientName)}'s medicine · ${bookingRef(d.id)}"),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Text(d.status == DeliveryStatus.notMatched ? 'No helper available this time' : 'This delivery is closed',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Nothing has been charged.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.5, color: CwColors.muted)),
          ]),
        ),
        const Spacer(),
        _BlueButton(label: 'Try another time', onPressed: () => context.go('/delivery/new')),
      ]);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.d, {required this.rows, this.paid = false});
  final MedDelivery d;
  final List<(String, String)> rows;
  final bool paid;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: Color(0xFFEFECF6)))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rows[i].$1, style: const TextStyle(fontSize: 14, color: CwColors.muted)),
                const SizedBox(width: 12),
                Expanded(
                  child: i == rows.length - 1 && paid
                      ? Text.rich(
                          TextSpan(text: rows[i].$2, style: const TextStyle(fontWeight: FontWeight.w800, color: _blue), children: [
                            TextSpan(text: ' · ${methodShort(d.payment?.method ?? 'fpx')}', style: const TextStyle(fontWeight: FontWeight.w600, color: CwColors.muted)),
                          ]),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 14),
                        )
                      : Text(rows[i].$2, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
        ]),
      );
}

class _NowCard extends StatelessWidget {
  const _NowCard({required this.title, required this.text, this.map});
  final String title;
  final String text;
  final Widget? map;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('NOW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xD9FFFFFF))),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: CwColors.white)),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xF2FFFFFF))),
          if (map != null) ...[const SizedBox(height: 12), map!],
        ]),
      );
}

/// 32 · Delivery booked (MedBooked.dc.html)
class _Booked extends StatelessWidget {
  const _Booked(this.d);
  final MedDelivery d;

  @override
  Widget build(BuildContext context) => _Screen(gap: 16, fill: true, children: [
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: CwColors.deliverySoft, shape: BoxShape.circle),
              child: Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                  child: const Center(child: CwIcon(CwIcons.check, size: 34, strokeWidth: 3, color: CwColors.white)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: CwColors.tealSoft, borderRadius: BorderRadius.circular(8)),
              child: const Text('Payment successful', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: CwColors.tealDark)),
            ),
            const SizedBox(height: 10),
            const Text('Delivery booked', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              "${d.caregiverName ?? 'Your helper'} collects the documents between ${d.window} and delivers ${_first(d.patientName)}'s medicine to your doorstep.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5, color: CwColors.muted),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(10)),
              child: Text('Booking ID ${bookingRef(d.id)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _blue)),
            ),
          ]),
        ),
        _SummaryCard(d, paid: true, rows: [
          ('Patient', d.patientName),
          ('Pharmacy', d.pharmacyName),
          ('Pickup window', d.window),
          ('Amount paid', formatRm(d.totalSen)),
        ]),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _BlueButton(label: 'View delivery progress', onPressed: () => context.push('/delivery/${d.id}/live')),
          const SizedBox(height: 10),
          _LinkButton(label: 'Back to home', color: CwColors.primaryDark, onPressed: () => context.go('/home')),
        ]),
      ]);
}

const _stepSubs = {
  'booked': 'Payment received',
  'collecting': 'IC copy, letter and appointment card',
  'collected': 'Checked against the prescription',
  'on_the_way': 'Heading to your doorstep',
  'delivered': 'Handed over at your door',
};

const _feedText = {
  'collecting': 'Collecting the IC copy, letter and appointment card from your door.',
  'at_pharmacy': 'At the pharmacy, waiting for the medicine.',
  'collected': 'Medicine collected and checked against the prescription.',
  'on_the_way': 'On the way to your doorstep.',
  'delivered': 'Delivered to your doorstep.',
};

/// 33 · Live progress and 34 · Delivered (DeliveryLive / DeliveryDone).
class _Progress extends ConsumerWidget {
  const _Progress(this.d);
  final MedDelivery d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = d.status == DeliveryStatus.delivered;
    final idx = deliveryStageKeys.indexOf(d.status.wire);
    final helper = d.caregiverName ?? 'Your helper';
    final helperFirst = _first(helper);
    final first = _first(d.patientName);
    final now = switch (d.status.wire) {
      'collecting' => ('Documents collected', '$helperFirst is collecting the documents and will drive to the pharmacy.'),
      'at_pharmacy' => ('Waiting at the pharmacy', "$helperFirst is in the pharmacy queue for $first's medicine."),
      'collected' => ('Medicine collected', '$helperFirst checked the medicine against the prescription.'),
      'on_the_way' => ('On the way to you', '$helperFirst is heading to your doorstep now.'),
      'delivered' => ('Delivered', "$first's medicine was handed over at the door."),
      _ => ('Booking confirmed', '$helperFirst will come for the documents in your pickup window.'),
    };
    const positions = [(30.0, 50.0), (120.0, 34.0), (282.0, 38.0), (282.0, 38.0), (160.0, 42.0), (30.0, 50.0)];
    final pos = positions[idx.clamp(0, positions.length - 1)];
    DateTime? at(String key) => d.steps.where((s) => s.key == key).firstOrNull?.at ?? (key == 'booked' ? d.payment?.paidAt : null);
    final feed = [
      for (final s in d.steps.reversed)
        if (_feedText.containsKey(s.key)) (timeLabel(s.at), _feedText[s.key]!),
    ];

    return _Screen(children: [
      _Header(
        title: 'Delivery progress',
        subtitle: "$first's medicine · ${bookingRef(d.id)}",
        onBack: () => context.go('/home'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFDDF5EC), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(done ? 'Done' : 'Live', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _green)),
          ]),
        ),
      ),
      _NowCard(
        title: now.$1,
        text: now.$2,
        map: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 70,
              color: const Color(0x1FFFFFFF),
              child: SvgPicture.string(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 70">'
                '<path d="M30 50 C 90 10, 150 60, 200 30 S 280 20, 290 40" fill="none" stroke="#FFFFFF" stroke-opacity="0.45" stroke-width="4" stroke-linecap="round" stroke-dasharray="2 8"/>'
                '<circle cx="30" cy="50" r="9" fill="#FFFFFF"/>'
                '<path d="M26 51l4-4 4 4M27 50v4h6v-4" fill="none" stroke="#2F64A8" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>'
                '<rect x="280" y="30" width="20" height="20" rx="5" fill="#FFFFFF"/>'
                '<path d="M290 34v12M284 40h12" stroke="#2F64A8" stroke-width="2.4" stroke-linecap="round"/>'
                '<circle cx="${pos.$1}" cy="${pos.$2}" r="8" fill="#F5B740" stroke="#FFFFFF" stroke-width="3"/></svg>',
                fit: BoxFit.contain,
                semanticsLabel: 'Route between your doorstep and ${d.pharmacyName}, helper ${now.$1.toLowerCase()}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: Text('Your doorstep', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xE6FFFFFF)))),
            Flexible(
              child: Text(d.pharmacyName,
                  textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xE6FFFFFF))),
            ),
          ]),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          CircleAvatarText(initialsOf(helper), size: 44, tone: (CwColors.tealSoft, CwColors.teal), fontSize: 15),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(helper, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Your helper${(d.caregiverPhone ?? '').isEmpty ? '' : ' · ${d.caregiverPhone}'}', style: const TextStyle(fontSize: 12, color: CwColors.muted)),
            ]),
          ),
          if ((d.caregiverPhone ?? '').isNotEmpty)
            Semantics(
              button: true,
              label: 'Call $helperFirst',
              excludeSemantics: true,
              child: Material(
                color: _blue,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => callNumber(context, d.caregiverPhone!),
                  child: const SizedBox(width: 46, height: 46, child: Center(child: CwIcon(CwIcons.phone, size: 20, strokeWidth: 2.2, color: CwColors.white))),
                ),
              ),
            ),
        ]),
      ),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Steps', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (var i = 0; i < deliveryStageKeys.length; i++)
            _StageRow(
              title: deliveryStageLabels[deliveryStageKeys[i]]!,
              sub: deliveryStageKeys[i] == 'at_pharmacy' ? d.pharmacyName : (_stepSubs[deliveryStageKeys[i]] ?? ''),
              time: at(deliveryStageKeys[i]) == null || i > idx ? '' : timeLabel(at(deliveryStageKeys[i])!),
              doneStep: i < idx || done,
              current: i == idx && !done,
              last: i == deliveryStageKeys.length - 1,
              lineDone: i < idx,
            ),
        ]),
      ),
      if (feed.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Live updates', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          for (final f in feed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(helper, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CwColors.muted))),
                    Text(f.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CwColors.muted)),
                  ]),
                  const SizedBox(height: 3),
                  Text(f.$2, style: const TextStyle(fontSize: 13, height: 1.4)),
                ]),
              ),
            ),
        ]),
      if (done)
        d.rating == null
            ? _BlueButton(
                label: 'Rate this delivery',
                leading: const CwIcon(CwIcons.star, size: 20, strokeWidth: 0, color: Color(0x00000000), fill: CwColors.star),
                onPressed: () => context.push('/delivery/${d.id}/rate'),
              )
            : Text('You rated ${d.rating!.stars} ★', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CwColors.muted)),
    ]);
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.title,
    required this.sub,
    required this.time,
    required this.doneStep,
    required this.current,
    required this.last,
    required this.lineDone,
  });
  final String title;
  final String sub;
  final String time;
  final bool doneStep;
  final bool current;
  final bool last;
  final bool lineDone;

  @override
  Widget build(BuildContext context) {
    final color = doneStep ? _green : (current ? _blue : const Color(0xFFD9D6E3));
    Widget dot = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: doneStep ? const Center(child: CwIcon(CwIcons.check, size: 12, strokeWidth: 3.6, color: CwColors.white)) : null,
    );
    if (current) dot = _Pulse(child: dot);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 24,
          child: Column(children: [
            dot,
            if (!last) Expanded(child: Container(width: 2, constraints: const BoxConstraints(minHeight: 14), color: lineDone ? _green : CwColors.line)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: current ? FontWeight.w800 : (doneStep ? FontWeight.w700 : FontWeight.w600),
                        color: current ? _blue : (doneStep ? CwColors.ink : const Color(0xFF9A96AD)),
                      )),
                  const SizedBox(height: 1),
                  Text(sub, style: const TextStyle(fontSize: 11, color: CwColors.muted)),
                ]),
              ),
              const SizedBox(width: 10),
              Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CwColors.muted)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Pulsing ring around the current step (the design's cw-live animation).
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = (_c.value / 0.7).clamp(0.0, 1.0);
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.5 * (1 - t)), spreadRadius: 7 * t)],
            ),
            child: child,
          );
        },
        child: widget.child,
      );
}

/// 35 · Rate (stars), step 1 of 2 (DelRate.dc.html)
class DeliveryRateScreen extends ConsumerStatefulWidget {
  const DeliveryRateScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  ConsumerState<DeliveryRateScreen> createState() => _DeliveryRateScreenState();
}

class _DeliveryRateScreenState extends ConsumerState<DeliveryRateScreen> {
  int _stars = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(deliveryProvider(widget.deliveryId)).value;
    final helper = d?.caregiverName ?? 'Your helper';
    final deliveredAt = d?.steps.where((s) => s.key == 'delivered').firstOrNull?.at;
    return _Screen(gap: 16, fill: true, children: [
      const _Header(title: 'Rate this delivery', subtitle: 'Step 1 of 2 · Stars'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          CircleAvatarText(initialsOf(helper), size: 52, tone: (CwColors.tealSoft, CwColors.teal), fontSize: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(helper, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text("Delivered ${d == null ? '' : _first(d.patientName)}'s medicine${deliveredAt == null ? '' : ' · ${timeLabel(deliveredAt)}'}",
                  style: const TextStyle(fontSize: 12, color: CwColors.muted)),
            ]),
          ),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Text('How was the delivery?', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              Padding(
                padding: EdgeInsets.only(left: i == 1 ? 0 : 4),
                child: Semantics(
                  button: true,
                  selected: i <= _stars,
                  label: '$i star${i == 1 ? '' : 's'}',
                  excludeSemantics: true,
                  child: InkResponse(
                    key: ValueKey('star-$i'),
                    radius: 26,
                    onTap: () => setState(() => _stars = i),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Center(
                        child: CwIcon(
                          CwIcons.star,
                          size: 38,
                          strokeWidth: 1.6,
                          fill: i <= _stars ? CwColors.star : CwColors.white,
                          color: i <= _stars ? const Color(0xFFE0A020) : const Color(0xFFC9C4D9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 20,
            child: Text(_stars == 0 ? 'Tap a star' : _ratingWords[_stars], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _gold)),
          ),
        ]),
      ),
      const Text('Ratings help us keep helpers on time and medicine handled with care.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.5, color: CwColors.muted)),
      const Spacer(),
      _BlueButton(label: 'Next', onPressed: _stars == 0 ? null : () => context.push('/delivery/${widget.deliveryId}/feedback?stars=$_stars')),
      _LinkButton(label: 'Skip for now', color: CwColors.muted, height: 44, onPressed: () => context.go('/home')),
    ]);
  }
}

/// 36 · Feedback, step 2 of 2 (DelFeedback.dc.html)
class DeliveryFeedbackScreen extends ConsumerStatefulWidget {
  const DeliveryFeedbackScreen({super.key, required this.deliveryId, required this.stars});
  final String deliveryId;
  final int stars;

  @override
  ConsumerState<DeliveryFeedbackScreen> createState() => _DeliveryFeedbackScreenState();
}

class _DeliveryFeedbackScreenState extends ConsumerState<DeliveryFeedbackScreen> {
  final Set<String> _tags = {};
  final _text = TextEditingController();
  bool _busy = false;

  int get _stars => widget.stars.clamp(1, 5);
  List<String> get _list => _stars >= 4 ? deliveryRatingTags : deliveryLowRatingTags;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(deliveryRepoProvider).rate(
            widget.deliveryId,
            Rating(stars: _stars, tags: [for (final t in _list) if (_tags.contains(t)) t], text: _text.text.trim()),
          );
      router.go('/delivery/${widget.deliveryId}/thanks');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final helper = ref.watch(deliveryProvider(widget.deliveryId)).value?.caregiverName?.split(' ').first ?? 'The helper';
    return _Screen(gap: 16, fill: true, children: [
      const _Header(title: 'Tell us more', subtitle: 'Step 2 of 2 · Feedback'),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your rating', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CwColors.muted)),
              const SizedBox(height: 2),
              Text(_ratingWords[_stars], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
          ),
          Semantics(
            label: '$_stars out of 5 stars',
            excludeSemantics: true,
            child: Text('★' * _stars + '☆' * (5 - _stars), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2, color: _gold)),
          ),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_stars >= 4 ? 'What went well?' : 'What could be better?', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in _list)
            Semantics(
              button: true,
              selected: _tags.contains(t),
              child: Material(
                color: _tags.contains(t) ? _blue : CwColors.white,
                shape: StadiumBorder(side: BorderSide(color: _tags.contains(t) ? _blue : CwColors.line, width: 2)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => setState(() => _tags.contains(t) ? _tags.remove(t) : _tags.add(t)),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      widthFactor: 1,
                      child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _tags.contains(t) ? CwColors.white : CwColors.ink)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text.rich(TextSpan(text: 'Anything else? ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800), children: [
          TextSpan(text: 'Optional', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CwColors.muted)),
        ])),
        const SizedBox(height: 8),
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: 4,
          style: const TextStyle(fontSize: 14, color: CwColors.ink),
          decoration: InputDecoration(
            hintText: 'e.g. $helper called before arriving, very helpful.',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]),
      const Spacer(),
      _BlueButton(label: 'Send feedback', loading: _busy, onPressed: _send),
    ]);
  }
}

/// 37 · Thank you (DelThanks.dc.html)
class DeliveryThanksScreen extends ConsumerWidget {
  const DeliveryThanksScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(deliveryProvider(deliveryId)).value;
    final first = d == null ? 'your family' : _first(d.patientName);
    return _Screen(gap: 16, fill: true, children: [
      Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(color: Color(0xFFFDF1D6), shape: BoxShape.circle),
            child: const Center(child: CwIcon(CwIcons.star, size: 56, strokeWidth: 1.4, fill: CwColors.star, color: Color(0xFFE0A020))),
          ),
          const SizedBox(height: 18),
          const Text('Thank you!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              "Your ${d?.rating?.stars ?? 5}-star rating and feedback have been sent. We'll share it with ${d?.caregiverName?.split(' ').first ?? 'your helper'} and our care team.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5, color: CwColors.muted),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Next refill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CwColors.muted)),
              const SizedBox(height: 4),
              Text("Book $first's next medicine delivery in one tap.", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _BlueButton(label: 'Book next delivery', onPressed: () => context.go('/delivery/new')),
        const SizedBox(height: 10),
        _LinkButton(label: 'Back to home', onPressed: () => context.go('/home')),
      ]),
    ]);
  }
}
