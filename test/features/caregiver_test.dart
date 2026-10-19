import 'package:careway/data/api.dart';
import 'package:careway/data/models/caregiver.dart';
import 'package:careway/data/models/notification.dart';
import 'package:careway/data/models/offer.dart';
import 'package:careway/data/models/user.dart';
import 'package:careway/domain/booking_status.dart';
import 'package:careway/domain/needs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_repos.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

const cgUser = AppUser(uid: 'cg1', name: 'Nurul H.', email: 'nurul@careway.demo', role: UserRole.caregiver);

CaregiverProfile profile({List<Certificate>? certs}) => CaregiverProfile(
      uid: 'cg1',
      displayName: 'Nurul H.',
      agency: 'Partner agency',
      onDuty: true,
      rating: 4.9,
      ratingCount: 128,
      languages: const ['Malay', 'English'],
      skills: const {Skill.transfer, Skill.consultSitIn},
      certificates: certs ??
          [
            Certificate(type: CertType.firstAid, verified: true, expiresAt: DateTime.utc(2028)),
            Certificate(type: CertType.trainedEscort, verified: true, expiresAt: DateTime.utc(2028)),
          ],
    );

Offer offer() => Offer(
      id: 'o1',
      caregiverId: 'cg1',
      kind: OfferKind.personal,
      status: OfferStatus.offered,
      expiresAt: now.add(const Duration(minutes: 18)),
      bookingId: 'b1',
      patientName: 'Adam bin Imran',
      patientAge: 9,
      placeName: 'Hospital Shah Alam · Paediatric clinic',
      apptAt: appt,
      level: 2,
      estimateSen: 12000,
      needs: const ['Child'],
    );

Fakes cgFakes({List<Offer> offers = const [], CaregiverProfile? p}) =>
    Fakes(uid: 'cg1', users: [cgUser], caregivers: [p ?? profile()], offers: offers);

Finder _filled(String label) => find.widgetWithText(FilledButton, label);

void main() {
  testWidgets('new job request shows the countdown', (tester) async {
    await pumpApp(tester, cgFakes(offers: [offer()]), now: now);
    expect(find.text('NEW JOB REQUEST'), findsOneWidget);
    expect(find.text('Expires in 18 min'), findsOneWidget);
    expect(find.textContaining('Adam bin Imran, 9'), findsOneWidget);
  });

  testWidgets('accept calls respondToOffer', (tester) async {
    final api = FakeApi();
    await pumpApp(tester, cgFakes(offers: [offer()]), now: now, api: api);
    await tester.tap(_filled('Accept'));
    await tester.pumpAndSettle();
    expect(api.argsOf('respondToOffer').single, {'offerId': 'o1', 'accept': true});
  });

  testWidgets('job request notification offers Accept and Decline while the offer is open', (tester) async {
    final api = FakeApi();
    final note = AppNotification(id: 'o1', type: 'job-request', title: 'New job request', body: 'Adam bin Imran', link: '/cg', createdAt: now);
    final fakes = Fakes(uid: 'cg1', users: [cgUser], caregivers: [profile()], offers: [offer()], notifications: [note]);
    await pumpApp(tester, fakes, at: '/cg/notifications', now: now, api: api);
    await tester.tap(_filled('Accept'));
    await tester.pumpAndSettle();
    expect(api.argsOf('respondToOffer').single, {'offerId': 'o1', 'accept': true});

    fakes.offer.offers.set([]);
    await tester.pumpAndSettle();
    expect(_filled('Accept'), findsNothing, reason: 'cancelled offers drop their actions');
  });

  testWidgets('expired offer is removed with a message', (tester) async {
    final api = FakeApi()..nextError = const CareWayException('offer-expired', 'This request expired.');
    await pumpApp(tester, cgFakes(offers: [offer()]), now: now, api: api);
    await tester.tap(_filled('Accept'));
    await tester.pumpAndSettle();
    expect(find.text('NEW JOB REQUEST'), findsNothing);
    expect(find.text('This request expired.'), findsOneWidget);
  });

  testWidgets('expired certificate is flagged', (tester) async {
    final p = profile(certs: [
      Certificate(type: CertType.firstAid, verified: true, expiresAt: DateTime.utc(2026, 1, 1)),
      Certificate(type: CertType.trainedEscort, verified: true, expiresAt: DateTime.utc(2028, 1, 1)),
    ]);
    await pumpApp(tester, cgFakes(p: p), at: '/cg/account', now: now);
    expect(find.textContaining('(expired)'), findsOneWidget);
    await tester.tap(find.text('Certificates'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Expired 1 Jan 2026'), findsOneWidget);
    expect(find.textContaining('Expires 1 Jan 2028'), findsOneWidget);
  });

  testWidgets('steps screen offers Picked up first', (tester) async {
    final fakes = cgFakes()..booking.put(booking(status: BookingStatus.confirmed, level: 2, groupId: null));
    final api = FakeApi();
    await pumpApp(tester, fakes, at: '/cg/job/b1/steps', now: now, api: api);
    expect(_filled('Mark done: Picked up'), findsOneWidget);
    await tester.tap(_filled('Mark done: Picked up'));
    await tester.pumpAndSettle();
    expect(api.argsOf('advanceStep'), ['b1']);
  });

  testWidgets('summary required sends the caregiver to the summary form', (tester) async {
    final fakes = cgFakes()..booking.put(booking(status: BookingStatus.inProgress, level: 2, groupId: null));
    final api = FakeApi()..nextError = const CareWayException('summary-required', 'Write the visit summary before finishing.');
    final c = await pumpApp(tester, fakes, at: '/cg/job/b1/steps', now: now, api: api);
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    expect(locationOf(c), '/cg/job/b1/summary');
  });
}
