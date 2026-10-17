import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/cw_button.dart';
import '../../core/widgets/cw_card.dart';
import '../../core/widgets/cw_chip.dart';
import '../../core/widgets/cw_page.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/status_timeline.dart';
import '../../core/widgets/step_label.dart';
import '../../data/api.dart';
import '../../data/models/booking.dart';
import '../../data/models/family.dart';
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../booking/confirmed_screen.dart' show bookingRef;
import '../home/home_screen.dart' show placeName, levelLabel;
import '../visits/live_visit_screen.dart' show callNumber, visitTimeline;

/// The patient's full profile, readable by the assigned caregiver while the
/// visit is active (security rules: access doc).
final _jobPatientProvider = StreamProvider.family<Patient?, (String, String)>(
  (ref, k) => ref.watch(familyRepoProvider).watchPatient(k.$1, k.$2).handleError((_) {}),
);

Widget _bookingView(WidgetRef ref, String id, Widget Function(Booking) data) => AsyncView<Booking?>(
      value: ref.watch(bookingProvider(id)),
      onRetry: () => ref.invalidate(bookingProvider(id)),
      isEmpty: (b) => b == null,
      empty: const EmptyState(icon: Icons.search_off, title: 'Job not found'),
      data: (b) => data(b!),
    );

/// C3 · Caregiver: job details (CgJob.dc.html)
class CgJobScreen extends ConsumerWidget {
  const CgJobScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CwPage(
      title: 'Job details',
      children: [
        _bookingView(ref, bookingId, (b) {
          final p = ref.watch(_jobPatientProvider((b.familyId, b.patientId))).value;
          final active = b.status == BookingStatus.confirmed || b.status == BookingStatus.inProgress;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${bookingRef(b.id)} · ${b.level == 1 ? 'Group helper' : 'Personal escort'}', style: CwText.small),
            const Gap(10),
            CwCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Avatar(b.patient.initials, background: CwColors.pinkSoft, color: CwColors.pink),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${b.patient.name}, ${b.patient.age}', style: CwText.h3)),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  CwBadge(b.patient.mobility.label),
                  if (b.patient.allergy.isNotEmpty) CwBadge('Allergy: ${b.patient.allergy}', color: CwColors.pink, background: CwColors.pinkSoft),
                  for (final e in p?.extraHelp ?? const <String>[]) CwBadge(e),
                  for (final a in b.addons) CwBadge(a.label, color: CwColors.tealDark, background: CwColors.tealSoft),
                ]),
                if (b.patient.talkNotes.isNotEmpty) ...[const SizedBox(height: 8), Text(b.patient.talkNotes, style: CwText.muted)],
                if ((p?.conditions ?? '').isNotEmpty) ...[const SizedBox(height: 6), Text(p!.conditions, style: CwText.small)],
              ]),
            ),
            const Gap(12),
            CwCard(
              child: Column(children: [
                if (b.pickupAt != null) KeyValueRow('Pickup', '${timeLabel(b.pickupAt!)} · ${b.pickup.label}'),
                KeyValueRow('Appointment', '${dayTimeLabel(b.apptAt)} · ${placeName(b.hospitalId)}'),
                KeyValueRow('Clinic', b.clinic),
                KeyValueRow('Booked for', b.level == 1 ? 'Shared ride (${levelLabel(b.level)})' : 'About 4 hours'),
                if (b.language != null && b.addons.isNotEmpty) KeyValueRow('Language', b.language!),
              ]),
            ),
            const Gap(10),
            CwButton(
              label: 'Directions to pickup',
              kind: CwButtonKind.secondary,
              color: CwColors.teal,
              onPressed: () => launchUrl(
                Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${b.pickup.lat},${b.pickup.lng}'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            const Gap(16),
            const SectionTitle('Family contacts'),
            CwCard(
              child: Column(children: [
                KeyValueRow('Booked by', b.guardianName.isEmpty ? 'Family' : b.guardianName),
                for (final c in p?.contacts ?? const <Contact>[])
                  InkWell(onTap: () => callNumber(context, c.phone), child: KeyValueRow('${c.name} · ${c.role}', c.phone)),
                if (p == null && active) const Text('Profile details load once the visit is confirmed.', style: CwText.small),
              ]),
            ),
            const Gap(16),
            if (active) CwButton(label: 'Open visit steps', color: CwColors.teal, onPressed: () => context.push('/cg/job/${b.id}/steps')),
            if (b.status == BookingStatus.awaitingPayment)
              const Text('Waiting for the family to pay. It becomes a confirmed job once they do.', style: CwText.muted),
          ]);
        }),
      ],
    );
  }
}

/// C4 · Caregiver: update visit steps (CgVisit.dc.html)
class CgStepsScreen extends ConsumerStatefulWidget {
  const CgStepsScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<CgStepsScreen> createState() => _CgStepsScreenState();
}

class _CgStepsScreenState extends ConsumerState<CgStepsScreen> {
  bool _busy = false;

