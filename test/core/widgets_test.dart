import 'package:careway/core/theme.dart';
import 'package:careway/core/widgets/async_view.dart';
import 'package:careway/core/widgets/cw_button.dart';
import 'package:careway/core/widgets/cw_page.dart';
import 'package:careway/core/widgets/seat_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: CwTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('disabled CwButton ignores taps', (tester) async {
    await tester.pumpWidget(
      wrap(const CwButton(label: 'Next', onPressed: null)),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('enabled CwButton calls onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(CwButton(label: 'Next', onPressed: () => taps++)),
    );
    await tester.tap(find.text('Next'));
    expect(taps, 1);
  });

  testWidgets('AsyncView error shows Retry that calls onRetry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(
        AsyncView<int>(
          value: AsyncValue<int>.error('boom', StackTrace.empty),
          data: (v) => Text('$v'),
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('AsyncView shows empty widget when isEmpty', (tester) async {
    await tester.pumpWidget(
      wrap(
        AsyncView<List<int>>(
          value: const AsyncValue.data([]),
          data: (v) => const Text('list'),
          isEmpty: (v) => v.isEmpty,
          empty: const Text('Nothing here'),
        ),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('SeatRow shows taken initials and empty seats', (tester) async {
    await tester.pumpWidget(wrap(const SeatRow(initials: ['SL', null, null])));
    expect(find.text('SL'), findsOneWidget);
    expect(find.byKey(const ValueKey('seat-empty')), findsNWidgets(2));
  });

  Finder logoImage(String name) => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName.endsWith(name),
  );

  testWidgets('CwLogo shows the guardian image', (tester) async {
    await tester.pumpWidget(wrap(const CwLogo()));
    expect(logoImage('careway-icon-512-square.png'), findsOneWidget);
  });

  testWidgets('CwLogo caregiver shows the caregiver image', (tester) async {
    await tester.pumpWidget(wrap(const CwLogo(caregiver: true)));
    expect(logoImage('careway-caregiver-icon-512.png'), findsOneWidget);
  });
}
