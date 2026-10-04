import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/notifications_wiring.dart';
import 'package:banca_digital/published_faults.dart';
import 'package:banca_digital/saved_customer_data.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:module_kit/module_kit.dart';

/// Which build of the app this is, as the store names it.
@immutable
final class AppInfo {
  const AppInfo({required this.version, required this.build});

  /// `1.0.0`.
  final String version;

  /// The build number within the version: `12`.
  final String build;
}

/// Everything the widget tree needs from outside it.
///
/// `main` builds it from Firebase and device plugins; tests build it from
/// fakes. Nothing below the app widget knows which one it got.
final class AppDependencies {
  const AppDependencies({
    required this.telemetry,
    required this.connectivity,
    required this.authRepository,
    required this.biometrics,
    required this.accountsRepositoryFor,
    required this.transfersRepositoryFor,
    required this.savedCustomerData,
    required this.configRepository,
    required this.publishedFaults,
    required this.homeModules,
    required this.appInfo,
    required this.notifications,
  });

  /// The customer's inbox, this device's registration and the messaging
  /// service.
  final NotificationsDependencies notifications;

  final Telemetry telemetry;

  /// Already started. The app closes it when it is disposed.
  final ConnectivityCubit connectivity;
  final AuthRepository authRepository;
  final BiometricAuthenticator biometrics;

  /// The accounts of the customer with the given uid. Called once per
  /// signed-in session: each customer gets a repository of their own, so
  /// nothing read for one can be shown to the next.
  final AccountsRepository Function(String uid) accountsRepositoryFor;

  /// Transfers and account opening for the customer with the given uid,
  /// through the customer API. One per signed-in session, like the accounts.
  final TransfersRepository Function(String uid) transfersRepositoryFor;

  /// Cleared whenever the session ends, so nothing of a customer stays on
  /// the device after they sign out.
  final SavedCustomerData savedCustomerData;

  /// The published configuration. It is listened to only while a customer
  /// is signed in: reading it needs a session.
  final ConfigRepository configRepository;

  /// Where the resilience policy reads the faults of the configuration in
  /// use. The same instance the policy was built with.
  final PublishedFaults publishedFaults;

  /// Every home module this build can draw, registered by its domain.
  final HomeModuleRegistry homeModules;

  final AppInfo appInfo;
}
