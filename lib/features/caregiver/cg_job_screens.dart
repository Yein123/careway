import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/design_kit.dart';
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

/// Teal header used by the caregiver job screens.
class _TealHeader extends StatelessWidget {
  const _TealHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        color: CwColors.teal,
        padding: EdgeInsets.fromLTRB(20, 20 + MediaQuery.paddingOf(context).top, 20, 20),
        child: Row(children: [
          Semantics(
            button: true,
            label: 'Back',
            excludeSemantics: true,
            child: Material(
              color: const Color(0x2EFFFFFF),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.canPop() ? context.pop() : context.go('/cg'),
                child: const SizedBox(width: 44, height: 44, child: Center(child: CwIcon(CwIcons.back, size: 20, strokeWidth: 2.4, color: CwColors.white))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: CwColors.white)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF))),
            ]),
          ),
        ]),
      );
}

/// Caregiver page: teal header, scrolling body, optional white bottom bar.
class _CgPage extends StatelessWidget {
  const _CgPage({required this.header, required this.body, this.bottom});
  final Widget header;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: CgColors.surface,
        body: Column(children: [
          header,
          Expanded(child: body),
          if (bottom != null) SafeArea(top: false, child: BottomBar(child: bottom!)),
        ]),
      );
}

Widget _loading(WidgetRef ref, String id, Widget Function(Booking) data) => AsyncView<Booking?>(
      value: ref.watch(bookingProvider(id)),
      onRetry: () => ref.invalidate(bookingProvider(id)),
      isEmpty: (b) => b == null,
      empty: const SafeArea(child: EmptyState(icon: Icons.search_off, title: 'Job not found')),
      data: (b) => data(b!),
    );

Widget _pill(String text, {bool alert = false}) => Tag(
      text,
      background: alert ? CwColors.pinkSoft : CgColors.soft,
      color: alert ? const Color(0xFFA02A4C) : CwColors.tealDark,
      fontSize: 12,
    );

List<Widget> _careTags(Booking b, Patient? p) => [
      if (b.patient.allergy.isNotEmpty) _pill('Allergy: ${b.patient.allergy}', alert: true),
      _pill(b.patient.mobility.label),
      for (final e in p?.extraHelp ?? const <String>[]) _pill(e),
      for (final a in b.addons) _pill(a.label),
      if (b.language != null && b.language!.isNotEmpty) _pill(b.language!),
    ];

Widget _callButton(BuildContext context, String name, String phone) => Semantics(
      button: true,
      label: 'Call $name',
      excludeSemantics: true,
      child: Material(
        color: CgColors.soft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => callNumber(context, phone),
          child: const SizedBox(width: 44, height: 44, child: Center(child: CwIcon(CwIcons.phone, size: 18, strokeWidth: 2.2, color: CwColors.tealDark))),
        ),
      ),
    );

