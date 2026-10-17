import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/step_label.dart';
import '../../data/models/booking.dart';
import '../../data/providers.dart';
import '../home/home_screen.dart' show placeName;
import 'booking_common.dart';

/// Short display reference for a booking id.
String bookingRef(String id) => 'CW-${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}';

/// 9 · Booking confirmed and 16 · Escort booked.
class ConfirmedScreen extends ConsumerWidget {
  const ConfirmedScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    final now = ref.watch(clockProvider)();
    return CwPage(
      showBack: false,
      children: [
        AsyncView<Booking?>(
          value: booking,
          onRetry: () => ref.invalidate(bookingProvider(bookingId)),
          isEmpty: (b) => b == null,
          empty: const EmptyState(icon: Icons.search_off, title: 'Booking not found'),
          data: (b) {
            b!;
            final first = b.patient.name.split(' ').first;
            final paid = b.price.paidSen;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Gap(12),
              const Center(child: Icon(Icons.check_circle, size: 72, color: CwColors.success)),
              const Gap(8),
              const Text('Payment successful', textAlign: TextAlign.center, style: CwText.small),
              Text(b.level == 1 ? 'Visit booked' : 'Escort booked', textAlign: TextAlign.center, style: CwText.h1),
              const Gap(6),
              Text(
                b.level == 1
                    ? '$first is all set for ${dayLabel(b.apptAt)}. We\'ll remind you the evening before.'
                    : '${b.caregiverName ?? 'Your escort'} will stay with $first for the whole visit on ${dayLabel(b.apptAt)}.',
                textAlign: TextAlign.center,
                style: CwText.muted,
              ),
              const Gap(16),
              CwCard(
                child: Column(children: [
                  KeyValueRow('Booking ID', bookingRef(b.id)),
                  KeyValueRow('Patient', '${b.patient.name}, ${b.patient.age}'),
                  KeyValueRow('Appointment', dayTimeLabel(b.apptAt)),
                  KeyValueRow('Hospital', '${placeName(b.hospitalId)}, ${b.clinic}'),
                  if (b.pickupAt != null) KeyValueRow('Pickup', '${timeLabel(b.pickupAt!)}, ${b.pickup.label}'),
                  KeyValueRow('Help', '${b.level == 1 ? 'Level 1 · shared helper' : 'Level 2 · one-to-one'} · ${b.caregiverName ?? ''}'),
                  const Divider(),
                  for (final l in b.price.lines) KeyValueRow(l.label, formatRm(l.sen)),
                  KeyValueRow('Amount paid', formatRm(paid), bold: true),
                ]),
              ),
              const Gap(8),
              Text(
                b.level == 1
                    ? 'If more neighbours join before the group locks, the difference comes back to you automatically. ${cancelRuleText(b, now)}'
                    : 'Any unused time is refunded after the visit. ${cancelRuleText(b, now)}',
                style: CwText.small,
              ),
              const Gap(20),
              CwButton(label: 'View visit', onPressed: () => context.go('/booking/${b.id}')),
              const Gap(8),
              CwButton(label: 'Back to home', kind: CwButtonKind.text, onPressed: () => context.go('/home')),
            ]);
          },
        ),
      ],
    );
  }
}
