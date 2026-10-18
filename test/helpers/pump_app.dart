import 'package:careway/app.dart';
import 'package:careway/core/router.dart';
import 'package:careway/data/api.dart';
import 'package:careway/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_repos.dart';

/// Pumps the full app on a phone-sized screen with fake repositories.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Fakes fakes, {
  String? at,
  FakeApi? api,
  DateTime? now,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Looping animations (pending spinner, live pulse) would never settle.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final container = ProviderContainer(
    overrides: [
      ...fakes.overrides,
      careWayApiProvider.overrideWithValue(api ?? FakeApi()),
      if (now != null) clockProvider.overrideWithValue(() => now),
    tickProvider.overrideWith((ref) => Stream.value(now ?? DateTime.now())),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const CareWayApp()),
  );
  await tester.pumpAndSettle();
  if (at != null) {
    container.read(routerProvider).go(at);
    await tester.pumpAndSettle();
  }
  return container;
}

/// Current router location.
String locationOf(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

/// Scrolls the screen's main list until [f] is built and fully visible.
Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}
