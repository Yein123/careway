import 'package:careway/core/router.dart';
import 'package:careway/data/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_repos.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('welcome shows Get started and Sign in', (tester) async {
    await pumpApp(tester, Fakes());
    expect(find.text('Welcome to CareWay'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('get started: Skip jumps to the account form', (tester) async {
    await pumpApp(tester, Fakes(), at: '/start');
    expect(find.text('Add who you care for'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('create account is disabled until the form is valid', (
    tester,
  ) async {
    final fakes = Fakes();
    final c = await pumpApp(tester, fakes, at: '/start');
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    Finder button() => find.widgetWithText(FilledButton, 'Create account');
    expect(tester.widget<FilledButton>(button()).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('gs-name')),
      'Aisyah binti Hassan',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gs-phone')),
      '12-345 6789',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gs-email')),
      'aisyah@example.com',
    );
    await tester.enterText(find.byKey(const ValueKey('gs-pass')), 'short');
    await tester.pump();
    expect(tester.widget<FilledButton>(button()).onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('gs-pass')), 'longenough');
    await tester.pump();
    expect(tester.widget<FilledButton>(button()).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('gs-agree')));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(button()).onPressed,
      isNull,
      reason: 'agreement unticked',
    );
    await tester.tap(find.byKey(const ValueKey('gs-agree')));
    await tester.pump();

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(button());
    await tester.tap(button());
    await tester.pumpAndSettle();
    expect(fakes.auth.signUps, ['aisyah@example.com']);
    final user = fakes.user.users.items.single;
    expect(
      (user.name, user.role, user.phone),
      ('Aisyah binti Hassan', UserRole.guardian, '+60 12-345 6789'),
    );
    expect(fakes.family.families.items.single.adminUid, user.uid);
    expect(locationOf(c), '/family');
  });

  testWidgets('signed-in caregiver is kept in the caregiver app', (
    tester,
  ) async {
    final fakes = Fakes(
      uid: 'cg1',
      users: [
        const AppUser(
          uid: 'cg1',
          name: 'Nurul H.',
          email: 'nurul@careway.demo',
          role: UserRole.caregiver,
        ),
      ],
    );
    final c = await pumpApp(tester, fakes);
    expect(locationOf(c), '/cg');
    c.read(routerProvider).go('/home');
    await tester.pumpAndSettle();
    expect(locationOf(c), '/cg');
  });

  testWidgets('signed-in guardian cannot open caregiver routes', (
    tester,
  ) async {
    final fakes = Fakes(
      uid: 'g1',
      users: [
        const AppUser(
          uid: 'g1',
          name: 'Aisyah',
          email: 'a@x.com',
          role: UserRole.guardian,
          familyId: 'f1',
        ),
      ],
    );
    final c = await pumpApp(tester, fakes, at: '/cg');
    expect(locationOf(c), '/home');
  });

  testWidgets('sign in with a bad password shows a friendly error', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Fakes(passwords: {'a@x.com': 'rightpass'}),
      at: '/signin',
    );
    await tester.enterText(find.byKey(const ValueKey('si-email')), 'a@x.com');
    await tester.enterText(find.byKey(const ValueKey('si-pass')), 'wrongpass');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  });
}
