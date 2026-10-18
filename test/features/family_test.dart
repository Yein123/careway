import 'package:careway/domain/needs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

Finder _filled(String label) => find.widgetWithText(FilledButton, label);

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty family invites adding someone', (tester) async {
    await pumpApp(tester, guardianFakes(patients: []), at: '/family');
    expect(find.text('Ahmad family'), findsOneWidget);
    expect(find.text('Add someone you care for'), findsOneWidget);
  });

  testWidgets('saving the form adds a patient tile', (tester) async {
    final fakes = guardianFakes(patients: []);
    await pumpApp(tester, fakes, at: '/family');
    await tester.tap(find.text('Add someone you care for'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pf-name')), 'Zainab binti Ahmad');
    await tester.enterText(find.byKey(const ValueKey('pf-age')), '72');
    await tester.ensureVisible(find.text('Walking stick'));
    await tester.tap(find.text('Walking stick'));
    await tester.pump();
    await tester.ensureVisible(_filled('Save'));
    await tester.tap(_filled('Save'));
    await tester.pumpAndSettle();
    expect(fakes.family.saved.single.mobility, Mobility.stick);
    expect(find.text('Zainab binti Ahmad'), findsOneWidget);
  });

  testWidgets('save is disabled until name and a valid age are entered', (tester) async {
    await pumpApp(tester, guardianFakes(patients: []), at: '/family/patient/new');
    expect(tester.widget<FilledButton>(_filled('Save')).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('pf-name')), 'Zainab');
    await tester.enterText(find.byKey(const ValueKey('pf-age')), '130');
    await tester.pump();
    expect(tester.widget<FilledButton>(_filled('Save')).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('pf-age')), '72');
    await tester.pump();
    expect(tester.widget<FilledButton>(_filled('Save')).onPressed, isNotNull);
  });

  testWidgets('profile edit saves the new mobility', (tester) async {
    final fakes = guardianFakes();
    await pumpApp(tester, fakes, at: '/family/patient/p1');
    expect(find.text('Zainab binti Ahmad, 72'), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    await _scrollTo(tester, _filled('Edit profile'));
    await tester.tap(_filled('Edit profile'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Wheelchair'));
    await tester.tap(find.text('Wheelchair'));
    await tester.pump();
    await _scrollTo(tester, _filled('Save profile'));
    await tester.tap(_filled('Save profile'));
    await tester.pumpAndSettle();
    expect(fakes.family.saved.single.mobility, Mobility.wheelchair);
    expect(fakes.family.saved.single.id, 'p1');
    expect(find.text('Edit profile'), findsOneWidget, reason: 'back to view mode');
  });
}
