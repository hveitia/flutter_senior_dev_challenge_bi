import 'dart:convert';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:banca_digital/app_dependencies.dart';
import 'package:banca_digital/composition.dart';
import 'package:banca_digital/published_faults.dart';
import 'package:banca_digital/saved_customer_data.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/testing.dart';

import 'fake_saved_customer_data.dart';

/// One module of a published document.
Map<String, Object?> moduleDocument(
  String id,
  String type, {
  bool visible = true,
  Map<String, Object?> props = const {},
}) {
  return {'id': id, 'type': type, 'visible': visible, 'props': props};
}

/// A published document for the segment `starting`.
Map<String, Object?> homeDocument({
  required List<Map<String, Object?>> modules,
  int configVersion = 14,
  int latencyMs = 0,
  bool movementsUnavailable = false,
}) {
  return {
    'schemaVersion': HomeConfigParser.supportedSchemaVersion,
    'configVersion': configVersion,
    'destinations': ['transfer', 'accounts', 'services', 'profile'],
    'resilience': {
      'latencyMs': latencyMs,
      'movementsUnavailable': movementsUnavailable,
      'partnerInsuranceUnavailable': false,
    },
    'segments': {
      'starting': {
        'label': 'Estoy empezando',
        'modules': modules,
        'features': {'transfers': true, 'partnerServices': true},
      },
    },
  };
}

/// The document a test device starts from, as if it shipped with the app:
/// the modules of the accounts domain, one of the home and one type nobody
/// registered.
final Map<String, Object?> bundledDocument = homeDocument(
  modules: [
    moduleDocument('balance', 'totalBalance'),
    moduleDocument('accounts', 'accountCarousel'),
    moduleDocument(
      'actions',
      'quickActions',
      props: {
        'actions': [
          {
            'label': 'Transferir',
            'icon': 'transfer',
            'destination': 'transfer',
          },
          {'label': 'Pagar', 'icon': 'pay', 'destination': 'services'},
        ],
      },
    ),
    moduleDocument('services', 'serviceRecommendations'),
    moduleDocument('movements', 'recentMovements'),
  ],
);

/// [AppDependencies] made of fakes, with the published configuration driven
/// through [config].
final class TestDependencies {
  TestDependencies({
    FakeAuthRepository? auth,
    AccountsRepository Function(String uid)? accountsRepositoryFor,
    SavedCustomerData? savedData,
    InMemoryTelemetry? telemetry,
    BiometricAuthenticator? biometrics,
  }) : auth = auth ?? FakeAuthRepository(),
       telemetry = telemetry ?? InMemoryTelemetry() {
    dependencies = AppDependencies(
      telemetry: this.telemetry,
      connectivity: ConnectivityCubit(monitor: FakeConnectivityMonitor())
        ..start(),
      authRepository: this.auth,
      biometrics: biometrics ?? FakeBiometricAuthenticator(),
      accountsRepositoryFor:
          accountsRepositoryFor ?? (_) => FakeAccountsRepository(),
      savedCustomerData: savedData ?? FakeSavedCustomerData(),
      configRepository: ConfigRepository(
        source: config,
        store: InMemoryConfigStore(),
        loadBundled: () async => jsonEncode(bundledDocument),
        telemetry: this.telemetry,
      ),
      publishedFaults: faults,
      homeModules: composeHomeModules(),
      appInfo: const AppInfo(version: '1.0.0', build: '12'),
    );
  }

  final FakeAuthRepository auth;
  final InMemoryTelemetry telemetry;

  /// Publishes documents as the backoffice would.
  final FakeConfigSource config = FakeConfigSource();
  final PublishedFaults faults = PublishedFaults();

  late final AppDependencies dependencies;
}
