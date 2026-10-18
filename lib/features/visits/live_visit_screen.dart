import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/places.dart';
import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/route_map.dart';
import '../../core/widgets/safety_button.dart';
import '../../core/widgets/status_timeline.dart';
import '../../data/api.dart';
import '../../data/models/booking.dart';
import '../../data/models/firestore_utils.dart' show initialsOf;
import '../../data/providers.dart';
import '../../domain/booking_status.dart';
import '../../domain/pricing.dart' show haversineKm;
import '../home/home_screen.dart' show placeName, levelLabel, levelTone;
import 'rate_sheet.dart';

/// Timeline rows for a booking's visit steps.
List<TimelineStep> visitTimeline(Booking b) {
  final keys = b.stepKeys;
  return [
    for (var i = 0; i < keys.length; i++)
      TimelineStep(
        stepLabels[keys[i]]!,
        i < b.steps.length ? b.steps[i].at : null,
        i < b.steps.length ? TimelineState.done : (i == b.steps.length && b.status != BookingStatus.completed ? TimelineState.current : TimelineState.upcoming),
      ),
  ];
}

/// Opens the phone dialer; shows a snackbar if that isn't possible (e.g. web).
Future<void> callNumber(BuildContext context, String number) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(Uri(scheme: 'tel', path: number.replaceAll(' ', ''))).catchError((_) => false);
  if (!ok) messenger.showSnackBar(SnackBar(content: Text('Call $number')));
}

Place? _place(String id) {
  try {
    return placeById(id);
  } catch (_) {
    return null;
  }
}

