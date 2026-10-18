import 'package:careway/data/models/booking.dart';
import 'package:careway/data/models/delivery.dart';
import 'package:careway/data/models/user.dart';
import 'package:careway/domain/booking_status.dart';
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

  testWidgets('Caregiver visit shows the step and Advance step calls adminAdvanceStep', (tester) async {
    final fakes = adminFakes();
    fakes.admin.s3.set([
      booking(id: 'demo-s3-visit', status: BookingStatus.inProgress, steps: [VisitStep('picked_up', now)]),
    ]);
    final api = FakeApi();
    await pumpApp(tester, fakes, at: '/admin', api: api);
    expect(find.text('Caregiver visit'), findsOneWidget);
    expect(find.text('Picked up'), findsOneWidget);
    await tester.tap(find.text('Advance step'));
    await tester.pumpAndSettle();
    expect(api.argsOf('adminAdvanceStep'), ['demo-s3-visit']);
  });
}
