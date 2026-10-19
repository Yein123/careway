import 'dart:async';

import 'package:careway/core/router.dart';
import 'package:careway/data/models/booking.dart';
import 'package:careway/data/models/group.dart';
import 'package:careway/domain/booking_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_repos.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

Group _group(int riders) => Group(
      id: 'grp',
      hospitalId: 'hsb',
      clinic: 'Orthopaedic specialist clinic',
      date: '2026-10-26',
      pickupPointId: 'elmina-lakeside',
      pickupAt: appt.subtract(const Duration(minutes: 75)),
      apptWindow: '8:45–9:30',
      status: GroupStatus.open,
      lockAt: appt.subtract(const Duration(hours: 25)),
      caregiverId: 'cg1',
      caregiverName: 'Farid A.',
      riderBookingIds: [for (var i = 0; i < riders; i++) 'r$i'],
      riderInitials: ['SL', 'RK'].sublist(0, riders),
    );

Fakes _fakes(Booking b, {int riders = 1}) => guardianFakes(bookings: [b])..group.groups.set([_group(riders)]);

Finder _filled(String label) => find.widgetWithText(FilledButton, label);

void main() {
  testWidgets('pending moves to the package screen when accepted (level 1)', (tester) async {
    final b = booking(status: BookingStatus.pendingCaregiver, caregiverName: null, offerCaregiverName: 'Farid A.', offerExpiresAt: now.add(const Duration(minutes: 18)));
    final fakes = _fakes(b);
    final c = await pumpApp(tester, fakes, at: '/booking/b1/pending', now: now);
    expect(find.textContaining('Waiting for Farid A. to accept'), findsOneWidget);
    fakes.booking.put(booking(status: BookingStatus.awaitingPayment));
    await tester.pumpAndSettle();
    expect(locationOf(c), '/booking/b1/package');
  });

  testWidgets('one-to-one escort is accepted for the caregiver after 10 seconds', (tester) async {
    final api = FakeApi();
    final b = booking(
      status: BookingStatus.pendingCaregiver,
      level: 2,
      caregiverName: null,
      offerCaregiverName: 'Nurul H.',
      offerExpiresAt: now.add(const Duration(minutes: 18)),
    );
    await pumpApp(tester, _fakes(b), at: '/booking/b1/pending', now: now, api: api);
    await tester.pump(const Duration(seconds: 9));
    expect(api.argsOf('autoAcceptBooking'), isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(api.argsOf('autoAcceptBooking'), ['b1']);
  });

  testWidgets('group requests are not accepted automatically', (tester) async {
    final api = FakeApi();
    final b = booking(status: BookingStatus.pendingCaregiver, caregiverName: null, offerCaregiverName: 'Farid A.', offerExpiresAt: now.add(const Duration(minutes: 18)));
    await pumpApp(tester, _fakes(b), at: '/booking/b1/pending', now: now, api: api);
    await tester.pump(const Duration(seconds: 15));
    expect(api.argsOf('autoAcceptBooking'), isEmpty);
  });

  testWidgets('pending moves to not found when no caregiver', (tester) async {
    final fakes = _fakes(booking(status: BookingStatus.pendingCaregiver, caregiverName: null));
    final c = await pumpApp(tester, fakes, at: '/booking/b1/pending', now: now);
    fakes.booking.put(booking(status: BookingStatus.notMatched, caregiverName: null, notMatchedReason: 'helper-declined'));
    await tester.pumpAndSettle();
    expect(locationOf(c), '/booking/b1/not-found');
    expect(find.textContaining('Nothing has been charged.'), findsOneWidget);
  });

  testWidgets('package total: Saver + language + consult sit-in, 1 rider already', (tester) async {
    final b = booking(
      status: BookingStatus.awaitingPayment,
      caregiverSkills: const ['wheelchair', 'consultSitIn'],
      caregiverLanguages: const ['Tamil', 'English'],
    );
    await pumpApp(tester, _fakes(b), at: '/booking/b1/package', now: now);
    expect(find.text('RM 30'), findsOneWidget, reason: 'Saver share for 2 riders');
    await scrollTo(tester, find.text('Language help'));
    await tester.tap(find.text('Language help'));
    await tester.pump();
    await scrollTo(tester, find.text('Consult sit-in'));
    await tester.tap(find.text('Consult sit-in'));
    await tester.pump();
    expect(find.text('RM 48.00'), findsOneWidget);
  });

  testWidgets('every add-on is offered and language help takes a typed language', (tester) async {
    final b = booking(status: BookingStatus.awaitingPayment, caregiverSkills: const ['wheelchair']);
    final c = await pumpApp(tester, _fakes(b), at: '/booking/b1/package', now: now);
    expect(find.text('Lowest price'), findsOneWidget);
    expect(find.text('Less waiting'), findsOneWidget);
    await scrollTo(tester, find.text('Consult sit-in'));
    await tester.tap(find.text('Consult sit-in'));
    await tester.pump();
    expect(find.text('RM 40.00'), findsOneWidget, reason: 'sit-in added');
    await scrollTo(tester, find.text('Language help'));
    await tester.tap(find.text('Language help'));
    await tester.pump();
    expect(find.text('Tamil'), findsNothing);
    await tester.tap(find.text('Continue to payment'));
    await tester.pump();
    expect(locationOf(c), '/booking/b1/package', reason: 'language not typed yet');
    await scrollTo(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Telugu');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation, '/booking/b1/pay');
  });

  testWidgets('pay shows a spinner and ignores a second tap', (tester) async {
    final api = FakeApi()..payGate = Completer<void>();
    final c = await pumpApp(tester, _fakes(booking(status: BookingStatus.awaitingPayment, level: 2, groupId: null)),
        at: '/booking/b1/pay', now: now, api: api);
    expect(find.text('Pay RM 144.00'), findsOneWidget);
    await tester.ensureVisible(_filled('Pay RM 144.00'));
    await tester.tap(_filled('Pay RM 144.00'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
    await tester.pump();
    expect(api.argsOf('payBooking'), hasLength(1));
    expect((api.argsOf('payBooking').single as Map)['method'], 'fpx');
    api.payGate!.complete();
    await tester.pumpAndSettle();
    expect(locationOf(c), '/booking/b1/confirmed');
  });

  testWidgets('upcoming visit can be cancelled for free when far away', (tester) async {
    final api = FakeApi();
    final c = await pumpApp(tester, _fakes(booking(status: BookingStatus.confirmed)), at: '/booking/b1', now: now, api: api);
    await scrollTo(tester, find.text('Cancel visit'));
    await tester.tap(find.text('Cancel visit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cancelling is free'), findsOneWidget);
    await scrollTo(tester, find.text('Yes, cancel'));
    await tester.tap(find.text('Yes, cancel'));
    await tester.pumpAndSettle();
    expect(api.argsOf('cancelBooking'), ['b1']);
    expect(c.read(routerProvider), isNotNull);
  });

  testWidgets('Cancel request asks first; Keep request does not cancel', (tester) async {
    final api = FakeApi();
    final fakes = _fakes(booking(status: BookingStatus.pendingCaregiver, caregiverName: null));
    await pumpApp(tester, fakes, at: '/booking/b1/pending', now: now, api: api);
    await scrollTo(tester, find.text('Cancel request'));
    await tester.tap(find.text('Cancel request'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this request?'), findsOneWidget);
    await tester.tap(find.text('Keep request'));
    await tester.pumpAndSettle();
    expect(api.argsOf('cancelBooking'), isEmpty);
    expect(find.text('Cancel this request?'), findsNothing);
  });

  testWidgets('Yes, cancel cancels and goes home', (tester) async {
    final api = FakeApi();
    final fakes = _fakes(booking(status: BookingStatus.pendingCaregiver, caregiverName: null));
    final c = await pumpApp(tester, fakes, at: '/booking/b1/pending', now: now, api: api);
    await scrollTo(tester, find.text('Cancel request'));
    await tester.tap(find.text('Cancel request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, cancel'));
    await tester.pumpAndSettle();
    expect(api.argsOf('cancelBooking'), ['b1']);
    expect(locationOf(c), '/home');
  });
}
