import 'package:careway/data/models/booking.dart';
import 'package:careway/data/models/delivery.dart';
import 'package:careway/data/models/user.dart';
import 'package:careway/domain/booking_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_repos.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

const adminUser = AppUser(uid: 'a1', name: 'Demo Admin', email: 'admin@gmail.com', role: UserRole.admin);

Fakes adminFakes() => Fakes(uid: 'a1', users: [adminUser]);

MedDelivery _delivery(DeliveryStatus status) => MedDelivery(
      id: 'd1',
      familyId: 'f1',
      guardianUid: 'g1',
      patientId: 'p1',
      patientName: 'Zainab binti Ahmad',
      pharmacyId: 'hsb',
      pharmacyName: 'Hospital Sungai Buloh',
      window: '8:00 - 10:00 AM',
      deliverTo: 'Home',
      routeKm: 12.4,
      baseSen: 500,
      distanceSen: 620,
      status: status,
      createdAt: now,
    );

void main() {
  testWidgets('admin user lands on /admin', (tester) async {
    final c = await pumpApp(tester, adminFakes(), at: '/home');
    expect(locationOf(c), '/admin');
    expect(find.text('CareWay demo admin'), findsOneWidget);
  });

  testWidgets('admin@gmail.com with a guardian profile lands on /admin', (tester) async {
    const user = AppUser(uid: 'a2', name: 'Admin', email: 'admin@gmail.com', role: UserRole.guardian);
    final c = await pumpApp(tester, Fakes(uid: 'a2', users: [user]), at: '/home');
    expect(locationOf(c), '/admin');
  });

  testWidgets('guardian visiting /admin is sent to /home', (tester) async {
    final c = await pumpApp(tester, guardianFakes(), at: '/admin');
    expect(locationOf(c), '/home');
  });

  testWidgets('pending booking row shows Accept/Reject/Not found and Accept calls adminRespondOffer', (tester) async {
    final fakes = adminFakes();
    fakes.admin.bookings.set([booking(id: 'b9', status: BookingStatus.pendingCaregiver)]);
    final api = FakeApi();
    await pumpApp(tester, fakes, at: '/admin', api: api);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Not found'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(api.argsOf('adminRespondOffer'), [
      {'col': 'bookings', 'id': 'b9', 'accept': true},
    ]);
  });

  testWidgets('confirmed level 1 booking with a group shows Group set', (tester) async {
    final fakes = adminFakes();
    fakes.admin.bookings.set([booking(id: 'b2')]);
    final api = FakeApi();
    await pumpApp(tester, fakes, at: '/admin', api: api);
    await tester.tap(find.text('Group set'));
    await tester.pumpAndSettle();
    expect(api.argsOf('adminLockGroup'), ['grp']);
    expect(find.text('Group set'), findsWidgets);
  });

  testWidgets('paid delivery row shows Next stage and Run to delivered', (tester) async {
    final fakes = adminFakes();
    fakes.admin.deliveries.set([_delivery(DeliveryStatus.booked)]);
    final api = FakeApi();
    await pumpApp(tester, fakes, at: '/admin', api: api);
    expect(find.text('Next stage'), findsOneWidget);
    expect(find.text('Run to delivered'), findsOneWidget);
    await tester.tap(find.text('Run to delivered'));
    await tester.pumpAndSettle();
    expect(api.argsOf('adminAdvanceDelivery'), [
      {'id': 'd1', 'toEnd': true},
    ]);
  });

  testWidgets('collected delivery row still shows Next stage and Run to delivered', (tester) async {
    final fakes = adminFakes();
    fakes.admin.deliveries.set([_delivery(DeliveryStatus.collected)]);
    await pumpApp(tester, fakes, at: '/admin', api: FakeApi());
    expect(find.text('Next stage'), findsOneWidget);
    expect(find.text('Run to delivered'), findsOneWidget);
  });

  testWidgets('Reset demo for today calls adminReset', (tester) async {
    final api = FakeApi();
    await pumpApp(tester, adminFakes(), at: '/admin', api: api);
    await tester.tap(find.text('Reset demo for today'));
    await tester.pumpAndSettle();
    expect(api.argsOf('adminReset'), hasLength(1));
  });

  testWidgets("today's visit shows the step and Mark done calls adminAdvanceStep", (tester) async {
    final fakes = adminFakes();
    fakes.admin.visits.set([
      booking(id: 'demo-s3-visit', status: BookingStatus.inProgress, steps: [VisitStep('picked_up', now)]),
    ]);
    final api = FakeApi();
    await pumpApp(tester, fakes, at: '/admin', api: api);
    expect(find.text("Today's caregiver visits"), findsOneWidget);
    expect(find.text('Picked up · 1 of 6 done'), findsOneWidget);
    expect(find.text('Write visit summary'), findsNothing);
    await tester.tap(find.text('Mark done: Arrived and registered'));
    await tester.pumpAndSettle();
    expect(api.argsOf('adminAdvanceStep'), ['demo-s3-visit']);
  });

  testWidgets('visits without a caregiver or not yet confirmed are hidden', (tester) async {
    final fakes = adminFakes();
    fakes.admin.visits.set([
      booking(id: 'v1', status: BookingStatus.pendingCaregiver, caregiverName: null),
      booking(id: 'v2', status: BookingStatus.awaitingPayment),
    ]);
    await pumpApp(tester, fakes, at: '/admin', api: FakeApi());
    expect(find.text('No visits today.'), findsOneWidget);
  });

  testWidgets('level 2 visit needs the summary before Home safely; the summary form submits adminSubmitSummary', (tester) async {
    final fakes = adminFakes();
    final steps = [for (final k in personalStepKeys.take(6)) VisitStep(k, now)];
    fakes.admin.visits.set([booking(id: 'v2', level: 2, status: BookingStatus.inProgress, steps: steps)]);
    final api = FakeApi();
    await pumpApp(tester, fakes, at: '/admin', api: api);
    expect(find.text('Write the visit summary before marking Home safely.'), findsOneWidget);
    expect(find.text('Mark done: Home safely'), findsNothing);
    await tester.tap(find.text('Write visit summary'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('as-diagnosis')), 'Knee is improving');
    await tester.enterText(find.widgetWithText(TextField, 'Medical instructions (one per line)'), 'Rest\n\nPhysio twice a week');
    await tester.pump();
    await tester.tap(find.text('Send to family group'));
    await tester.pumpAndSettle();
    expect(api.argsOf('adminSubmitSummary'), [
      {
        'bookingId': 'v2',
        'seenBy': '',
        'diagnosis': 'Knee is improving',
        'instructions': ['Rest', 'Physio twice a week'],
        'nextAppt': '',
        'medicines': '',
        'notes': '',
      },
    ]);
    expect(find.text('Visit summary sent'), findsOneWidget);
  });

  testWidgets('completed visit offers Edit visit summary prefilled', (tester) async {
    final fakes = adminFakes();
    fakes.admin.visits.set([
      booking(
        id: 'v3',
        status: BookingStatus.completed,
        steps: [for (final k in groupStepKeys) VisitStep(k, now)],
        summary: const VisitSummary(seenBy: 'Dr Lee', diagnosis: 'Stable'),
      ),
    ]);
    await pumpApp(tester, fakes, at: '/admin', api: FakeApi());
    expect(find.text('Summary sent'), findsOneWidget);
    expect(find.textContaining('Mark done'), findsNothing);
    await tester.tap(find.text('Edit visit summary'));
    await tester.pumpAndSettle();
    expect(find.text('Stable'), findsOneWidget);
    expect(find.text('Dr Lee'), findsOneWidget);
  });
}
