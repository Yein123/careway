import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../data/api.dart';
import '../../data/models/booking.dart';
import '../../data/models/delivery.dart';
import '../../data/providers.dart';
import 'admin_providers.dart';

/// One row in "Live requests": a booking or a medicine delivery.
class _Item {
  const _Item({
    required this.col,
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.createdAt,
    this.groupId,
    this.isLevel1 = false,
  });

  final String col; // 'bookings' | 'deliveries'
  final String id;
  final String title;
  final String type; // Group | Escort | Medicine
  final String status; // wire value
  final DateTime? createdAt;
  final String? groupId;
  final bool isLevel1;

  bool get pending => status == 'pending_caregiver';
  bool get canLockGroup =>
      col == 'bookings' && isLevel1 && status == 'confirmed' && groupId != null;
  bool get canAdvanceDelivery =>
      col == 'deliveries' &&
      const {'booked', 'collecting', 'at_pharmacy', 'on_the_way'}.contains(status);
}

String _statusLabel(String wire) {
  final w = wire.replaceAll('_', ' ');
  return w[0].toUpperCase() + w.substring(1);
}

List<_Item> _items(List<Booking> bookings, List<MedDelivery> deliveries) {
  final out = <_Item>[
    for (final b in bookings)
      _Item(
        col: 'bookings',
        id: b.id,
        title: _title(b.guardianName, b.patient.name),
        type: b.level == 1 ? 'Group' : 'Escort',
        status: b.status.wire,
        createdAt: b.createdAt,
        groupId: b.groupId,
        isLevel1: b.level == 1,
      ),
    for (final d in deliveries)
      _Item(
        col: 'deliveries',
        id: d.id,
        title: _title('', d.patientName),
        type: 'Medicine',
        status: d.status.wire,
        createdAt: d.createdAt,
      ),
  ];
  out.sort((a, b) {
    final x = a.createdAt, y = b.createdAt;
    if (x == null || y == null) return 0;
    return y.compareTo(x);
  });
  return out;
}

String _title(String guardian, String patient) =>
    guardian.isEmpty ? patient : '$guardian · $patient';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _busy = <String>{};

  /// Runs [action] with a spinner on the button identified by [key]; shows
  /// errors (or the optional success message) in a snackbar.
  Future<void> _run(String key, Future<String?> Function() action) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final msg = await action();
      if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  CareWayApi get _api => ref.read(careWayApiProvider);

  Widget _btn(String key, String label, Future<String?> Function() action, {bool primary = false}) {
    final loading = _busy.contains(key);
    final child = loading
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
        : Text(label);
    final onPressed = loading ? null : () => _run(key, action);
    return primary
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }

  Widget _row(_Item it) {
    final k = '${it.col}/${it.id}';
    final buttons = <Widget>[
      if (it.pending) ...[
        _btn('$k:accept', 'Accept', () async {
          await _api.adminRespondOffer(it.col, it.id, true);
          return null;
        }, primary: true),
        _btn('$k:reject', 'Reject', () async {
          await _api.adminRespondOffer(it.col, it.id, false);
          return null;
        }),
        _btn('$k:nf', 'Not found', () async {
          await _api.adminNotFound(it.col, it.id);
          return null;
        }),
      ],
      if (it.canLockGroup)
        _btn('$k:lock', 'Group set', () async {
          final status = await _api.adminLockGroup(it.groupId!);
          return status == 'locked' ? 'Group set' : 'Group cancelled — no riders';
        }, primary: true),
      if (it.canAdvanceDelivery) ...[
        _btn('$k:next', 'Next stage', () async {
          await _api.adminAdvanceDelivery(it.id);
          return null;
        }, primary: true),
        _btn('$k:end', 'Run to delivered', () async {
          await _api.adminAdvanceDelivery(it.id, toEnd: true);
          return null;
        }),
      ],
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CwColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CwColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(it.title, style: CwText.h3),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill(it.type, CwColors.lilac, CwColors.primaryDark),
            _pill(_statusLabel(it.status), CwColors.tealSoft, CwColors.tealDark),
          ]),
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: buttons),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _liveRequests() {
    final bookings = ref.watch(adminBookingsProvider);
    final deliveries = ref.watch(adminDeliveriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Live requests', style: CwText.h2),
        const SizedBox(height: 12),
        AsyncView<List<Booking>>(
          value: bookings,
          data: (bs) => AsyncView<List<MedDelivery>>(
            value: deliveries,
            data: (ds) {
              final items = _items(bs, ds);
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No live requests.', style: CwText.muted),
                );
              }
              return Column(children: [for (final it in items) _row(it)]);
            },
          ),
        ),
      ],
    );
  }

  Widget _visit() {
    final s3 = ref.watch(adminS3Provider);
    final b = s3.value;
    final label = b == null || b.steps.isEmpty
        ? 'Not started'
        : (stepLabels[b.steps.last.key] ?? b.steps.last.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Caregiver visit', style: CwText.h2),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CwColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CwColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: CwText.h3),
              const SizedBox(height: 12),
              _btn('s3:advance', 'Advance step', () async {
                await _api.adminAdvanceStep(demoS3BookingId);
                return null;
              }, primary: true),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CwColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final header = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CareWay demo admin', style: CwText.h1),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _btn('reset', 'Reset demo for today', () async {
                    await _api.adminReset();
                    return 'Demo reset';
                  }, primary: true),
                  OutlinedButton(
                    onPressed: () => ref.read(authRepoProvider).signOut(),
                    child: const Text('Sign out'),
                  ),
                ]),
              ],
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: 24),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _liveRequests()),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: _visit()),
                      ],
                    )
                  else ...[
                    _liveRequests(),
                    const SizedBox(height: 24),
                    _visit(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