/// C3 · Caregiver: job details (CgJob.dc.html)
class CgJobScreen extends ConsumerWidget {
  const CgJobScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(bookingProvider(bookingId)).value;
    final active = b != null && (b.status == BookingStatus.confirmed || b.status == BookingStatus.inProgress);
    return _CgPage(
      header: _TealHeader(
        title: 'Job details',
        subtitle: b == null ? '' : '${bookingRef(b.id)} · ${b.level == 1 ? 'Group helper' : 'Personal escort'}',
      ),
      bottom: active ? BigButton(label: 'Open visit steps', color: CwColors.teal, height: 58, onPressed: () => context.push('/cg/job/${b.id}/steps')) : null,
      body: _loading(ref, bookingId, (b) {
        final p = ref.watch(_jobPatientProvider((b.familyId, b.patientId))).value;
        const k = TextStyle(fontSize: 13, color: CgColors.muted);
        const v = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CgColors.ink);
        final rows = [
          if (b.pickupAt != null) ('Pickup', '${timeLabel(b.pickupAt!)} · ${b.pickup.label}'),
          ('Appointment', '${dayTimeLabel(b.apptAt)} · ${placeName(b.hospitalId)}'),
          if (b.clinic.isNotEmpty) ('Clinic', b.clinic),
          ('Booked for', b.level == 1 ? 'Shared ride with the group' : 'About 4 hours'),
        ];
        final notes = [if ((p?.conditions ?? '').isNotEmpty) p!.conditions, if (b.patient.talkNotes.isNotEmpty) b.patient.talkNotes].join(' ');
        final contacts = <(String, String, String)>[
          for (final c in p?.contacts ?? const <Contact>[]) ('${c.name} · ${c.role.toLowerCase()}', c.phone, c.name),
          if ((p?.phone ?? '').isNotEmpty) ('${b.patient.name.split(' ').first} · patient', p!.phone, b.patient.name.split(' ').first),
        ];
        return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: CwColors.pinkSoft, shape: BoxShape.circle),
                  child: Text(b.patient.initials, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CwColors.pink)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${b.patient.name}, ${b.patient.age}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CgColors.ink)),
                    if (b.caregiverLanguages.isNotEmpty || (b.language ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('${levelLabel(b.level)} visit', style: const TextStyle(fontSize: 12, color: CgColors.muted)),
                    ],
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: _careTags(b, p)),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: CgColors.surface, borderRadius: BorderRadius.circular(10)),
                  child: Text(notes, style: const TextStyle(fontSize: 12, height: 1.5, color: CgColors.ink2)),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: CgColors.divider))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rows[i].$1, style: k),
                    const SizedBox(width: 12),
                    Expanded(child: Text(rows[i].$2, textAlign: TextAlign.right, style: v)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => launchUrl(
                Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${b.pickup.lat},${b.pickup.lng}&travelmode=driving'),
                mode: LaunchMode.externalApplication,
              ).catchError((_) => false),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
                backgroundColor: CwColors.white,
                side: const BorderSide(color: CgColors.line, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontFamily: cwFont, fontSize: 15, fontWeight: FontWeight.w800),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                CwIcon('<path d="M12 2 4 20l8-4 8 4z"/>', size: 18, strokeWidth: 2.4, color: Color(0xFF1A73E8)),
                SizedBox(width: 8),
                Text('Directions to pickup'),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Family contacts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: CgColors.ink)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              if (contacts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    active ? 'Booked by ${b.guardianName.isEmpty ? 'the family' : b.guardianName}.' : 'Contacts show once the visit is confirmed.',
                    style: const TextStyle(fontSize: 13, color: CgColors.muted),
                  ),
                ),
              for (var i = 0; i < contacts.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: i == contacts.length - 1 ? null : const Border(bottom: BorderSide(color: CgColors.divider))),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(contacts[i].$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: CgColors.ink)),
                        const SizedBox(height: 2),
                        Text(contacts[i].$2, style: const TextStyle(fontSize: 12, color: CgColors.muted)),
                      ]),
                    ),
                    _callButton(context, contacts[i].$3, contacts[i].$2),
                  ]),
                ),
            ]),
          ),
          if (b.status == BookingStatus.awaitingPayment) ...[
            const SizedBox(height: 16),
            const Text('Waiting for the family to pay. It becomes a confirmed job once they do.', style: TextStyle(fontSize: 13, color: CgColors.muted)),
          ],
        ]);
      }),
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
    final b = ref.watch(bookingProvider(widget.bookingId)).value;
    final profile = ref.watch(caregiverProfileProvider).value;
    final done = b?.status == BookingStatus.completed;
    final next = b?.nextStepKey;
    final needsSummary = b != null && (b.level == 2 || b.addons.any((a) => a.name == 'visitSummary'));
    final p = b == null ? null : ref.watch(_jobPatientProvider((b.familyId, b.patientId))).value;
    final family = p?.contacts.where((c) => c.phone.isNotEmpty).firstOrNull;

    return _CgPage(
      header: Container(
        color: CwColors.teal,
        padding: EdgeInsets.fromLTRB(20, 20 + MediaQuery.paddingOf(context).top, 20, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            InkWell(
              onTap: () => context.canPop() ? context.pop() : context.go('/cg/job/${widget.bookingId}'),
              child: const SizedBox(
                height: 32,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CwIcon(CwIcons.back, size: 18, strokeWidth: 2.4, color: CwColors.white),
                  SizedBox(width: 4),
                  Text('Job details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CwColors.white)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            const Spacer(),
            if (profile != null)
              Flexible(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(8)),
                  child: Text('${profile.onDuty ? 'On duty' : 'Off duty'} · ${profile.displayName}',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: CwColors.white)),
                ),
              ),
          ]),
          if (b != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: CwColors.white, shape: BoxShape.circle),
                child: Text(b.patient.initials, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CwColors.pink)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${b.patient.name}, ${b.patient.age}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CwColors.white)),
                  const SizedBox(height: 2),
                  Text('${levelLabel(b.level)} · ${placeName(b.hospitalId)}${b.clinic.isEmpty ? '' : ' · ${b.clinic}'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF))),
                ]),
              ),
            ]),
          ],
        ]),
      ),
      bottom: b == null
          ? null
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!done && next != null)
                BigButton(label: 'Mark done: ${stepLabels[next]}', color: CwColors.teal, height: 58, loading: _busy, onPressed: () => _advance(b)),
              if ((done || next == null || needsSummary) && (needsSummary || b.summary != null)) ...[
                if (!done && next != null) const SizedBox(height: 8),
                done || next == null
                    ? BigButton(
                        label: b.summary == null ? 'Write visit summary' : 'Edit visit summary',
                        color: CwColors.teal,
                        height: 58,
                        onPressed: () => context.push('/cg/job/${b.id}/summary'),
                      )
                    : LinkButton(
                        label: b.summary == null ? 'Write visit summary' : 'Edit visit summary',
                        color: CwColors.teal,
                        height: 40,
                        fontSize: 13,
                        onPressed: () => context.push('/cg/job/${b.id}/summary'),
                      ),
              ],
              if (done && !needsSummary && b.summary == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Visit complete. Thank you!', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CgColors.ink)),
                ),
              Row(children: [
                const Expanded(
                  child: Text('The family gets a notification at each step.', style: TextStyle(fontSize: 12, color: CgColors.muted)),
                ),
                if (family != null)
                  TextButton(
                    onPressed: () => callNumber(context, family.phone),
                    style: TextButton.styleFrom(foregroundColor: CwColors.primary, padding: const EdgeInsets.symmetric(horizontal: 4)),
                    child: Text('Call ${family.name.split(' ').first} (family)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ]),
      body: _loading(ref, widget.bookingId, (b) {
        final timeline = visitTimeline(b);
        return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
          if (b.rideRequestedAt != null && !b.steps.any((s) => s.key == 'ride_home')) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: CwColors.amberSoft, borderRadius: BorderRadius.circular(16)),
              child: Text('${b.patient.name.split(' ').first} is ready for pickup (since ${timeLabel(b.rideRequestedAt!)}). Meet them at the pharmacy.',
                  style: const TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w700, color: CwColors.amber)),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: CwColors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('BEFORE YOU START', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: CgColors.muted)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: _careTags(b, ref.watch(_jobPatientProvider((b.familyId, b.patientId))).value)),
              if (b.patient.talkNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(b.patient.talkNotes, style: const TextStyle(fontSize: 12, height: 1.5, color: CgColors.ink2)),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            const Expanded(child: Text('Visit steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CgColors.ink))),
            Text('${b.steps.length} of ${b.stepKeys.length} done', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CgColors.muted)),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ColoredBox(
              color: CwColors.white,
              child: Column(children: [
                for (var i = 0; i < timeline.length; i++)
                  Builder(builder: (_) {
                    final s = timeline[i];
                    final isDone = s.state.name == 'done';
                    final isNow = s.state.name == 'current';
                    return Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isNow ? CgColors.soft : null,
                        border: i == 0 ? null : const Border(top: BorderSide(color: CgColors.divider)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone ? CwColors.teal : CwColors.white,
                            border: isDone ? null : Border.all(color: isNow ? CwColors.teal : const Color(0xFFC7D9DE), width: isNow ? 3 : 2),
                          ),
                          child: isDone ? const Center(child: CwIcon(CwIcons.check, size: 14, strokeWidth: 3.4, color: CwColors.white)) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s.label,
                              style: TextStyle(fontSize: 15, fontWeight: isNow ? FontWeight.w800 : FontWeight.w700, color: isDone || isNow ? CgColors.ink : CgColors.faint)),
                        ),
                        Text(s.at != null ? timeLabel(s.at!) : (isNow ? 'Now' : ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CgColors.muted)),
                      ]),
                    );
                  }),
              ]),
            ),
          ),
        ]);
      }),
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
  final _bp = TextEditingController();
  final _weight = TextEditingController();
  final _advice = TextEditingController();
  final _medicines = TextEditingController();
  final _next = TextEditingController();
  final List<TextEditingController> _instructions = [TextEditingController()];
  String _seenBy = '';
  String _otherNotes = '';
  bool _loaded = false;
  bool _busy = false;
  bool _sent = false;

  static final _bpPattern = RegExp(r'BP ([^·]+?)(?: · |$)');
  static final _wtPattern = RegExp(r'weight ([\d.]+) kg');

  void _load(Booking b) {
    if (_loaded) return;
    _loaded = true;
    final s = b.summary;
    if (s == null) return;
    _seenBy = s.seenBy;
    _advice.text = s.diagnosis;
    _medicines.text = s.medicines;
    _next.text = s.nextAppt;
    _bp.text = _bpPattern.firstMatch(s.notes)?.group(1)?.trim() ?? '';
    _weight.text = _wtPattern.firstMatch(s.notes)?.group(1) ?? '';
    _otherNotes = s.notes.replaceAll(_bpPattern, '').replaceAll(_wtPattern, '').replaceAll(RegExp(r'^[ ·]+|[ ·]+$'), '');
    _instructions
      ..clear()
      ..addAll([for (final i in s.instructions) TextEditingController(text: i)]);
    if (_instructions.isEmpty) _instructions.add(TextEditingController());
  }

  Future<void> _send(Booking b) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final notes = [
      if (_bp.text.trim().isNotEmpty) 'BP ${_bp.text.trim()}',
      if (_weight.text.trim().isNotEmpty) 'weight ${_weight.text.trim()} kg',
      if (_otherNotes.isNotEmpty) _otherNotes,
    ].join(' · ');
    try {
      await ref.read(careWayApiProvider).submitSummary(b.id, {
        'seenBy': _seenBy,
        'diagnosis': _advice.text.trim(),
        'instructions': [for (final c in _instructions) if (c.text.trim().isNotEmpty) c.text.trim()],
        'nextAppt': _next.text.trim(),
        'medicines': _medicines.text.trim(),
        'notes': notes,
      });
      setState(() => _sent = true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, TextEditingController c, {int lines = 1, String? hint, TextInputType? type, Key? key}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CgColors.ink)),
          const SizedBox(height: 6),
          _input(c, lines: lines, hint: hint, type: type, key: key),
        ],
      );

  Widget _input(TextEditingController c, {int lines = 1, String? hint, TextInputType? type, Key? key}) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 2));
    return TextField(
      key: key,
      controller: c,
      minLines: lines,
      maxLines: lines,
      keyboardType: type,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 14, height: 1.45, color: CgColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: border(CgColors.line),
        border: border(CgColors.line),
        focusedBorder: border(CwColors.teal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = ref.watch(bookingProvider(widget.bookingId)).value;
    if (b != null) _load(b);
    final first = b?.patient.name.split(' ').first ?? 'the patient';
    final valid = _advice.text.trim().isNotEmpty;
    return _CgPage(
      header: _TealHeader(title: 'Visit summary', subtitle: b == null ? '' : '${b.patient.name} · ${dayLabel(b.apptAt)}'),
      bottom: b == null || _sent
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              BigButton(label: 'Send to family group', color: CwColors.teal, height: 58, loading: _busy, onPressed: valid ? () => _send(b) : null),
              const SizedBox(height: 6),
              Text("Only $first's family group can see this summary.", style: const TextStyle(fontSize: 11, color: CgColors.muted)),
            ]),
      body: _loading(ref, widget.bookingId, (b) {
        if (_sent) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(color: CwColors.tealSoft, shape: BoxShape.circle),
                  child: const Center(child: CwIcon(CwIcons.check, size: 40, strokeWidth: 2.8, color: CwColors.teal)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Summary sent', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CgColors.ink)),
              const SizedBox(height: 12),
              Text("$first's family can read it now under Past visits.",
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.5, color: CgColors.muted)),
              const SizedBox(height: 20),
              BigButton(label: 'Back to today', color: CwColors.teal, fontSize: 16, onPressed: () => context.go('/cg')),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _sent = false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CwColors.teal,
                      backgroundColor: CwColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      side: const BorderSide(color: CgColors.line, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontFamily: cwFont, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    child: const Text('Edit summary'),
                  ),
                ),
              ),
            ]),
          );
        }
        return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
          Row(children: [
            Expanded(child: _field('Blood pressure', _bp, hint: 'e.g. 132/84')),
            const SizedBox(width: 10),
            Expanded(child: _field('Weight (kg)', _weight, hint: 'e.g. 61', type: const TextInputType.numberWithOptions(decimal: true))),
          ]),
          const SizedBox(height: 16),
          _field("Doctor's advice", _advice, lines: 2, hint: 'Knee is improving. Continue physiotherapy twice a week.', key: const ValueKey('cs-advice')),
          const SizedBox(height: 16),
          _field('Medicine collected', _medicines, hint: 'e.g. Paracetamol 500 mg, knee support'),
          const SizedBox(height: 16),
          const Text('Medical instructions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CgColors.ink)),
          for (var i = 0; i < _instructions.length; i++) ...[
            const SizedBox(height: 6),
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: CwColors.teal, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: _input(_instructions[i], hint: 'Add an instruction')),
            ]),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _instructions.add(TextEditingController())),
              style: TextButton.styleFrom(foregroundColor: CwColors.teal, padding: const EdgeInsets.symmetric(vertical: 4)),
              child: const Text('+ Add instruction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          _field('Next appointment', _next, hint: 'e.g. Mon 25 Jan 2027, 9:00 AM'),
          const SizedBox(height: 12),
          const Text('Not medical advice. Write what the doctor said.', style: TextStyle(fontSize: 11, color: CgColors.muted)),
        ]);
      }),
    );
  }
}
