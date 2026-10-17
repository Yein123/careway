import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_repos.dart';
import 'helpers/pump_app.dart';

void main() {
  testWidgets('app boots to welcome', (tester) async {
    await pumpApp(tester, Fakes());
    expect(find.text('Welcome to CareWay'), findsOneWidget);
  });
}
