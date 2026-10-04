import 'package:banca_digital/api_base_url.dart';
import 'package:banca_digital/firebase_emulators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FirebaseEmulators? resolve({
    bool requested = true,
    String host = '',
    String authPort = '',
    String firestorePort = '',
    BuildMode mode = BuildMode.debug,
  }) => firebaseEmulatorsFor(
    requested: requested,
    host: host,
    authPort: authPort,
    firestorePort: firestorePort,
    mode: mode,
  );

  group('firebaseEmulatorsFor', () {
    test('a build that does not ask for the emulators uses the project', () {
      for (final mode in BuildMode.values) {
        expect(resolve(requested: false, mode: mode), isNull);
      }
    });

    test('defaults to the developer machine and the standard ports', () {
      final emulators = resolve();

      expect(emulators, isNotNull);
      expect(emulators!.host, 'localhost');
      expect(emulators.authPort, 9099);
      expect(emulators.firestorePort, 8080);
    });

    test('a profile build may use the emulators too', () {
      expect(resolve(mode: BuildMode.profile), isNotNull);
    });

    test('takes the host an Android emulator sees the machine as', () {
      expect(resolve(host: '10.0.2.2')!.host, '10.0.2.2');
    });

    test('takes other ports when given', () {
      final emulators = resolve(authPort: '9199', firestorePort: '8181');

      expect(emulators!.authPort, 9199);
      expect(emulators.firestorePort, 8181);
    });

    test('a release build refuses to start against the emulators', () {
      expect(
        () => resolve(mode: BuildMode.release),
        throwsA(isA<FirebaseEmulatorsError>()),
      );
    });

    test('refuses a host that is not the developer machine', () {
      for (final host in ['example.com', '192.168.1.20', 'localhost.evil']) {
        expect(
          () => resolve(host: host),
          throwsA(isA<FirebaseEmulatorsError>()),
          reason: host,
        );
      }
    });

    test('refuses a port that is not a port', () {
      for (final port in ['abc', '0', '70000', '-1', '80.5']) {
        expect(
          () => resolve(authPort: port),
          throwsA(isA<FirebaseEmulatorsError>()),
          reason: 'auth $port',
        );
        expect(
          () => resolve(firestorePort: port),
          throwsA(isA<FirebaseEmulatorsError>()),
          reason: 'firestore $port',
        );
      }
    });
  });

  group('AppEnvironment', () {
    test('names where the data of this build lives', () {
      expect(appEnvironmentFor(null), AppEnvironment.project);
      expect(appEnvironmentFor(resolve()), AppEnvironment.localEmulators);
    });
  });
}
