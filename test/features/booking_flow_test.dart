import 'package:careway/core/router.dart';
import 'package:careway/data/api.dart';
import 'package:careway/data/models/booking.dart';
import 'package:careway/data/models/family.dart';
import 'package:careway/data/models/group.dart';
import 'package:careway/domain/needs.dart';
import 'package:careway/features/booking/booking_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../fakes/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

final apptLocal = appt.toLocal();
final dayKey =
    '${apptLocal.year}-${apptLocal.month.toString().padLeft(2, '0')}-${apptLocal.day.toString().padLeft(2, '0')}';

Group group(String id, int riders, {String point = 'elmina-lakeside', GroupStatus status = GroupStatus.open, DateTime? pickupAt}) => Group(
      id: id,
      hospitalId: 'hsb',
      clinic: 'Orthopaedic specialist clinic',
      date: dayKey,
      pickupPointId: point,
      pickupAt: pickupAt ?? appt.subtract(const Duration(minutes: 75)),
      apptWindow: '8:45–9:30',
      status: status,
      lockAt: appt.subtract(const Duration(hours: 25)),
      caregiverId: 'farid',
      caregiverName: 'Farid A.',
      caregiverRating: 4.9,
      riderBookingIds: [for (var i = 0; i < riders; i++) '$id-r$i'],
      riderInitials: ['SL', 'RK', 'NH'].sublist(0, riders),
    );

/// Draft filled up to step 1 for patient [pid].
void fillDetails(ProviderContainer c, String pid) => c.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
      patientId: pid,
      pickup: const PlaceRef(label: 'Home · 12, Jalan Elmina Lakeside', lat: 3.1885, lng: 101.5165),
      hospitalId: 'hsb',
      clinic: 'Orthopaedic specialist clinic',
      date: DateTime(apptLocal.year, apptLocal.month, apptLocal.day),
      minutes: apptLocal.hour * 60 + apptLocal.minute,
    ));

Finder _filled(String label) => find.widgetWithText(FilledButton, label);

