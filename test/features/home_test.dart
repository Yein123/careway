import 'package:careway/core/router.dart';
import 'package:careway/data/models/booking.dart';
import 'package:careway/data/models/delivery.dart';
import 'package:careway/data/models/notification.dart';
import 'package:careway/domain/booking_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_repos.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

Fakes _with({List<Booking> bookings = const [], List<AppNotification> notes = const []}) {
  final f = guardianFakes(bookings: bookings);
  f.notification.items.set(notes);
  return f;
}

void main() {
  testWidgets('awaiting payment shows Pay to confirm', (tester) async {
    await pumpApp(tester, _with(bookings: [booking(status: BookingStatus.awaitingPayment)]), at: '/home', now: now);
    expect(find.text('Hello, Aisyah!'), findsOneWidget);
    expect(find.text('Pay to confirm'), findsOneWidget);
  });

  testWidgets('no pending action: only the Book a visit call to action', (tester) async {
    await pumpApp(tester, _with(), at: '/home', now: now);
    expect(find.text('Pay to confirm'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Book a visit'), findsOneWidget);
  });

  testWidgets('live visit shows LIVE NOW', (tester) async {
    await pumpApp(
      tester,
      _with(bookings: [booking(status: BookingStatus.inProgress, steps: [VisitStep('picked_up', now)])]),
      at: '/home',
      now: now,
    );
    expect(find.text('LIVE NOW'), findsOneWidget);
  });

  testWidgets('an early-morning visit today counts as 0 days, not -1', (tester) async {
    // 06:00 and 07:30 in Malaysia: the visit's UTC date is the day before.
    final early = DateTime.utc(2026, 10, 16, 22).toLocal();
    final b = booking(apptAt: DateTime.utc(2026, 10, 16, 23, 30));
    await pumpApp(tester, _with(bookings: [b]), at: '/home', now: early);
    await scrollTo(tester, find.text('days'));
    expect(find.text('0'), findsOneWidget);
    expect(find.text('-1'), findsNothing);
  });

  testWidgets('bell shows the unread count', (tester) async {
    final notes = [
      AppNotification(id: 'n1', type: 'accepted', title: 'A', body: '', createdAt: now),
      AppNotification(id: 'n2', type: 'accepted', title: 'B', body: '', createdAt: now),
      AppNotification(id: 'n3', type: 'accepted', title: 'C', body: '', read: true, createdAt: now),
    ];
    await pumpApp(tester, _with(notes: notes), at: '/home', now: now);
    expect(find.descendant(of: find.byKey(const ValueKey('icon-badge')), matching: find.text('2')), findsOneWidget);
  });

  testWidgets('tapping a notification marks it read and opens its link', (tester) async {
    final fakes = _with(notes: [
      AppNotification(id: 'n1', type: 'accepted', title: 'Farid accepted — pay to confirm', body: 'Pay within 30 minutes', link: '/family', createdAt: now),
    ]);
    final c = await pumpApp(tester, fakes, at: '/notifications', now: now);
    await tester.tap(find.text('Farid accepted — pay to confirm'));
    await tester.pumpAndSettle();
    expect(fakes.notification.marked, ['n1']);
    expect(locationOf(c), '/family');
  });

  testWidgets('no deliveries hides the Medicine delivery section', (tester) async {
    await pumpApp(tester, guardianFakes(deliveries: []), at: '/home', now: now);
    expect(find.text('Medicine delivery'), findsOneWidget, reason: 'only the service tile');
    expect(find.textContaining('Track'), findsNothing);
    expect(find.text('Delivered'), findsNothing);
  });

  testWidgets('in-progress delivery shows a card with stage label and Track', (tester) async {
    final fakes = guardianFakes(deliveries: [delivery(status: DeliveryStatus.atPharmacy)]);
    final c = await pumpApp(tester, fakes, at: '/home', now: now);
    await scrollTo(tester, find.text('At the pharmacy · Farid A.'));
    expect(find.text('Track ›'), findsOneWidget);
    expect(find.text("Zainab's medicine"), findsOneWidget);
    await tester.tap(find.text('At the pharmacy · Farid A.'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation, '/delivery/d1/live');
  });

  testWidgets('View delivery progress on a booked delivery opens the progress page', (tester) async {
    final c = await pumpApp(tester, guardianFakes(deliveries: [delivery()]), at: '/delivery/d1', now: now);
    expect(find.text('Delivery booked'), findsOneWidget);
    await scrollTo(tester, find.text('View delivery progress'));
    await tester.tap(find.text('View delivery progress'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation, '/delivery/d1/live');
    expect(find.text('Delivery progress'), findsOneWidget);
    expect(find.text('Booking confirmed'), findsOneWidget);
  });

  testWidgets('only delivered shows the latest delivered row', (tester) async {
    final fakes = guardianFakes(deliveries: [delivery(status: DeliveryStatus.delivered)]);
    final c = await pumpApp(tester, fakes, at: '/home', now: now);
    await scrollTo(tester, find.text('Delivered'));
    expect(find.text('Track ›'), findsNothing);
    await tester.tap(find.text('Delivered'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation, '/delivery/d1/done');
  });
}
