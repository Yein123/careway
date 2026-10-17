import 'package:careway/data/models/booking.dart';
import 'package:careway/domain/booking_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('live visit shows the current step', (tester) async {
    final b = booking(
      status: BookingStatus.inProgress,
      steps: [VisitStep('picked_up', now), VisitStep('registered', now.add(const Duration(minutes: 40)))],
    );
    await pumpApp(tester, guardianFakes(bookings: [b]), at: '/booking/b1/live', now: now);
    expect(find.text('Now: With the doctor'), findsOneWidget);
    expect(find.text('Arrived and registered'), findsOneWidget);
  });

  testWidgets('rating a past visit', (tester) async {
    final b = booking(
      status: BookingStatus.completed,
      apptAt: now.subtract(const Duration(days: 3)),
      price: const PriceInfo(lines: [PriceLine('Group Saver', 2200)], paidSen: 2200),
      summary: const VisitSummary(seenBy: 'Dr Lee', diagnosis: 'Knee stable', instructions: ['Physio twice a week'], writtenBy: 'Farid A.'),
    );
    final fakes = guardianFakes(bookings: [b]);
    await pumpApp(tester, fakes, at: '/visits', now: now);
    await tester.tap(find.textContaining('Past'));
    await tester.pumpAndSettle();
    expect(find.text('Rate this visit'), findsOneWidget);
    await tester.tap(find.text('Rate this visit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('star-4')));
    await tester.pump();
    expect(find.text('Good'), findsOneWidget);
    await tester.tap(find.text('On time'));
    await tester.tap(find.widgetWithText(FilledButton, 'Send feedback'));
    await tester.pumpAndSettle();
    expect(fakes.booking.ratings.single.$2.stars, 4);
    expect(fakes.booking.ratings.single.$2.tags, ['On time']);
    expect(find.text('You rated 4'), findsOneWidget);
  });

  testWidgets('summary is shown for a past visit', (tester) async {
    final b = booking(
      status: BookingStatus.completed,
      apptAt: now.subtract(const Duration(days: 3)),
      summary: const VisitSummary(seenBy: 'Dr Lee', diagnosis: 'Knee stable', instructions: ['Physio twice a week'], writtenBy: 'Farid A.'),
    );
    await pumpApp(tester, guardianFakes(bookings: [b]), at: '/visits', now: now);
    await tester.tap(find.textContaining('Past'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visit summary'));
    await tester.pumpAndSettle();
    expect(find.text('Physio twice a week'), findsOneWidget);
    expect(find.textContaining('Written by Farid A.'), findsOneWidget);
  });

  testWidgets('empty Now tab', (tester) async {
    await pumpApp(tester, guardianFakes(), at: '/visits', now: now);
    await tester.tap(find.textContaining('Now'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing happening now'), findsOneWidget);
  });
}
