import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../data/models/notification.dart';
import '../../data/providers.dart';

/// 22 · Notifications (Notifications.dc.html). Shared by guardians and caregivers.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

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
    return CwPage(
      title: 'Notifications',
      action: TextButton(
        onPressed: () => _markAll(notes.value ?? const []),
        child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      children: [
        Wrap(spacing: 8, children: [
          CwChip(label: 'All', selected: !_unreadOnly, onTap: () => setState(() => _unreadOnly = false)),
          CwChip(label: 'Unread', selected: _unreadOnly, onTap: () => setState(() => _unreadOnly = true)),
        ]),
        const Gap(14),
        AsyncView<List<AppNotification>>(
          value: notes,
          onRetry: () => ref.invalidate(notificationsProvider),
          isEmpty: (l) => l.where((n) => !_unreadOnly || !n.read).isEmpty,
          empty: const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: "You're all caught up",
            message: 'Updates about bookings and visits show up here.',
          ),
          data: (list) => Column(children: [
            for (final n in list.where((n) => !_unreadOnly || !n.read))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CwCard(
                  onTap: () => _open(n),
                  color: n.read ? CwColors.white : CwColors.lilac,
                  borderColor: n.read ? CwColors.line : CwColors.lilacLine,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      decoration: BoxDecoration(color: n.read ? Colors.transparent : CwColors.primary, shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.title, style: CwText.bodyBold),
                        if (n.body.isNotEmpty) Text(n.body, style: CwText.small),
                        if (n.createdAt != null)
                          Text('${agoLabel(n.createdAt!, now)} · ${timeLabel(n.createdAt!)}',
                              style: CwText.small.copyWith(fontSize: 12)),
                      ]),
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
