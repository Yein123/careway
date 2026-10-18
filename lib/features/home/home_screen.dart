import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/health_events.dart';
import '../../config/places.dart';
import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_sheet.dart';
import '../../core/widgets/cw_top_bar.dart';
import '../../core/widgets/safety_button.dart';
import '../../data/models/booking.dart';
import '../../data/models/family.dart';
import '../../data/models/firestore_utils.dart' show initialsOf;
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../../data/models/delivery.dart';
import '../booking/booking_draft.dart';
import '../delivery/delivery_list_screen.dart';
import '../visits/rate_sheet.dart';

String placeName(String hospitalId) {
  try {
    return placeById(hospitalId).name;
  } catch (_) {
    return hospitalId;
  }
}

String levelLabel(int level) => level == 1 ? 'Group' : 'Personal';

/// Badge colours for Group (lilac) and Personal (teal) visits.
(Color, Color) levelTone(int level) =>
    level == 1 ? (CwColors.lilac, CwColors.primaryDark) : (CwColors.tealSoft, CwColors.tealDark);

const _livePhrases = {
  'picked_up': 'is on the way',
  'registered': 'is at the hospital',
  'waiting_doctor': 'is waiting for the doctor',
  'with_doctor': 'is with the doctor',
  'pharmacy': 'is at the pharmacy',
  'ride_home': 'is on the way home',
  'home': 'is home safely',
};

