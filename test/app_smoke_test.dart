import 'package:careway/app.dart';
import 'package:careway/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to welcome', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [authStateProvider.overrideWith((_) => Stream.value(null))],
      child: const CareWayApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to CareWay'), findsOneWidget);
  });
}
