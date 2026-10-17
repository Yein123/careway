import 'package:careway/core/money.dart';
import 'package:careway/data/models/delivery.dart';
import 'package:careway/domain/pricing.dart';
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
    expect(tester.widget<FilledButton>(_filled('Tick all 3 documents to continue')).onPressed, isNull);
    for (final d in ['Appointment card or prescription slip', "Copy of Zainab's IC", 'Authorisation letter']) {
      await tester.ensureVisible(find.text(d));
      await tester.tap(find.text(d));
      await tester.pump();
    }
    expect(tester.widget<FilledButton>(_filled('Find a helper')).onPressed, isNotNull);
  });

  testWidgets('fee estimate uses the distance formula, without claiming AI', (tester) async {
    await pumpApp(tester, guardianFakes(), at: '/delivery/new', now: now);
    await tester.tap(find.text('Hospital Sungai Buloh'));
    await tester.pump();
    final km = routeKm(3.1885, 101.5165, 3.2196, 101.5826);
    final fee = deliveryFee(km);
    expect(find.text('Fee estimate'), findsOneWidget);
    expect(find.textContaining('AI'), findsNothing);
    expect(find.text('$km km'), findsOneWidget);
    expect(find.text(formatRm(fee.totalSen)), findsOneWidget);
  });

  testWidgets('request sends documents and window, then opens the status', (tester) async {
    final api = FakeApi();
    final c = await pumpApp(tester, guardianFakes(), at: '/delivery/new', now: now, api: api);
    await tester.tap(find.text('Hospital Sungai Buloh'));
    for (final d in ['Appointment card or prescription slip', "Copy of Zainab's IC", 'Authorisation letter']) {
      await tester.ensureVisible(find.text(d));
      await tester.tap(find.text(d));
    }
    await tester.pump();
    await tester.ensureVisible(_filled('Find a helper'));
    await tester.tap(_filled('Find a helper'));
    await tester.pumpAndSettle();
    final req = api.argsOf('requestDelivery').single as Map;
    expect((req['pharmacyId'], req['window']), ('hsb', '8:00 – 10:00 AM'));
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
}
