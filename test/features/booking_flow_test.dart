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

import '../fakes/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

final apptLocal = appt.toLocal();
final dayKey =
    '${apptLocal.year}-${apptLocal.month.toString().padLeft(2, '0')}-${apptLocal.day.toString().padLeft(2, '0')}';

Group group(String id, int riders, {String point = 'elmina-lakeside', GroupStatus status = GroupStatus.open}) => Group(
      id: id,
      hospitalId: 'hsb',
      clinic: 'Orthopaedic specialist clinic',
      date: dayKey,
      pickupPointId: point,
      pickupAt: appt.subtract(const Duration(minutes: 75)),
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
    final c = await pumpApp(tester, fakes, at: '/book', now: now);
    expect(tester.widget<FilledButton>(_filled('Next: choose help')).onPressed, isNull);
    expect(find.text('Save to my family list'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('pf-name')), 'Zainab binti Ahmad');
    await tester.enterText(find.byKey(const ValueKey('pf-age')), '72');
    await tester.pump();
    await tester.ensureVisible(_filled('Save to my family list'));
    await tester.tap(_filled('Save to my family list'));
    await tester.pumpAndSettle();
    expect(c.read(bookingDraftProvider).patientId, isNotNull);
    expect(fakes.family.saved.single.name, 'Zainab binti Ahmad');
    expect(tester.widget<FilledButton>(_filled('Next: choose help')).onPressed, isNull, reason: 'place and time still missing');
  });

  testWidgets('a date less than 24 hours away is disabled', (tester) async {
    await pumpApp(tester, guardianFakes(), at: '/book', now: now);
    final local = now.toLocal();
    String key(DateTime d) => 'day-${d.year}-${d.month}-${d.day}';
    final tomorrow = DateTime(local.year, local.month, local.day + 1);
    final dayAfter = DateTime(local.year, local.month, local.day + 2);
    expect(tester.widget<InkWell>(find.byKey(ValueKey(key(tomorrow)))).onTap, isNull);
    expect(tester.widget<InkWell>(find.byKey(ValueKey(key(dayAfter)))).onTap, isNotNull);
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
    expect(find.text('RM 144.00'), findsOneWidget);
    await tester.ensureVisible(_filled('Find my escort'));
    await tester.tap(_filled('Find my escort'));
    await tester.pumpAndSettle();
    expect((api.argsOf('requestBooking').single as Map)['level'], 2);
  });
}
