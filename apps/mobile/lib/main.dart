import 'package:app_platform/adapters.dart';
import 'package:banca_digital/app.dart';
import 'package:banca_digital/bootstrap.dart';
import 'package:banca_digital/composition.dart';
import 'package:banca_digital/firebase_emulators.dart';
import 'package:banca_digital/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Decided before Firebase is touched: a release build asked to use the
  // emulators, which accept any password, stops here.
  final emulators = firebaseEmulatorsFor(
    requested: BuildFlags.useFirebaseEmulators,
    host: BuildFlags.firebaseEmulatorHost,
    authPort: BuildFlags.authEmulatorPort,
    firestorePort: BuildFlags.firestoreEmulatorPort,
    mode: BuildFlags.mode,
  );
  final telemetry = await connectTelemetry(_connectFirebase);
  await useFirebaseEmulators(emulators);
  installTelemetry(telemetry);
  runApp(
    BancaDigitalApp(
      dependencies: await composeDependencies(telemetry, emulators: emulators),
    ),
  );
}

Future<FirebaseTelemetry> _connectFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final telemetry = FirebaseTelemetry.forDefaultApp();
  // Crashes of a developer's build would pollute the production figures.
  await telemetry.setCrashCollectionEnabled(enabled: kReleaseMode);
  return telemetry;
}