/// 10 · Visit day (Group) and 19 · Visit day (Personal).
class LiveVisitScreen extends ConsumerWidget {
  const LiveVisitScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return Scaffold(
      backgroundColor: CwColors.surface,
      body: AsyncView<Booking?>(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        isEmpty: (b) => b == null,
        empty: const SafeArea(child: EmptyState(icon: Icons.search_off, title: 'Visit not found')),
        data: (b) => _Body(b!),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body(this.b);
  final Booking b;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  Future<void> _rideHome() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(careWayApiProvider).requestRideHome(widget.b.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final group = b.level == 1;
    final accent = group ? CwColors.primary : CwColors.teal;
    final first = b.patient.name.split(' ').first;
    final done = b.status == BookingStatus.completed;
    final lastKey = b.steps.isEmpty ? null : b.steps.last.key;
    final rideCalled = b.rideRequestedAt != null || lastKey == 'ride_home' || lastKey == 'home';
    final today = DateUtils.isSameDay(b.apptAt.toLocal(), ref.watch(clockProvider)());

    final hospital = _place(b.hospitalId);
    final km = hospital == null || (b.pickup.lat == 0 && b.pickup.lng == 0)
        ? null
        : haversineKm(b.pickup.lat, b.pickup.lng, hospital.lat, hospital.lng) * 1.3;
    final pickupLabel = b.pickup.label.isEmpty ? 'Pickup' : b.pickup.label;

    final (statusText, statusTone) = switch (lastKey) {
      _ when done => ('Home safe', (CwColors.successSoft, const Color(0xFF1D6B45))),
      null => ('Pickup ${timeLabel(b.pickupAt ?? b.apptAt.subtract(const Duration(hours: 1)))}', (CwColors.lilac, CwColors.primaryDark)),
      'picked_up' => ('On the way', (CwColors.tealSoft, CwColors.tealDark)),
      'with_doctor' => ('With doctor', group ? (CwColors.amberSoft, CwColors.amber) : (CwColors.tealSoft, CwColors.tealDark)),
      'pharmacy' => ('At pharmacy', group ? (CwColors.amberSoft, CwColors.amber) : (CwColors.tealSoft, CwColors.tealDark)),
      'ride_home' => ('Heading home', (CwColors.tealSoft, CwColors.tealDark)),
      _ => (rideCalled ? 'Heading home' : 'At hospital',
          rideCalled ? (CwColors.tealSoft, CwColors.tealDark) : (group ? (CwColors.amberSoft, CwColors.amber) : (CwColors.tealSoft, CwColors.tealDark))),
    };

    String? note(String key, bool reached) {
      if (!group) return null;
      return switch (key) {
        'picked_up' when reached => pickupLabel,
        'ride_home' when !reached && !rideCalled => 'Tap Ready for pickup when $first has the medicine.',
        'ride_home' when !reached && rideCalled => '${b.caregiverName ?? 'The helper'} will meet $first at the pharmacy and walk to the van.',
        _ => null,
      };
    }

    final keys = b.stepKeys;
    final v = b.caregiverVehicle;
    final mapsUrl = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': b.pickup.lat != 0 ? '${b.pickup.lat},${b.pickup.lng}' : pickupLabel,
      'destination': placeName(b.hospitalId),
      'travelmode': 'driving',
    });

    return Column(children: [
      SizedBox(
        height: 300 + MediaQuery.paddingOf(context).top,
        child: Stack(fit: StackFit.expand, children: [
          RouteMap(
            origin: pickupLabel,
            originArea: 'Pickup',
            dest: placeName(b.hospitalId),
            destArea: hospital?.area ?? '',
            semanticLabel: 'Map: route from $pickupLabel to ${placeName(b.hospitalId)}${km == null ? '' : ', about ${km.round()} km'}',
          ),
          SafeArea(
            bottom: false,
            child: Stack(children: [
              if (km != null)
                Positioned(
                  top: 22,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: CwColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Color(0x4D3C4043), blurRadius: 4, offset: Offset(0, 1))],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${(km / 45 * 60).round()} min', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF188038))),
                        Text('${km.round()} km · estimated', style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368))),
                      ]),
                    ),
                  ),
                ),
              Positioned(
                left: 20,
                top: 20,
                child: _MapButton(
                  label: 'Back',
                  onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                  child: const CwIcon(CwIcons.back, size: 20, strokeWidth: 2.4),
                ),
              ),
              Positioned(
                right: 20,
                top: 20,
                child: _MapButton(
                  label: 'Help and safety',
                  onTap: () => showHelpSheet(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      CwIcon(CwIcons.shield, size: 18, strokeWidth: 2.2, color: CwColors.pink),
                      SizedBox(width: 6),
                      Text('Help', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CwColors.pink)),
                    ]),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 40,
                child: Material(
                  color: CwColors.white,
                  shape: const StadiumBorder(),
                  elevation: 1,
                  shadowColor: const Color(0x4D3C4043),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => launchUrl(mapsUrl, mode: LaunchMode.externalApplication).catchError((_) => false),
                    child: const SizedBox(
                      height: 40,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          CwIcon('<path d="M12 2 4 20l8-4 8 4z"/>', size: 16, strokeWidth: 2.4, color: Color(0xFF1A73E8)),
                          SizedBox(width: 6),
                          Text('Open in Google Maps', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A73E8))),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: Transform.translate(
          offset: const Offset(0, -24),
          child: Container(
            decoration: const BoxDecoration(
              color: CwColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 44),
              children: [
                Center(
                  child: Container(width: 44, height: 5, decoration: BoxDecoration(color: CwColors.line, borderRadius: BorderRadius.circular(3))),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  CircleAvatarText(b.patient.initials, size: 48, tone: personTone(0), fontSize: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("$first's visit ${today ? 'today' : dayLabel(b.apptAt)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text.rich(TextSpan(style: const TextStyle(fontSize: 13, color: CwColors.muted), children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: levelTone(b.level).$1, borderRadius: BorderRadius.circular(6)),
                            child: Text(levelLabel(b.level), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: levelTone(b.level).$2)),
                          ),
                        ),
                        TextSpan(text: ' ${placeName(b.hospitalId)}${b.caregiverName == null ? '' : ' · ${b.caregiverName}'}'),
                      ])),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: statusTone.$1, borderRadius: BorderRadius.circular(8)),
                    child: Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusTone.$2)),
                  ),
                ]),
                if (v != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: CwColors.surface, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      if (group) ...[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: CwColors.lilac, borderRadius: BorderRadius.circular(12)),
                          child: const Center(
                            child: CwIcon(
                              '<path d="M3 16V8a2 2 0 0 1 2-2h10l4 4h1a1 1 0 0 1 1 1v5"/><path d="M3 16h18"/><circle cx="7.5" cy="17.5" r="1.8"/><circle cx="16.5" cy="17.5" r="1.8"/>',
                              size: 22,
                              strokeWidth: 2.2,
                              color: CwColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(v.model, style: const TextStyle(fontSize: 12, color: CwColors.muted)),
                          const SizedBox(height: 2),
                          Text(
                            v.driver.isNotEmpty
                                ? 'Driver ${v.driver}${b.caregiverName == null ? '' : ' · with ${b.caregiverName}'}'
                                : 'Driven by ${b.caregiverName ?? 'your helper'}',
                            style: const TextStyle(fontSize: 12, color: CwColors.muted),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: CwColors.ink, borderRadius: BorderRadius.circular(8)),
                        child: Text(v.plate,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1, color: CwColors.white, fontFeatures: [FontFeature.tabularFigures()])),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
                for (var i = 0; i < keys.length; i++)
                  _StepRow(
                    title: stepLabels[keys[i]]!,
                    time: i < b.steps.length
                        ? timeLabel(b.steps[i].at)
                        : (group && keys[i] == 'ride_home' && i == b.steps.length ? (rideCalled ? 'Requested' : 'Waiting') : ''),
                    note: note(keys[i], i < b.steps.length),
                    state: i < b.steps.length
                        ? TimelineState.done
                        : (i == b.steps.length && !done ? TimelineState.current : TimelineState.upcoming),
                    last: i == keys.length - 1,
                    accent: accent,
                    ring: group ? CwColors.lilacLine : const Color(0xFFB9DDE6),
                  ),
                if (group && !done) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Semantics(
                      button: true,
                      label: 'Call helper',
                      excludeSemantics: true,
                      child: Material(
                        color: CwColors.lilac,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: (b.caregiverPhone ?? '').isEmpty ? null : () => callNumber(context, b.caregiverPhone!),
                          child: const SizedBox(
                            width: 56,
                            height: 56,
                            child: Center(child: CwIcon(CwIcons.phone, size: 22, strokeWidth: 2.2, color: CwColors.primaryDark)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: rideCalled || _busy || b.steps.isEmpty ? null : _rideHome,
                          style: FilledButton.styleFrom(
                            backgroundColor: CwColors.primary,
                            foregroundColor: CwColors.white,
                            disabledBackgroundColor: rideCalled ? CwColors.tealSoft : CwColors.line,
                            disabledForegroundColor: rideCalled ? CwColors.tealDark : CwColors.muted,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            textStyle: const TextStyle(fontFamily: cwFont, fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          child: Text(rideCalled ? 'Ride home is on its way' : 'Ready for pickup'),
                        ),
                      ),
                    ),
                  ]),
                ],
                if (done) ...[
                  const SizedBox(height: 10),
                  if (b.rating == null)
                    TextButton(
                      onPressed: () => RateSheet.show(
                        context,
                        title: "How was $first's visit?",
                        subtitle: 'Rate ${b.caregiverName ?? 'your helper'}${group ? ' and the ride' : ''}',
                        initials: initialsOf(b.caregiverName ?? '?'),
                        privacyNote: "Shared with CareWay and ${b.caregiverName?.split(' ').first ?? 'the helper'}'s partner agency only.",
                        onSubmit: (r) => ref.read(bookingRepoProvider).rate(b.id, r),
                      ),
                      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44), foregroundColor: CwColors.primary),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Home safe? Rate this visit', style: TextStyle(fontFamily: cwFont, fontSize: 15, fontWeight: FontWeight.w800)),
                        SizedBox(width: 6),
                        CwIcon(CwIcons.chevronRight, size: 16, strokeWidth: 2.4, color: CwColors.primary),
                      ]),
                    )
                  else
                    Text('You rated ${b.rating!.stars} ★', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CwColors.muted)),
                ],
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.label, required this.onTap, required this.child});
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: CwColors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 44, minHeight: 44), child: Center(widthFactor: 1, child: child)),
          ),
        ),
      );
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.title,
    required this.time,
    required this.note,
    required this.state,
    required this.last,
    required this.accent,
    required this.ring,
  });
  final String title;
  final String time;
  final String? note;
  final TimelineState state;
  final bool last;
  final Color accent;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final isDone = state == TimelineState.done;
    final isNow = state == TimelineState.current;
    final Widget dot = isDone
        ? Container(width: 18, height: 18, decoration: BoxDecoration(color: accent, shape: BoxShape.circle))
        : isNow
            ? Container(width: 20, height: 20, decoration: BoxDecoration(color: CwColors.white, shape: BoxShape.circle, border: Border.all(color: accent, width: 4)))
            : Container(width: 14, height: 14, decoration: BoxDecoration(color: CwColors.white, shape: BoxShape.circle, border: Border.all(color: ring, width: 2)));
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 22,
          child: Column(children: [
            dot,
            if (!last) Expanded(child: Container(width: 2, constraints: const BoxConstraints(minHeight: 20), color: isDone ? accent : CwColors.line)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(fontSize: 14, fontWeight: isNow ? FontWeight.w800 : FontWeight.w700, color: isDone || isNow ? CwColors.ink : const Color(0xFF8E8AA3))),
                  ),
                  const SizedBox(width: 8),
                  Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CwColors.muted)),
                ]),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: const TextStyle(fontSize: 12, height: 1.4, color: CwColors.muted)),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
