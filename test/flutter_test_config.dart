import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:careway/domain/fee_model.dart';

/// Runs before every test file: loads the fee model file the app bundles, as
/// main() does at startup.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  FeeModel.current = FeeModel.fromJson(jsonDecode(File(FeeModel.assetPath).readAsStringSync()) as Map<String, dynamic>);
  await testMain();
}
