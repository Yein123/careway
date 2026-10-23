import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'domain/fee_model.dart';
import 'firebase_options.dart';

const useEmulator = bool.fromEnvironment('USE_EMULATOR');
const functionsRegion = 'asia-southeast1';

Future<void> connectEmulators() async {
  final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8085);
  FirebaseFunctions.instanceFor(
    region: functionsRegion,
  ).useFunctionsEmulator(host, 5001);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (useEmulator) await connectEmulators();
  await FeeModel.load();
  runApp(const ProviderScope(child: CareWayApp()));
}