/// 2 · Home (Home.dc.html)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final bookings = ref.watch(familyBookingsProvider).value ?? const <Booking>[];
    final patients = ref.watch(patientsProvider).value ?? const <Patient>[];
    final unread = (ref.watch(notificationsProvider).value ?? const []).where((n) => !n.read).length;
    final now = ref.watch(clockProvider)();

    final awaiting = bookings.where((b) => b.status == BookingStatus.awaitingPayment).toList();
    final pending = bookings.where((b) => b.status == BookingStatus.pendingCaregiver).toList();
    final live = bookings.where((b) => b.status == BookingStatus.inProgress).toList();
    final upcoming = bookings.where((b) => b.status == BookingStatus.confirmed && b.apptAt.isAfter(now)).toList()
      ..sort((a, b) => a.apptAt.compareTo(b.apptAt));
    final past = bookings.where((b) => b.status == BookingStatus.completed).toList()
      ..sort((a, b) => b.apptAt.compareTo(a.apptAt));
    final deliveries = ref.watch(familyDeliveriesProvider).value ?? const <MedDelivery>[];
    final deliveriesActive = deliveries.where(isDeliveryInProgress).toList();
    final deliveredLatest = deliveries.where((d) => d.status == DeliveryStatus.delivered).firstOrNull;

    final sections = <Widget>[
      // Greeting
      Row(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0xFFE4DCFB), shape: BoxShape.circle),
          child: Text(user?.initials ?? '?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hello, ${user?.firstName ?? 'there'}!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            if ((user?.area ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(children: [
                const CwIcon(CwIcons.pin, size: 14, strokeWidth: 2.4, color: CwColors.primary),
                const SizedBox(width: 4),
                Flexible(child: Text(user!.area, style: const TextStyle(fontSize: 13, color: CwColors.muted))),
              ]),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        SquareIconButton(
          svg: CwIcons.bell,
          size: 46,
          label: unread > 0 ? 'Notifications, $unread new' : 'Notifications',
          badge: unread,
          onTap: () => context.push('/notifications'),
        ),
      ]),
      for (final b in awaiting)
        _ActionBanner(
          title: 'Pay to confirm',
          body: "${b.caregiverName ?? 'Your caregiver'} accepted ${_first(b.patient.name)}'s visit on ${dayLabel(b.apptAt)}.",
          action: 'Pay',
          background: CwColors.amberSoft,
          border: const Color(0xFFF6D3B0),
          accent: CwColors.amber,
          onTap: () => context.push(b.level == 1 ? '/booking/${b.id}/package' : '/booking/${b.id}/pay'),
        ),
      for (final b in pending)
        _ActionBanner(
          title: 'Finding a caregiver',
          body: '${_first(b.patient.name)} · ${dayLabel(b.apptAt)}. You are not charged until someone accepts.',
          action: 'View',
          background: CwColors.white,
          border: CwColors.line,
          accent: CwColors.primaryDark,
          onTap: () => context.push('/booking/${b.id}/pending'),
        ),
      // Book a visit banner
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE4DCFB),
          border: Border.all(color: CwColors.lilacLine, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Doctor's visit coming up?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Helper + ride, no leave needed',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CwColors.primaryDark)),
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 42,
            child: FilledButton(
              onPressed: () => startBooking(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: CwColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontFamily: cwFont, fontSize: 14, fontWeight: FontWeight.w800),
              ),
              child: const Text('Book a visit'),
            ),
          ),
        ]),
      ),
      // Health events
      _Section(
        title: 'Health events near you',
        onSeeAll: () => _showAllEvents(context),
        child: _Bleed(
          children: [for (final e in healthEvents) _EventCard(e, onOpen: () => _showEvent(context, ref, e))],
        ),
      ),
      // Services
      _Section(
        title: 'Services',
        child: _Bleed(children: [
          _ServiceTile(CwIcons.group, 'Shared ride + guidance', 'Level 1', CwColors.primary,
              () => startBooking(context, ref, level: 1)),
          _ServiceTile(CwIcons.escort, 'One-to-one escort', 'Level 2', CwColors.teal,
              () => startBooking(context, ref, level: 2)),
          _ServiceTile(CwIcons.medicine, 'Medicine delivery', 'Fee by distance', CwColors.deliveryBlue,
              () => context.push('/delivery/new')),
          _ServiceTile(CwIcons.profile, 'Patient profiles',
              '${patients.length} family member${patients.length == 1 ? '' : 's'}', const Color(0xFFB35A12),
              () => context.go('/family')),
          _ServiceTile(CwIcons.shield, 'Help and safety', 'Emergency, support', CwColors.pink,
              () => showHelpSheet(context)),
        ]),
      ),
      if (live.isNotEmpty)
        _Section(
          title: 'Ongoing',
          child: Column(children: [
            for (final b in live) Padding(padding: const EdgeInsets.only(bottom: 12), child: _LiveCard(b)),
          ]),
        ),
      _Section(
        title: 'Upcoming',
        count: upcoming.length,
        onSeeAll: () => context.go('/visits'),
        child: upcoming.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
                child: const Text('No visits booked yet.', style: TextStyle(fontSize: 13, color: CwColors.muted)),
              )
            : Column(children: [
                for (final b in upcoming.take(2))
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: _UpcomingCard(b, now)),
              ]),
      ),
      if (deliveriesActive.isNotEmpty || deliveredLatest != null)
        _Section(
          title: 'Medicine delivery',
          count: deliveriesActive.length,
          onSeeAll: () => context.push('/deliveries'),
          child: deliveriesActive.isNotEmpty
              ? Column(children: [
                  for (final d in deliveriesActive)
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: DeliveryProgressCard(d)),
                ])
              : DeliveredRow(deliveredLatest!),
        ),
      if (patients.isNotEmpty)
        _Section(
          title: 'Family',
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < patients.length; i++)
              _FamilyChip(patients[i], personTone(i), () => context.push('/family/patient/${patients[i].id}')),
          ]),
        ),
      if (past.isNotEmpty)
        _Section(
          title: 'Past visits',
          child: Column(children: [
            for (final b in past.take(2))
              Padding(padding: const EdgeInsets.only(bottom: 12), child: _PastCard(b)),
          ]),
        ),
    ];

    return Scaffold(
      backgroundColor: CwColors.surface,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 22),
              sections[i],
            ],
          ]),
        ),
      ),
    );
  }
}

String _first(String name) => name.trim().split(RegExp(r'\s+')).first;

