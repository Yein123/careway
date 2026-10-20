import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../data/api.dart';
import '../../data/models/booking.dart';
import '../../data/models/delivery.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../../domain/pricing.dart';
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
      const {'booked', 'collecting', 'at_pharmacy', 'collected', 'on_the_way'}.contains(status);
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

  Widget _visits() {
    final visits = ref.watch(adminTodayVisitsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today's caregiver visits", style: CwText.h2),
        const SizedBox(height: 4),
        const Text('Act as the assigned caregiver: post each visit update, then write the summary.', style: CwText.muted),
        const SizedBox(height: 12),
        AsyncView<List<Booking>>(
          value: visits,
          data: (bs) {
            final live = [for (final b in bs) if (b.caregiverId != null && _visitStatuses.contains(b.status)) b];
            if (live.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No visits today.', style: CwText.muted),
              );
            }
            return Column(children: [for (final b in live) _visitCard(b)]);
          },
        ),
      ],
    );
  }

  static const _visitStatuses = {BookingStatus.confirmed, BookingStatus.inProgress, BookingStatus.completed};

  Widget _visitCard(Booking b) {
    final k = 'visit/${b.id}';
    final next = b.nextStepKey;
    final active = b.status == BookingStatus.confirmed || b.status == BookingStatus.inProgress;
    final needsSummary = b.level == 2 || b.addons.contains(Addon.visitSummary);
    final blocked = next == b.stepKeys.last && needsSummary && b.summary == null;
    final seenDoctor = b.status == BookingStatus.completed || b.steps.any((s) => s.key == 'with_doctor');
    final last = b.steps.isEmpty ? 'Not started' : (stepLabels[b.steps.last.key] ?? b.steps.last.key);
    return Container(
      width: double.infinity,
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
          Text(_title(b.guardianName, b.patient.name), style: CwText.h3),
          const SizedBox(height: 4),
          Text('${timeLabel(b.apptAt)} · ${b.caregiverName ?? 'Caregiver'}', style: CwText.muted),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill(b.level == 1 ? 'Group' : 'Escort', CwColors.lilac, CwColors.primaryDark),
            _pill(_statusLabel(b.status.wire), CwColors.tealSoft, CwColors.tealDark),
            if (b.summary != null) _pill('Summary sent', CwColors.successSoft, CwColors.successDark),
          ]),
          const SizedBox(height: 10),
          Text('$last · ${b.steps.length} of ${b.stepKeys.length} done', style: CwText.h3),
          if (blocked) ...[
            const SizedBox(height: 4),
            const Text('Write the visit summary before marking Home safely.', style: CwText.muted),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (active && next != null && !blocked)
              _btn('$k:advance', 'Mark done: ${stepLabels[next] ?? next}', () async {
                await _api.adminAdvanceStep(b.id);
                return null;
              }, primary: true),
            if (seenDoctor)
              OutlinedButton(
                onPressed: () => _openSummary(b),
                child: Text(b.summary == null ? 'Write visit summary' : 'Edit visit summary'),
              ),
          ]),
        ],
      ),
    );
  }

  Future<void> _openSummary(Booking b) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _SummaryDialog(booking: b, api: _api),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visit summary sent')));
    }
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
                        Expanded(flex: 2, child: _visits()),
                      ],
                    )
                  else ...[
                    _liveRequests(),
                    const SizedBox(height: 24),
                    _visits(),
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

/// Visit summary form, submitted on behalf of the booking's caregiver.
class _SummaryDialog extends StatefulWidget {
  const _SummaryDialog({required this.booking, required this.api});
  final Booking booking;
  final CareWayApi api;

  @override
  State<_SummaryDialog> createState() => _SummaryDialogState();
}

class _SummaryDialogState extends State<_SummaryDialog> {
  late final VisitSummary? _s = widget.booking.summary;
  late final _seenBy = TextEditingController(text: _s?.seenBy ?? '');
  late final _diagnosis = TextEditingController(text: _s?.diagnosis ?? '');
  late final _instructions = TextEditingController(text: _s?.instructions.join('\n') ?? '');
  late final _medicines = TextEditingController(text: _s?.medicines ?? '');
  late final _nextAppt = TextEditingController(text: _s?.nextAppt ?? '');
  late final _notes = TextEditingController(text: _s?.notes ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_seenBy, _diagnosis, _instructions, _medicines, _nextAppt, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.adminSubmitSummary(widget.booking.id, {
        'seenBy': _seenBy.text.trim(),
        'diagnosis': _diagnosis.text.trim(),
        'instructions': [
          for (final l in _instructions.text.split('\n'))
            if (l.trim().isNotEmpty) l.trim(),
        ],
        'nextAppt': _nextAppt.text.trim(),
        'medicines': _medicines.text.trim(),
        'notes': _notes.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, TextEditingController c, {int lines = 1, String? hint, Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: key,
          controller: c,
          minLines: lines,
          maxLines: lines,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final valid = _diagnosis.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text('Visit summary · ${b.patient.name}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sent as ${b.caregiverName ?? 'the caregiver'}. Only the family group can see it.', style: CwText.muted),
              const SizedBox(height: 12),
              _field('Seen by', _seenBy, hint: 'e.g. Dr Lee'),
              _field("Doctor's advice", _diagnosis, lines: 2, hint: 'Knee is improving. Continue physiotherapy.', key: const ValueKey('as-diagnosis')),
              _field('Medical instructions (one per line)', _instructions, lines: 3),
              _field('Medicine collected', _medicines, hint: 'e.g. Paracetamol 500 mg'),
              _field('Next appointment', _nextAppt, hint: 'e.g. 26 Jan 2027'),
              _field('Notes', _notes, hint: 'e.g. BP 132/84 · weight 61 kg'),
              if (_error != null) Text(_error!, style: const TextStyle(color: CwColors.pink)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy || !valid ? null : _send,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
              : const Text('Send to family group'),
        ),
      ],
    );
  }
}
