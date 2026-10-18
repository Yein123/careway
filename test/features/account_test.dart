import 'package:careway/data/models/notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('choosing Large text saves and scales the app', (tester) async {
    final fakes = guardianFakes();
    await pumpApp(tester, fakes, at: '/account/language', now: now);
    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    expect(fakes.user.updates.last.$2, {'settings.textScale': 1.15});
    final ctx = tester.element(find.text('Language and text size').first);
    expect(MediaQuery.textScalerOf(ctx).scale(10), closeTo(11.5, 0.001));
  });

  testWidgets('refund receipt shows as a negative amount', (tester) async {
    final fakes = guardianFakes();
    fakes.receipt.items.set([
      Receipt(id: 'r1', uid: 'g1', amountSen: 4000, kind: ReceiptKind.payment, label: 'Shared ride · Zainab', method: 'FPX online banking', createdAt: now),
      Receipt(id: 'r2', uid: 'g1', amountSen: 1800, kind: ReceiptKind.refund, label: 'Group price drop · 3 riders', createdAt: now),
    ]);
    await pumpApp(tester, fakes, at: '/account/receipts', now: now);
    expect(find.text('RM 40.00'), findsOneWidget);
    expect(find.text('− RM 18.00'), findsOneWidget);
  });

  testWidgets('sign out returns to welcome', (tester) async {
    final fakes = guardianFakes();
    final c = await pumpApp(tester, fakes, at: '/account', now: now);
    expect(find.text('Aisyah binti Hassan'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sign out'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(fakes.auth.signOuts, 1);
    expect(locationOf(c), '/');
    expect(find.text('Welcome to CareWay'), findsOneWidget);
  });

  testWidgets('notification switches save to settings', (tester) async {
    final fakes = guardianFakes();
    await pumpApp(tester, fakes, at: '/account/notifications', now: now);
    await tester.tap(find.byKey(const ValueKey('notif-reminders')));
    await tester.pumpAndSettle();
    expect(fakes.user.updates.last.$2, {'settings.notif.reminders': false});
  });
}