void _showEvent(BuildContext context, WidgetRef ref, HealthEvent e) => showCwSheet<void>(
      context,
      grabber: false,
      padding: EdgeInsets.zero,
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _EventPhoto(e, height: 180, child: Positioned(
          right: 14,
          top: 14,
          child: SheetCloseButton(label: 'Close event details', onPhoto: true, onTap: () => Navigator.pop(ctx)),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Tag(e.tag, background: CwColors.lilac, color: CwColors.primaryDark),
            const SizedBox(height: 12),
            Text(e.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final (k, v) in [('Where', e.where), ('When', e.when), ('Cost', e.cost)])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(TextSpan(
                  style: const TextStyle(fontSize: 13, color: Color(0xFF3D3955)),
                  children: [TextSpan(text: k, style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: ' · $v')],
                )),
              ),
            const SizedBox(height: 8),
            Text(e.description, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF3D3955))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SheetButton(
                label: 'Book a ride there',
                onPressed: () {
                  Navigator.pop(ctx);
                  startBooking(context, ref);
                },
              ),
            ),
          ]),
        ),
      ]),
    );

void _showAllEvents(BuildContext context) => showCwSheet<void>(
      context,
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Health events near you', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        for (final e in healthEvents)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _EventPhoto(e, height: 64, width: 64),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${e.tag} · ${e.where}', style: const TextStyle(fontSize: 12, height: 1.4, color: CwColors.muted)),
                ]),
              ),
            ]),
          ),
      ]),
    );

/// Horizontal row that scrolls past the right page padding, as in the design.
class _Bleed extends StatelessWidget {
  const _Bleed({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Transform.translate(
        offset: Offset.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(right: 20),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 12), children[i]],
            ]),
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.onSeeAll, this.count});
  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;
  final int? count;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text.rich(TextSpan(
              text: title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              children: [
                if (count != null && count! > 0)
                  TextSpan(text: ' ($count)', style: const TextStyle(color: CwColors.muted, fontWeight: FontWeight.w600)),
              ],
            )),
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('See all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CwColors.primary)),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        child,
      ]);
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.background, required this.color});
  final String text;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );
}

class _EventPhoto extends StatelessWidget {
  const _EventPhoto(this.e, {required this.height, this.width, this.child});
  final HealthEvent e;
  final double height;
  final double? width;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: width,
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: e.background),
          Image.asset(e.image, fit: BoxFit.cover, alignment: e.alignment, semanticLabel: e.alt),
          ?child,
        ]),
      );
}

class _EventCard extends StatelessWidget {
  const _EventCard(this.e, {required this.onOpen});
  final HealthEvent e;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Container(
        width: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _EventPhoto(e, height: 130, child: Positioned(
            left: 12,
            top: 12,
            child: _Tag(e.tag, background: const Color(0xEBFFFFFF), color: CwColors.ink),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${e.where} · ${e.when}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.4, color: CwColors.muted)),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: TextButton(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                    backgroundColor: CwColors.lilac,
                    foregroundColor: CwColors.primaryDark,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontFamily: cwFont, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Show details'),
                ),
              ),
            ]),
          ),
        ]),
      );
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile(this.icon, this.title, this.sub, this.color, this.onTap);
  final String icon;
  final String title;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: 132,
            height: 116,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              CwIcon(icon, size: 28, color: CwColors.white),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 2, style: const TextStyle(fontSize: 14, height: 1.25, fontWeight: FontWeight.w800, color: CwColors.white)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xE6FFFFFF))),
              ]),
            ]),
          ),
        ),
      );
}

class _ActionBanner extends StatelessWidget {
  const _ActionBanner({
    required this.title,
    required this.body,
    required this.action,
    required this.background,
    required this.border,
    required this.accent,
    required this.onTap,
  });
  final String title;
  final String body;
  final String action;
  final Color background;
  final Color border;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accent)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 12, height: 1.4, color: CwColors.muted)),
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 42,
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: CwColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontFamily: cwFont, fontSize: 14, fontWeight: FontWeight.w800),
              ),
              child: Text(action),
            ),
          ),
        ]),
      );
}

class _LiveCard extends StatelessWidget {
  const _LiveCard(this.b);
  final Booking b;

