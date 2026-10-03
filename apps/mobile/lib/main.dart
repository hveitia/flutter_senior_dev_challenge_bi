import 'package:app_platform/adapters.dart';
import 'package:banca_digital/app.dart';
import 'package:banca_digital/bootstrap.dart';
import 'package:banca_digital/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installTelemetry(await connectTelemetry(_connectFirebase));
  runApp(const BancaDigitalApp());
}

Future<FirebaseTelemetry> _connectFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final telemetry = FirebaseTelemetry.forDefaultApp();
  // Crashes of a developer's build would pollute the production figures.
  await telemetry.setCrashCollectionEnabled(enabled: kReleaseMode);
  return telemetry;
}
