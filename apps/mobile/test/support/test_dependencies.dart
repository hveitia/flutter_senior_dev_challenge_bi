import 'dart:convert';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:banca_digital/app_dependencies.dart';
import 'package:banca_digital/composition.dart';
import 'package:banca_digital/notifications_wiring.dart';
import 'package:banca_digital/published_faults.dart';
import 'package:banca_digital/saved_customer_data.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/testing.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/testing.dart';
import 'package:feature_services/feature_services.dart';
import 'package:feature_services/testing.dart';

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
    String? partnerOrigin = partnerOriginOfTests,
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
      transfersRepositoryFor: (_) => transfers,
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
      notifications: NotificationsDependencies(
        repositoryFor: (_) => inbox,
        registrations: DeviceRegistrations(
          messaging: messaging,
          devicesFor: (_) => devices,
          identity: const FakeDeviceIdentity(),
          memory: registrationMemory,
          telemetry: this.telemetry,
        ),
        opened: OpenedNotifications(messaging)..start(),
        messaging: messaging,
        memory: primerMemory,
        settings: FakeSystemSettings(),
      ),
      services: ServicesDependencies(
        origin: partnerOrigin == null
            ? null
            : PartnerOrigin.parse(partnerOrigin, isDevelopment: false),
        policy: _policyFollowing(faults),
        telemetry: this.telemetry,
        surfaceFactory: (events) {
          final surface = FakeMiniAppSurface(events);
          miniApps.add(surface);
          return surface;
        },
        externalLinks: FakeExternalLinks(),
        data: miniAppData,
      ),
    );
  }

  /// The customer's inbox, driven by hand.
  final FakeNotificationsRepository inbox = FakeNotificationsRepository();
  final FakeDeviceStore devices = FakeDeviceStore();
  final FakeRegistrationMemory registrationMemory = FakeRegistrationMemory();

  /// The system has not asked about notifications, and the customer already
  /// answered the app's invitation on this device: nothing interrupts a test
  /// that is not about notifications.
  final FakePushMessaging messaging = FakePushMessaging();
  final FakePrimerMemory primerMemory = FakePrimerMemory(wasAnswered: true);

  /// A policy that applies the published faults, tied to [faults] as the
  /// app's own is: told at once when they change.
  static ResiliencePolicy _policyFollowing(PublishedFaults faults) {
    final policy = ResiliencePolicy(
      faults: () => faults.current,
      allowFaultInjection: true,
      delay: (_) async {},
    );
    // Added to whatever already listens, never in its place.
    final previous = faults.onChanged;
    faults.onChanged = () {
      previous?.call();
      policy.faultsChanged();
    };
    return policy;
  }

  /// Where the partners of these tests serve their mini apps.
  static const String partnerOriginOfTests = 'https://partners.example.com';

  /// The surface of every mini app opened, in order. A test plays the
  /// partner's page through the last one.
  final List<FakeMiniAppSurface> miniApps = [];

  /// What partners' pages left on the device, as the mini apps see it.
  final FakeMiniAppData miniAppData = FakeMiniAppData();

  final FakeAuthRepository auth;
  final InMemoryTelemetry telemetry;

  /// Publishes documents as the backoffice would.
  final FakeConfigSource config = FakeConfigSource();
  final PublishedFaults faults = PublishedFaults();

  /// The customer API as the test scripts it.
  final FakeTransfersRepository transfers = FakeTransfersRepository();

  late final AppDependencies dependencies;
}
