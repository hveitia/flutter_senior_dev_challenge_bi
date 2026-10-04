import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app_dependencies.dart';
import 'package:banca_digital/shell/diagnostics_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 3, 10);

  group('age of the last synchronization', () {
    String age(Duration ago) =>
        DiagnosticsStrings.age(now.subtract(ago), now: now);

    test('says so when the device never synchronized', () {
      expect(DiagnosticsStrings.age(null, now: now), 'Sin sincronizar');
    });

    test('is written in the largest unit that fits', () {
      expect(age(const Duration(seconds: 59)), 'hace un momento');
      expect(age(const Duration(minutes: 1)), 'hace 1 min');
      expect(age(const Duration(minutes: 59)), 'hace 59 min');
      expect(age(const Duration(hours: 1)), 'hace 1 h');
      expect(age(const Duration(hours: 23)), 'hace 23 h');
      expect(age(const Duration(days: 3)), 'hace 3 d');
    });

    test('is never negative when the device clock was moved back', () {
      expect(age(const Duration(minutes: -30)), 'hace un momento');
    });
  });

  test('the configuration is named by version and origin', () {
    expect(
      DiagnosticsStrings.config(14, ConfigOrigin.remote),
      'v14 · publicada',
    );
    expect(
      DiagnosticsStrings.config(14, ConfigOrigin.cached),
      'v14 · guardada',
    );
    expect(
      DiagnosticsStrings.config(3, ConfigOrigin.bundled),
      'v3 · incluida en la app',
    );
    expect(DiagnosticsStrings.config(null, null), 'Sin configuración');
  });

  test('the connection is named as the customer would say it', () {
    expect(
      DiagnosticsStrings.connectionStatus(ConnectivityStatus.online),
      'En línea',
    );
    expect(
      DiagnosticsStrings.connectionStatus(ConnectivityStatus.restored),
      'En línea',
    );
    expect(
      DiagnosticsStrings.connectionStatus(ConnectivityStatus.offline),
      'Sin conexión',
    );
    expect(
      DiagnosticsStrings.connectionStatus(ConnectivityStatus.slow),
      'Conexión lenta',
    );
  });

  test('the build is written as version and build number', () {
    expect(
      DiagnosticsStrings.app(const AppInfo(version: '1.0.0', build: '12')),
      '1.0.0 (12)',
    );
  });
}
