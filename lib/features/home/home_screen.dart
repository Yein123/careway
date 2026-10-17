import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/places.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/cw_top_bar.dart';
import '../../core/widgets/safety_button.dart';
import '../../core/widgets/step_label.dart';
import '../../data/models/booking.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';

String placeName(String hospitalId) {
  try {
    return placeById(hospitalId).name;
  } catch (_) {
    return hospitalId;
  }
}

String levelLabel(int level) => level == 1 ? 'Group' : 'Personal';

/// 2 · Home (Home.dc.html)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final bookings = ref.watch(familyBookingsProvider).value ?? const <Booking>[];
    final patients = ref.watch(patientsProvider).value ?? const [];
    final unread = (ref.watch(notificationsProvider).value ?? const []).where((n) => !n.read).length;
    final now = ref.watch(clockProvider)();

    final awaiting = bookings.where((b) => b.status == BookingStatus.awaitingPayment).toList();
    final pending = bookings.where((b) => b.status == BookingStatus.pendingCaregiver).toList();
    final live = bookings.where((b) => b.status == BookingStatus.inProgress).toList();
    final upcoming = bookings.where((b) => b.status == BookingStatus.confirmed && b.apptAt.isAfter(now)).toList()
      ..sort((a, b) => a.apptAt.compareTo(b.apptAt));
    final past = bookings.where((b) => b.status == BookingStatus.completed).toList()
      ..sort((a, b) => b.apptAt.compareTo(a.apptAt));

    return CwPage(
      children: [
        Row(children: [
          Avatar(user?.initials ?? '?'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${user?.firstName ?? 'there'}!', style: CwText.h2),
              if ((user?.area ?? '').isNotEmpty) Text(user!.area, style: CwText.small),
            ]),
          ),
          SquareIconButton(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            badge: unread,
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(width: 8),
          const SafetyButton(),
        ]),
        const Gap(18),
        for (final b in awaiting)
          _ActionCard(
            color: CwColors.amberSoft,
            accent: CwColors.amber,
            title: 'Pay to confirm',
            body: '${b.caregiverName ?? 'Your caregiver'} accepted ${b.patient.name.split(' ').first}\'s visit on ${dayLabel(b.apptAt)}.',
            onTap: () => context.push(b.level == 1 ? '/booking/${b.id}/package' : '/booking/${b.id}/pay'),
          ),
        for (final b in pending)
          _ActionCard(
            color: CwColors.lilac,
            accent: CwColors.primaryDark,
            title: 'Finding a caregiver',
            body: '${b.patient.name.split(' ').first} · ${dayLabel(b.apptAt)}. You are not charged until someone accepts.',
            onTap: () => context.push('/booking/${b.id}/pending'),
          ),
        CwCard(
          color: CwColors.primary,
          borderColor: CwColors.primary,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Doctor's visit coming up?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CwColors.white)),
            const SizedBox(height: 4),
            const Text('Helper + ride, no leave needed', style: TextStyle(fontSize: 14, color: Color(0xFFE4DCFB))),
            const SizedBox(height: 14),
            CwButton(label: 'Book a visit', color: CwColors.white, onPressed: () => context.push('/book')),
          ]),
        ),
        const Gap(20),
        if (live.isNotEmpty) ...[
          const SectionTitle('Ongoing'),
          for (final b in live) _LiveCard(b),
          const Gap(12),
        ],
        const SectionTitle('Services'),
        _TileRow([
          _ServiceTile(Icons.directions_bus_outlined, 'Shared ride + guidance', 'Level 1', CwColors.primary,
              () => context.push('/book?service=level1')),
          _ServiceTile(Icons.accessibility_new_rounded, 'One-to-one escort', 'Level 2', CwColors.teal,
              () => context.push('/book?service=level2')),
        ]),
        const Gap(10),
        _TileRow([
          _ServiceTile(Icons.medication_outlined, 'Medicine delivery', 'Fee by distance', CwColors.deliveryBlue,
              () => context.push('/delivery/new')),
          _ServiceTile(Icons.badge_outlined, 'Patient profiles', '${patients.length} family members', CwColors.pink,
              () => context.go('/family')),
        ]),
        const Gap(10),
        _ServiceTile(Icons.shield_outlined, 'Help and safety', 'Emergency, support', CwColors.pink,
            () => context.go('/account?section=safety'),
            wide: true),
        const Gap(20),
        SectionTitle('Upcoming', trailing: TextButton(onPressed: () => context.go('/visits'), child: const Text('See all'))),
        if (upcoming.isEmpty)
          const Text('No visits booked yet.', style: CwText.muted)
        else
          for (final b in upcoming.take(3)) _UpcomingRow(b, now),
        if (past.isNotEmpty) ...[
          const Gap(20),
          const SectionTitle('Past visits'),
          for (final b in past.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CwCard(
                onTap: () => context.go('/visits'),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${b.patient.name.split(' ').first} · ${placeName(b.hospitalId)}', style: CwText.bodyBold),
                      Text(
                        '${dayLabel(b.apptAt)} · ${levelLabel(b.level)} · ${formatRm(b.price.paidSen - b.price.refundSen)} · ${b.caregiverName ?? ''}',
                        style: CwText.small,
                      ),
                    ]),
                  ),
                  Text(b.rating == null ? 'Rate this visit' : 'Rated ★ ${b.rating!.stars}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
                ]),
              ),
            ),
        ],
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.color, required this.accent, required this.title, required this.body, required this.onTap});
  final Color color;
  final Color accent;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CwCard(
          color: color,
          borderColor: color,
          onTap: onTap,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accent)),
                const SizedBox(height: 2),
                Text(body, style: CwText.small),
              ]),
            ),
            Icon(Icons.chevron_right, color: accent),
          ]),
        ),
      );
}

