import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/design_kit.dart';
import '../../data/models/delivery.dart';
import '../../data/providers.dart';

/// True while a delivery is still being arranged or on its way.
bool isDeliveryInProgress(MedDelivery d) => switch (d.status) {
      DeliveryStatus.pendingCaregiver ||
      DeliveryStatus.awaitingPayment ||
      DeliveryStatus.booked ||
      DeliveryStatus.collecting ||
      DeliveryStatus.atPharmacy ||
      DeliveryStatus.collected ||
      DeliveryStatus.onTheWay =>
        true,
      _ => false,
    };

String _first(String name) => name.trim().split(RegExp(r'\s+')).first;

/// Card for a delivery that is still in progress: stage bar, current stage and helper.
class DeliveryProgressCard extends StatelessWidget {
  const DeliveryProgressCard(this.delivery, {super.key});
  final MedDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final waiting = d.status == DeliveryStatus.pendingCaregiver || d.status == DeliveryStatus.awaitingPayment;
    final chip = switch (d.status) {
      DeliveryStatus.pendingCaregiver => 'Pending',
      DeliveryStatus.awaitingPayment => 'Pay to confirm',
      _ => 'Live',
    };
    final idx = deliveryStageKeys.indexOf(d.status.wire);
    final stage = deliveryStageLabels[d.status.wire] ?? chip;
    final route = waiting ? '/delivery/${d.id}' : '/delivery/${d.id}/live';
    return Material(
      color: CwColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: CwColors.deliverySoft, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: CwIcon(CwIcons.medicine, size: 22, strokeWidth: 2.2, color: CwColors.deliveryBlue)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("${_first(d.patientName)}'s medicine",
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${d.pharmacyName} · to your doorstep',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                ]),
              ),
              const SizedBox(width: 8),
              _Chip(chip, background: CwColors.deliverySoft, color: CwColors.deliveryBlue),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < deliveryStageKeys.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < idx
                          ? CwColors.deliveryBlue
                          : i == idx
                              ? const Color(0xFF8FB0DA)
                              : const Color(0xFFE3ECF8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text('$stage · ${d.caregiverName ?? 'Finding a helper'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF3D3955))),
              ),
              const Text('Track ›', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CwColors.deliveryBlue)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Compact row for a finished delivery.
class DeliveredRow extends StatelessWidget {
  const DeliveredRow(this.delivery, {super.key});
  final MedDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final when = d.date ?? d.createdAt;
    return Material(
      color: CwColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/delivery/${d.id}/done'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${when == null ? '' : '${DateFormat('EEE d MMM').format(when.toLocal())} · '}${_first(d.patientName)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(d.pharmacyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            const _Chip('Delivered', background: CwColors.successSoft, color: CwColors.successDark),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.background, required this.color});
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

/// Medicine deliveries (/deliveries): in progress first, then delivered.
class DeliveryListScreen extends ConsumerWidget {
  const DeliveryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(familyDeliveriesProvider);
    return DesignScaffold(
      bottom: BigButton(label: 'New delivery', onPressed: () => context.push('/delivery/new')),
      children: [
        const PageHeader(title: 'Medicine deliveries', subtitle: 'Track and look back at every delivery'),
        AsyncView<List<MedDelivery>>(
          value: all,
          onRetry: () => ref.invalidate(familyDeliveriesProvider),
          data: (list) {
            final active = [for (final d in list) if (isDeliveryInProgress(d)) d];
            final done = [for (final d in list) if (d.status == DeliveryStatus.delivered) d];
            if (active.isEmpty && done.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('No deliveries yet', style: TextStyle(fontSize: 14, color: CwColors.muted))),
              );
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (active.isNotEmpty) ...[
                const Text('In progress', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (final d in active) Padding(padding: const EdgeInsets.only(bottom: 12), child: DeliveryProgressCard(d)),
              ],
              if (done.isNotEmpty) ...[
                if (active.isNotEmpty) const SizedBox(height: 10),
                const Text('Delivered', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (final d in done) Padding(padding: const EdgeInsets.only(bottom: 12), child: DeliveredRow(d)),
              ],
            ]);
          },
        ),
      ],
    );
  }
}
