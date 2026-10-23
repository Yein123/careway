import 'package:careway/core/router.dart';
import 'package:careway/core/money.dart';
import 'package:careway/data/models/delivery.dart';
import 'package:careway/domain/pricing.dart';
import 'package:careway/features/delivery/delivery_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_api.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

Finder _filled(String label) => find.widgetWithText(FilledButton, label);

MedDelivery _delivery(DeliveryStatus status) => MedDelivery(
      id: 'd1',
      familyId: 'f1',
      guardianUid: 'g1',
      patientId: 'p1',
      patientName: 'Zainab binti Ahmad',
      pharmacyId: 'hsb',
      pharmacyName: 'Hospital Sungai Buloh',
      window: '8:00 – 10:00 AM',
      deliverTo: 'Home · 12, Jalan Elmina Lakeside',
      routeKm: 12.4,
      baseSen: 500,
      distanceSen: 620,
      status: status,
      caregiverId: 'cg1',
      caregiverName: 'Farid A.',
      createdAt: now,
    );

void main() {
  testWidgets('documents must all be ticked', (tester) async {
    await pumpApp(tester, guardianFakes(), at: '/delivery/new', now: now);
    await tester.tap(find.text('Hospital Sungai Buloh'));
    await tester.pump();
    expect(tester.widget<FilledButton>(_filled('Calculate the fee to continue')).onPressed, isNull);
    await scrollTo(tester, _filled('Calculate fee'));
    await tester.tap(_filled('Calculate fee'));
    await tester.pump();
    expect(tester.widget<FilledButton>(_filled('Tick all 3 documents to continue')).onPressed, isNull);
    for (final d in ['Appointment card or prescription slip', "Copy of Zainab's IC", 'Authorisation letter']) {
      await scrollTo(tester, find.text(d));
      await tester.tap(find.text(d));
      await tester.pump();
    }
    expect(tester.widget<FilledButton>(find.ancestor(of: find.textContaining('Pay RM'), matching: find.byType(FilledButton))).onPressed, isNotNull);
  });

  testWidgets('fee estimate comes from the AI fee model for the route and window', (tester) async {
    await pumpApp(tester, guardianFakes(), at: '/delivery/new', now: now);
    await tester.tap(find.text('Hospital Sungai Buloh'));
    await tester.pump();
    await scrollTo(tester, _filled('Calculate fee'));
    await tester.tap(_filled('Calculate fee'));
    await tester.pump();
    final km = routeKm(3.1885, 101.5165, 3.2196, 101.5826);
    // Default window: tomorrow, first slot.
    final local = now.toLocal();
    final start = DateTime(local.year, local.month, local.day + 1).add(Duration(minutes: deliveryWindows[0].$2));
    final fee = deliveryFee(km, start);
    expect(find.text('AI fee estimate'), findsOneWidget);
    expect(find.textContaining('MyUBAT'), findsOneWidget);
    expect(find.text('$km km'), findsOneWidget);
    expect(find.text(formatRm(fee.totalSen)), findsOneWidget);
  });

  testWidgets('request sends documents and window, then opens the status', (tester) async {
    final api = FakeApi();
    final c = await pumpApp(tester, guardianFakes(), at: '/delivery/new', now: now, api: api);
    await tester.tap(find.text('Hospital Sungai Buloh'));
    await tester.pump();
    await scrollTo(tester, _filled('Calculate fee'));
    await tester.tap(_filled('Calculate fee'));
    await tester.pump();
    for (final d in ['Appointment card or prescription slip', "Copy of Zainab's IC", 'Authorisation letter']) {
      await scrollTo(tester, find.text(d));
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.tap(find.textContaining('Pay RM'));
    await tester.pumpAndSettle();
    final req = api.argsOf('requestDelivery').single as Map;
    expect((req['pharmacyId'], req['window'], req['method']), ('hsb', '8:00 – 10:00 AM', 'fpx'));
    expect(req['docs'], {'card': true, 'ic': true, 'letter': true});
    expect(locationOf(c), '/delivery/d-new');
  });

  testWidgets('accepted delivery can be paid', (tester) async {
    final api = FakeApi();
    final fakes = guardianFakes()..delivery.put(_delivery(DeliveryStatus.awaitingPayment));
    await pumpApp(tester, fakes, at: '/delivery/d1', now: now, api: api);
    await tester.ensureVisible(_filled('Pay RM 11.20'));
    await tester.tap(_filled('Pay RM 11.20'));
    await tester.pumpAndSettle();
    expect(api.argsOf('payDelivery').single, {'deliveryId': 'd1', 'method': 'fpx'});
  });

  testWidgets('delivered shows rate this delivery', (tester) async {
    final fakes = guardianFakes()..delivery.put(_delivery(DeliveryStatus.delivered));
    await pumpApp(tester, fakes, at: '/delivery/d1', now: now);
    expect(find.text('Rate this delivery'), findsOneWidget);
  });

  testWidgets('deliveries list groups In progress and Delivered and New delivery opens the request', (tester) async {
    final fakes = guardianFakes(deliveries: [
      delivery(id: 'd1', status: DeliveryStatus.onTheWay),
      delivery(id: 'd2', status: DeliveryStatus.delivered),
    ]);
    final c = await pumpApp(tester, fakes, at: '/deliveries', now: now);
    expect(find.text('Medicine deliveries'), findsOneWidget);
    expect(find.text('Track and look back at every delivery'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Delivered'), findsNWidgets(2), reason: 'section title and chip');
    expect(find.text('Track ›'), findsOneWidget);
    await tester.tap(_filled('New delivery'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation, '/delivery/new');
  });

  testWidgets('deliveries list shows an empty state', (tester) async {
    await pumpApp(tester, guardianFakes(deliveries: []), at: '/deliveries', now: now);
    expect(find.text('No deliveries yet'), findsOneWidget);
  });
}
