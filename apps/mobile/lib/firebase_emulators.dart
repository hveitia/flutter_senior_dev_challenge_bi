import 'package:banca_digital/api_base_url.dart';

/// Where the Firebase emulators of a local stack listen.
final class FirebaseEmulators {
  const FirebaseEmulators({
    required this.host,
    required this.authPort,
    required this.firestorePort,
  });

  final String host;
  final int authPort;
  final int firestorePort;
}

/// This build cannot use the Firebase emulators it was asked to use.
final class FirebaseEmulatorsError implements Exception {
  const FirebaseEmulatorsError(this.message);

  final String message;

  @override
  String toString() => 'FirebaseEmulatorsError: $message';
}

/// Where the data of a build lives, as the diagnostics card names it.
enum AppEnvironment { project, localEmulators }

AppEnvironment appEnvironmentFor(FirebaseEmulators? emulators) =>
    emulators == null ? AppEnvironment.project : AppEnvironment.localEmulators;

/// The Auth emulator's standard port.
const int defaultAuthEmulatorPort = 9099;

/// The Firestore emulator's standard port.
const int defaultFirestoreEmulatorPort = 8080;

/// The host a phone reaches the developer's machine by through
/// `adb reverse`, which also works on an Android emulator.
const String defaultEmulatorHost = 'localhost';

const int _maxPort = 65535;

/// The emulators a build in [mode] uses, or null for the Firebase project.
///
/// The Auth emulator accepts any password and signs nothing, so it is only
/// for a developer's machine:
///
/// * a build that did not ask (`USE_FIREBASE_EMULATORS` not `true`) gets
///   null and talks to the project;
/// * a release build that asked refuses to start;
/// * the host must be one of [developmentHosts], the same ones a debug or
///   profile build may reach without encryption.
///
/// Throws [FirebaseEmulatorsError] otherwise.
FirebaseEmulators? firebaseEmulatorsFor({
  required bool requested,
  required String host,
  required String authPort,
  required String firestorePort,
  required BuildMode mode,
}) {
  if (!requested) return null;
  if (mode == BuildMode.release) {
    throw const FirebaseEmulatorsError(
      'USE_FIREBASE_EMULATORS cannot be set in a release build.',
    );
  }

  final target = host.trim().isEmpty ? defaultEmulatorHost : host.trim();
  if (!developmentHosts.contains(target)) {
    throw const FirebaseEmulatorsError(
      'FIREBASE_EMULATOR_HOST must be the developer machine: localhost, '
      '127.0.0.1 or 10.0.2.2.',
    );
  }

  return FirebaseEmulators(
    host: target,
    authPort: _portFrom(
      authPort,
      fallback: defaultAuthEmulatorPort,
      name: 'FIREBASE_AUTH_EMULATOR_PORT',
    ),
    firestorePort: _portFrom(
      firestorePort,
      fallback: defaultFirestoreEmulatorPort,
      name: 'FIRESTORE_EMULATOR_PORT',
    ),
  );
}

int _portFrom(String value, {required int fallback, required String name}) {
  final text = value.trim();
  if (text.isEmpty) return fallback;
  final port = int.tryParse(text);
  if (port == null || port < 1 || port > _maxPort) {
    throw FirebaseEmulatorsError('$name is not a port number.');
  }
  return port;
}
