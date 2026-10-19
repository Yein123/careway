import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/design_kit.dart';
import '../../data/api.dart';
import '../../data/models/notification.dart';
import '../../data/providers.dart';
import '../caregiver/cg_providers.dart';

enum _Kind { ride, visit, delivery }

const _kinds = {
  _Kind.ride: ('Ride', CwColors.successSoft, Color(0xFF1D6B45), '<path d="M4 16V9l2-4h12l2 4v7M3 16h18v3H3zM7 19v1M17 19v1"/>'),
  _Kind.visit: ('Visit reminder', CwColors.lilac, CwColors.primaryDark, '<path d="M4 6h16v14H4zM4 10h16M9 3v4M15 3v4"/>'),
  _Kind.delivery: ('Medicine delivery', CwColors.deliverySoft, CwColors.deliveryBlue, CwIcons.medicine),
};

_Kind _kindOf(AppNotification n) => switch (n.type) {
      'visit-step' || 'ride-ready' => _Kind.ride,
      'delivery-step' => _Kind.delivery,
      _ when (n.link ?? '').startsWith('/delivery') => _Kind.delivery,
      _ => _Kind.visit,
    };

/// 22 · Notifications (Notifications.dc.html). Shared by guardians and caregivers.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _Kind? _filter;

  Future<void> _open(AppNotification n) async {
    final uid = ref.read(authStateProvider).value;
    final router = GoRouter.of(context);
    if (uid != null && !n.read) await ref.read(notificationRepoProvider).markRead(uid, n.id);
    if (n.link != null) router.go(n.link!);
  }

  Future<void> _markAll(List<AppNotification> list) async {
    final uid = ref.read(authStateProvider).value;
    if (uid == null) return;
    final repo = ref.read(notificationRepoProvider);
    for (final n in list.where((n) => !n.read)) {
      await repo.markRead(uid, n.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notificationsProvider);
    final now = ref.watch(clockProvider)();
    final filters = [(null, 'All'), (_Kind.ride, 'Rides'), (_Kind.visit, 'Visit reminders'), (_Kind.delivery, 'Deliveries')];

    return Scaffold(
      backgroundColor: CwColors.surface,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PageHeader(
                title: 'Notifications',
                trailing: TextButton(
                  onPressed: () => _markAll(notes.value ?? const []),
                  style: TextButton.styleFrom(foregroundColor: CwColors.primaryDark, padding: const EdgeInsets.symmetric(horizontal: 4)),
                  child: const Text('Mark all read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, c) => SizedBox(
                  height: 38,
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: c.maxWidth + 20,
                    maxWidth: c.maxWidth + 20,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 20),
                      itemCount: filters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final on = filters[i].$1 == _filter;
                        return Semantics(
                          selected: on,
                          button: true,
                          child: Material(
                            color: on ? CwColors.primary : CwColors.white,
                            shape: StadiumBorder(side: on ? BorderSide.none : const BorderSide(color: CwColors.line, width: 2)),
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: () => setState(() => _filter = filters[i].$1),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Center(
                                  widthFactor: 1,
                                  child: Text(filters[i].$2,
                                      style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w800 : FontWeight.w700, color: on ? CwColors.white : CwColors.ink)),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: AsyncView<List<AppNotification>>(
              value: notes,
              onRetry: () => ref.invalidate(notificationsProvider),
              isEmpty: (l) => l.where((n) => _filter == null || _kindOf(n) == _filter).isEmpty,
              empty: const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: "You're all caught up",
                message: 'Updates about bookings and visits show up here.',
              ),
              data: (list) {
                final shown = list.where((n) => _filter == null || _kindOf(n) == _filter).toList();
                bool isToday(AppNotification n) => n.createdAt != null && DateUtils.isSameDay(n.createdAt!.toLocal(), now.toLocal());
                final today = shown.where(isToday).toList();
                final earlier = shown.where((n) => !isToday(n)).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    for (final (head, items) in [('TODAY', today), ('EARLIER', earlier)])
                      if (items.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
                          child: Text(head, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: CwColors.muted)),
                        ),
                        for (final n in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: _Card(n, now, () => _open(n))),
                      ],
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.n, this.now, this.onTap);
  final AppNotification n;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, icon) = _kinds[_kindOf(n)]!;
    final unread = !n.read;
    final when = n.createdAt == null
        ? ''
        : now.difference(n.createdAt!).inMinutes < 2
            ? 'Now'
            : DateUtils.isSameDay(n.createdAt!.toLocal(), now.toLocal())
                ? timeLabel(n.createdAt!)
                : agoLabel(n.createdAt!, now).replaceFirst('yesterday', 'Yesterday');
    return Opacity(
      opacity: unread ? 1 : 0.85,
      child: Material(
        color: CwColors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: unread ? const BoxDecoration(border: Border(left: BorderSide(color: CwColors.primary, width: 3))) : null,
            padding: EdgeInsets.fromLTRB(unread ? 11 : 14, 12, 14, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Center(child: CwIcon(icon, size: 20, strokeWidth: 2.2, color: fg)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg))),
                    Text(when, style: const TextStyle(fontSize: 11, color: CwColors.muted)),
                  ]),
                  const SizedBox(height: 3),
                  Text(n.title, style: const TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w800)),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(n.body, style: const TextStyle(fontSize: 12, height: 1.45, color: CwColors.muted)),
                  ],
                  // Job requests are keyed by their offer id.
                  if (n.type == 'job-request') _OfferActions(offerId: n.id),
                ]),
              ),
              const SizedBox(width: 12),
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: unread ? CwColors.pink : Colors.transparent, shape: BoxShape.circle),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Accept / Decline on a caregiver's job request while its offer is still open.
class _OfferActions extends ConsumerStatefulWidget {
  const _OfferActions({required this.offerId});
  final String offerId;

  @override
  ConsumerState<_OfferActions> createState() => _OfferActionsState();
}

class _OfferActionsState extends ConsumerState<_OfferActions> {
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(careWayApiProvider).respondToOffer(widget.offerId, accept);
      messenger.showSnackBar(SnackBar(content: Text(accept ? 'Added to your schedule. The family pays next.' : 'Request declined.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final open = (ref.watch(cgOffersProvider).value ?? const []).any((o) => o.id == widget.offerId && o.expiresAt.isAfter(now));
    if (!open) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Expanded(child: CwButton(label: 'Decline', kind: CwButtonKind.secondary, onPressed: _busy ? null : () => _respond(false))),
        const SizedBox(width: 8),
        Expanded(child: CwButton(label: 'Accept', loading: _busy, onPressed: _busy ? null : () => _respond(true))),
      ]),
    );
  }
}