  @override
  Widget build(BuildContext context) {
    final last = b.steps.isEmpty ? null : b.steps.last;
    final phrase = last == null ? 'is getting ready' : (_livePhrases[last.key] ?? 'is on a visit');
    const white90 = Color(0xE6FFFFFF);
    return Material(
      color: CwColors.successDark,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/booking/${b.id}/live'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF7BE3B4),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x4D7BE3B4), spreadRadius: 4)],
                ),
              ),
              const SizedBox(width: 8),
              const Text('LIVE NOW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: CwColors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(8)),
                child: Text(levelLabel(b.level), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: CwColors.white)),
              ),
            ]),
            const SizedBox(height: 10),
            Text('${_first(b.patient.name)} $phrase',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CwColors.white)),
            const SizedBox(height: 2),
            Text(
              [placeName(b.hospitalId), if (b.caregiverName != null) b.caregiverName!, if (b.level == 1) 'ride home when ready'].join(' · '),
              style: const TextStyle(fontSize: 13, color: white90),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(last == null ? '' : '${stepLabels[last.key] ?? ''} ${timeLabel(last.at)}',
                    style: const TextStyle(fontSize: 13, color: white90)),
              ),
              const Text('Track ›', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CwColors.white)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard(this.b, this.now);
  final Booking b;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(b.apptAt.year, b.apptAt.month, b.apptAt.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final tone = levelTone(b.level);
    const meta = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF3D3955));
    return Material(
      color: CwColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/booking/${b.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$days', style: const TextStyle(fontSize: 20, height: 1, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
                  Text(days == 1 ? 'day' : 'days',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CwColors.primaryDark)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.patient.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${dayLabel(b.apptAt)} · ${placeName(b.hospitalId)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                ]),
              ),
              const SizedBox(width: 12),
              _Tag(levelLabel(b.level), background: tone.$1, color: tone.$2),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEFECF6)))),
              child: Row(children: [
                const CwIcon(CwIcons.clock, size: 15, strokeWidth: 2.4, color: CwColors.primaryDark),
                const SizedBox(width: 6),
                Text(timeLabel(b.apptAt), style: meta),
                if (b.caregiverName != null) ...[
                  const SizedBox(width: 16),
                  const CwIcon(CwIcons.person, size: 15, strokeWidth: 2.4, color: CwColors.primaryDark),
                  const SizedBox(width: 6),
                  Flexible(child: Text(b.caregiverName!, overflow: TextOverflow.ellipsis, style: meta)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FamilyChip extends StatelessWidget {
  const _FamilyChip(this.p, this.tone, this.onTap);
  final Patient p;
  final (Color, Color) tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: CwColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatarText(p.initials, size: 32, tone: tone, fontSize: 12),
              const SizedBox(width: 8),
              Text(_first(p.name), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _PastCard extends ConsumerWidget {
  const _PastCard(this.b);
  final Booking b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rated = b.rating != null;
    final first = _first(b.patient.name);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: CwColors.tealSoft, borderRadius: BorderRadius.circular(12)),
          child: const Center(child: CwIcon(CwIcons.check, size: 20, strokeWidth: 2.4, color: CwColors.teal)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$first · ${placeName(b.hospitalId)}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              [dayLabel(b.apptAt), levelLabel(b.level), formatRm(b.price.paidSen - b.price.refundSen), if (b.caregiverName != null) b.caregiverName!]
                  .join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: CwColors.muted),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 36,
          child: TextButton(
            onPressed: rated
                ? null
                : () => RateSheet.show(
                      context,
                      title: "How was $first's visit?",
                      subtitle: [dayLabel(b.apptAt), if (b.caregiverName != null) b.caregiverName!, placeName(b.hospitalId)].join(' · '),
                      initials: initialsOf(b.caregiverName ?? '?'),
                      onSubmit: (r) => ref.read(bookingRepoProvider).rate(b.id, r),
                    ),
            style: TextButton.styleFrom(
              backgroundColor: rated ? CwColors.surface : CwColors.primary,
              foregroundColor: CwColors.white,
              disabledBackgroundColor: CwColors.surface,
              disabledForegroundColor: CwColors.muted,
              padding: EdgeInsets.symmetric(horizontal: rated ? 12 : 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontFamily: cwFont, fontSize: 12, fontWeight: FontWeight.w800),
            ),
            child: Text(rated ? 'Rated ★ ${b.rating!.stars}' : 'Rate'),
          ),
        ),
      ]),
    );
  }
}