  Future<void> _advance(Booking b) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(careWayApiProvider).advanceStep(b.id);
    } on CareWayException catch (e) {
      if (e.code == 'summary-required') {
        router.go('/cg/job/${b.id}/summary');
      } else {
        messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CwPage(
      title: 'Visit steps',
      children: [
        _bookingView(ref, widget.bookingId, (b) {
          final next = b.nextStepKey;
          final done = b.status == BookingStatus.completed;
          final needsSummary = b.level == 2 || b.addons.any((a) => a.name == 'visitSummary');
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${b.patient.name}, ${b.patient.age}', style: CwText.h3),
            Text('${levelLabel(b.level)} · ${placeName(b.hospitalId)} · ${b.clinic}', style: CwText.small),
            const Gap(12),
            CwCard(
              color: CwColors.pinkSoft,
              borderColor: CwColors.pinkSoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const StepLabel('Before you start', color: CwColors.pink),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (b.patient.allergy.isNotEmpty) CwBadge('Allergy: ${b.patient.allergy}', color: CwColors.pink, background: CwColors.white),
                  CwBadge(b.patient.mobility.label, color: CwColors.pink, background: CwColors.white),
                ]),
                if (b.patient.talkNotes.isNotEmpty) ...[const SizedBox(height: 6), Text(b.patient.talkNotes, style: CwText.small)],
              ]),
            ),
            const Gap(14),
            SectionTitle('Visit steps', trailing: Text('${b.steps.length} of ${b.stepKeys.length}', style: CwText.small)),
            CwCard(child: StatusTimeline(steps: visitTimeline(b), accent: CwColors.teal)),
            const Gap(14),
            if (!done && next != null)
              CwButton(label: 'Mark: ${stepLabels[next]}', color: CwColors.teal, loading: _busy, onPressed: () => _advance(b)),
            if (done) const Text('Visit complete. Thank you!', textAlign: TextAlign.center, style: CwText.bodyBold),
            const Gap(8),
            if (needsSummary || b.summary != null)
              CwButton(
                label: b.summary == null ? 'Write visit summary' : 'Edit visit summary',
                kind: CwButtonKind.secondary,
                color: CwColors.teal,
                onPressed: () => context.push('/cg/job/${b.id}/summary'),
              ),
            const Gap(8),
            Text('The family gets a notification at each step.', textAlign: TextAlign.center, style: CwText.small),
          ]);
        }),
      ],
    );
  }
}

/// C5 · Caregiver: write visit summary (CgSummary.dc.html)
class CgSummaryScreen extends ConsumerStatefulWidget {
  const CgSummaryScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<CgSummaryScreen> createState() => _CgSummaryScreenState();
}

class _CgSummaryScreenState extends ConsumerState<CgSummaryScreen> {
  final _seenBy = TextEditingController();
  final _advice = TextEditingController();
  final _medicines = TextEditingController();
  final _next = TextEditingController();
  final _notes = TextEditingController();
  final List<TextEditingController> _instructions = [TextEditingController()];
  bool _loaded = false;
  bool _busy = false;
  bool _sent = false;

  void _load(Booking b) {
    if (_loaded) return;
    _loaded = true;
    final s = b.summary;
    if (s == null) return;
    _seenBy.text = s.seenBy;
    _advice.text = s.diagnosis;
    _medicines.text = s.medicines;
    _next.text = s.nextAppt;
    _notes.text = s.notes;
    _instructions
      ..clear()
      ..addAll([for (final i in s.instructions) TextEditingController(text: i)]);
    if (_instructions.isEmpty) _instructions.add(TextEditingController());
  }

  Future<void> _send(Booking b) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(careWayApiProvider).submitSummary(b.id, {
        'seenBy': _seenBy.text.trim(),
        'diagnosis': _advice.text.trim(),
        'instructions': [for (final c in _instructions) if (c.text.trim().isNotEmpty) c.text.trim()],
        'nextAppt': _next.text.trim(),
        'medicines': _medicines.text.trim(),
        'notes': _notes.text.trim(),
      });
      setState(() => _sent = true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CwPage(
      title: 'Visit summary',
      children: [
        _bookingView(ref, widget.bookingId, (b) {
          _load(b);
          final first = b.patient.name.split(' ').first;
          if (_sent) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Gap(30),
              const Center(child: Icon(Icons.mark_email_read_outlined, size: 64, color: CwColors.teal)),
              const Text('Summary sent', textAlign: TextAlign.center, style: CwText.h1),
              Text("$first's family can read it now under Past visits.", textAlign: TextAlign.center, style: CwText.muted),
              const Gap(20),
              CwButton(label: 'Back to visit steps', color: CwColors.teal, onPressed: () => context.go('/cg/job/${b.id}/steps')),
              CwButton(label: 'Edit summary', kind: CwButtonKind.text, color: CwColors.teal, onPressed: () => setState(() => _sent = false)),
            ]);
          }
          final valid = _seenBy.text.trim().isNotEmpty && _advice.text.trim().isNotEmpty;
          void changed(String _) => setState(() {});
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${b.patient.name} · ${dayLabel(b.apptAt)}', style: CwText.small),
            const Gap(14),
            LabeledField(label: 'Seen by', controller: _seenBy, hint: 'e.g. Dr Lee, orthopaedic', onChanged: changed),
            const Gap(12),
            LabeledField(label: "Doctor's advice", controller: _advice, maxLines: 3, onChanged: changed,
                hint: 'Knee is improving. Continue physiotherapy twice a week.'),
            const Gap(12),
            LabeledField(label: 'Medicine collected', controller: _medicines, optional: true),
            const Gap(12),
            const Text('Medical instructions', style: CwText.label),
            const SizedBox(height: 6),
            for (final c in _instructions) ...[
              TextField(controller: c, decoration: const InputDecoration(hintText: 'One instruction')),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: () => setState(() => _instructions.add(TextEditingController())),
              child: const Text('+ Add instruction', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            LabeledField(label: 'Next appointment', controller: _next, optional: true, hint: 'e.g. 26 Jan 2027'),
            const Gap(12),
            LabeledField(label: 'Other notes (blood pressure, weight…)', controller: _notes, maxLines: 2, optional: true),
            const Gap(8),
            Text("Only $first's family group can see this summary. Not medical advice.", style: CwText.small),
            const Gap(16),
            CwButton(label: 'Send to family group', color: CwColors.teal, loading: _busy, onPressed: valid ? () => _send(b) : null),
          ]);
        }),
      ],
    );
  }
}