Future<void> _go(WidgetTester tester, ProviderContainer c, String path) async {
  c.read(routerProvider).go(path);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('book requires patient', (tester) async {
    final fakes = guardianFakes(patients: []);
    await pumpApp(tester, fakes, at: '/book', now: now);
    expect(find.text('Save to my family list'), findsOneWidget);
    expect(_filled('Use these details'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('pf-name')), 'Zainab binti Ahmad');
    await tester.enterText(find.byKey(const ValueKey('pf-age')), '72');
    await tester.pump();
    await scrollTo(tester, _filled('Next: choose help'));
    expect(tester.widget<FilledButton>(_filled('Next: choose help')).onPressed, isNull, reason: 'place and time still missing');
    expect(fakes.family.saved, isEmpty);
  });

  /// Fills place and time on step 1 without choosing a patient.
  void fillPlaceAndTime(ProviderContainer c) => c.read(bookingDraftProvider.notifier).update((d) => d.copyWith(
        pickup: const PlaceRef(label: 'Home · 12, Jalan Elmina Lakeside', lat: 3.1885, lng: 101.5165),
        hospitalId: 'hsb',
        clinic: 'Orthopaedic specialist clinic',
        date: DateTime(apptLocal.year, apptLocal.month, apptLocal.day),
        minutes: apptLocal.hour * 60 + apptLocal.minute,
      ));

  for (final keep in [true, false]) {
    testWidgets('Next: choose help saves the new patient (family list ${keep ? 'ticked' : 'unticked'})', (tester) async {
      final fakes = guardianFakes(patients: []);
      final c = await pumpApp(tester, fakes, at: '/book', now: now);
      // Untick before typing: a focused field scrolls itself back into view.
      if (!keep) {
        await scrollTo(tester, find.text('Save to my family list'));
        await tester.tap(find.text('Save to my family list'));
      }
      await tester.enterText(find.byKey(const ValueKey('pf-name')), 'Zainab binti Ahmad');
      await tester.enterText(find.byKey(const ValueKey('pf-age')), '72');
      fillPlaceAndTime(c);
      await tester.pumpAndSettle();
      await scrollTo(tester, _filled('Next: choose help'));
      await tester.tap(_filled('Next: choose help'));
      await tester.pumpAndSettle();
      expect(fakes.family.saved.single.name, 'Zainab binti Ahmad');
      expect(fakes.family.saved.single.inFamilyList, keep);
      expect(c.read(bookingDraftProvider).patientId, isNotNull);
      expect(find.text('Choose help'), findsOneWidget);
    });
  }

  testWidgets('today is bookable and a past day is disabled', (tester) async {
    final morning = DateTime(2026, 10, 17, 10);
    await pumpApp(tester, guardianFakes(), at: '/book', now: morning);
    final local = morning;
    String key(DateTime d) => 'day-${d.year}-${d.month}-${d.day}';
    final today = DateTime(local.year, local.month, local.day);
    final yesterday = DateTime(local.year, local.month, local.day - 1);
    expect(tester.widget<InkWell>(find.byKey(ValueKey(key(today)))).onTap, isNotNull);
    expect(tester.widget<InkWell>(find.byKey(ValueKey(key(yesterday)))).onTap, isNull);
  });

  testWidgets("today's time list only offers slots still ahead", (tester) async {
    final at2pm = DateTime(2026, 10, 17, 14);
    await pumpApp(tester, guardianFakes(), at: '/book', now: at2pm);
    await scrollTo(tester, find.byKey(const ValueKey('day-2026-10-17')));
    await tester.tap(find.byKey(const ValueKey('day-2026-10-17')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Choose a time'));
    await tester.tap(find.text('Choose a time'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('slot-${13 * 60 + 30}')), findsNothing);
    expect(find.byKey(ValueKey('slot-${15 * 60 + 15}')), findsOneWidget);
  });

  testWidgets('today is not bookable after the last slot', (tester) async {
    await pumpApp(tester, guardianFakes(), at: '/book', now: DateTime(2026, 10, 17, 17));
    expect(tester.widget<InkWell>(find.byKey(const ValueKey('day-2026-10-17'))).onTap, isNull);
    expect(tester.widget<InkWell>(find.byKey(const ValueKey('day-2026-10-18'))).onTap, isNotNull);
  });

  testWidgets('calendar stays open after picking a date', (tester) async {
    final morning = DateTime(2026, 10, 17, 10);
    await pumpApp(tester, guardianFakes(), at: '/book', now: morning);
    final local = morning;
    final today = DateTime(local.year, local.month, local.day);
    final header = find.text(DateFormat('MMMM yyyy').format(today));
    expect(header, findsOneWidget);
    await tester.tap(find.byKey(ValueKey('day-${today.year}-${today.month}-${today.day}')));
    await tester.pumpAndSettle();
    expect(header, findsOneWidget);
  });

  testWidgets('group list hides a group whose pickup has passed', (tester) async {
    final fakes = guardianFakes()
      ..group.groups.set([
        group('past', 1, pickupAt: now.subtract(const Duration(minutes: 10))),
        group('soon', 1, pickupAt: now.add(const Duration(hours: 2))),
      ]);
    final c = await pumpApp(tester, fakes, at: '/home', now: now);
    fillDetails(c, 'p1');
    c.read(bookingDraftProvider.notifier).update((d) => d.copyWith(level: 1));
    await _go(tester, c, '/book/groups');
    expect(find.textContaining('1 group going'), findsOneWidget);
  });

  testWidgets('transfer patient cannot pick Level 1', (tester) async {
    const lim = Patient(id: 'p2', name: 'Lim Ah Kow', age: 80, mobility: Mobility.transfer);
    final c = await pumpApp(tester, guardianFakes(patients: [zainab, lim]), at: '/home', now: now);
    fillDetails(c, 'p2');
    await _go(tester, c, '/book/help');
    expect(find.textContaining('Lifting and transfer help needs Level 2'), findsOneWidget);
    expect(tester.widget<InkWell>(find.byKey(const ValueKey('level-1'))).onTap, isNull);
  });

  testWidgets('group with one rider shows the 2-rider price', (tester) async {
    final fakes = guardianFakes()..group.groups.set([group('g1', 1)]);
    final c = await pumpApp(tester, fakes, at: '/home', now: now);
    fillDetails(c, 'p1');
    c.read(bookingDraftProvider.notifier).update((d) => d.copyWith(level: 1));
    await _go(tester, c, '/book/groups');
    expect(find.text('RM 30'), findsOneWidget);
    expect(find.text('Helper: Farid A. · 4.9 ★'), findsOneWidget);
  });

  testWidgets('a full group offers the waitlist', (tester) async {
    final fakes = guardianFakes()..group.groups.set([group('g3', 3, point: 'denai-alam', status: GroupStatus.full)]);
    final c = await pumpApp(tester, fakes, at: '/home', now: now);
    fillDetails(c, 'p1');
    c.read(bookingDraftProvider.notifier).update((d) => d.copyWith(level: 1));
    await _go(tester, c, '/book/groups');
    await tester.tap(find.text('Denai Alam community hall'));
    await tester.pump();
    expect(_filled('Join the waitlist'), findsOneWidget);
  });

  testWidgets('seat taken goes to group not found', (tester) async {
    final fakes = guardianFakes()..group.groups.set([group('g1', 2)]);
    final api = FakeApi()..nextError = const CareWayException('seat-taken', 'The last seat was just taken.');
    final c = await pumpApp(tester, fakes, at: '/home', now: now, api: api);
    fillDetails(c, 'p1');
    c.read(bookingDraftProvider.notifier).update((d) => d.copyWith(level: 1));
    await _go(tester, c, '/book/groups');
    await tester.tap(find.text('Elmina Lakeside pickup bay'));
    await tester.pump();
    await tester.tap(_filled('Request to join'));
    await tester.pumpAndSettle();
    expect(locationOf(c), '/book/not-found?reason=seat-taken');
    final req = api.argsOf('requestBooking').single as Map;
    expect((req['groupId'], req['level']), ('g1', 1));
  });

  testWidgets('request to join goes to pending', (tester) async {
    final fakes = guardianFakes()..group.groups.set([group('g1', 1)]);
    final c = await pumpApp(tester, fakes, at: '/home', now: now);
    fillDetails(c, 'p1');
    c.read(bookingDraftProvider.notifier).update((d) => d.copyWith(level: 1));
    await _go(tester, c, '/book/groups');
    await tester.tap(find.text('Elmina Lakeside pickup bay'));
    await tester.pump();
    await tester.tap(_filled('Request to join'));
    await tester.pumpAndSettle();
    expect(locationOf(c), '/booking/b-new/pending');
  });

  testWidgets('escort review shows the estimate and requests level 2', (tester) async {
    final api = FakeApi();
    final c = await pumpApp(tester, guardianFakes(), at: '/home', now: now, api: api);
    fillDetails(c, 'p1');
    c.read(bookingDraftProvider.notifier).update((d) => d.copyWith(level: 2));
    await _go(tester, c, '/book/escort');
    await scrollTo(tester, find.text('RM 144.00'));
    expect(find.text('RM 144.00'), findsOneWidget);
    await scrollTo(tester, _filled('Find my escort'));
    await tester.tap(_filled('Find my escort'));
    await tester.pumpAndSettle();
    expect((api.argsOf('requestBooking').single as Map)['level'], 2);
  });
}