class _LiveCard extends StatelessWidget {
  const _LiveCard(this.b);
  final Booking b;

  @override
  Widget build(BuildContext context) {
    final last = b.steps.isEmpty ? null : b.steps.last;
    return CwCard(
      color: CwColors.successSoft,
      borderColor: CwColors.successSoft,
      onTap: () => context.push('/booking/${b.id}/live'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CwBadge('LIVE NOW', color: CwColors.white, background: CwColors.success),
          const SizedBox(width: 8),
          CwBadge(levelLabel(b.level).toUpperCase()),
        ]),
        const SizedBox(height: 8),
        Text('${b.patient.name.split(' ').first} · ${last == null ? 'on the way' : stepLabels[last.key]}', style: CwText.h3),
        Text('${placeName(b.hospitalId)} · ${b.caregiverName ?? ''}', style: CwText.small),
        if (last != null) Text('Updated ${timeLabel(last.at)}', style: CwText.small),
        const Align(alignment: Alignment.centerRight, child: Text('Track ›', style: TextStyle(fontWeight: FontWeight.w800, color: CwColors.successDark))),
      ]),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow(this.b, this.now);
  final Booking b;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = b.apptAt.difference(now).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CwCard(
        onTap: () => context.push('/booking/${b.id}'),
        child: Row(children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('$days', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CwColors.primaryDark)),
              Text(days == 1 ? 'day' : 'days', style: CwText.small),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.patient.name, style: CwText.bodyBold),
              Text('${dayLabel(b.apptAt)} · ${placeName(b.hospitalId)}', style: CwText.small),
              Text('${levelLabel(b.level)} · ${timeLabel(b.apptAt)} · ${b.caregiverName ?? ''}', style: CwText.small),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Two equal-height tiles side by side.
class _TileRow extends StatelessWidget {
  const _TileRow(this.tiles);
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: 10),
          Expanded(child: tiles[1]),
        ]),
      );
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile(this.icon, this.title, this.sub, this.color, this.onTap, {this.wide = false});
  final IconData icon;
  final String title;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) => CwCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Flex(
          direction: wide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            SizedBox(height: 8, width: wide ? 12 : 0),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: CwText.small),
              ]),
            ),
          ],
        ),
      );
}
