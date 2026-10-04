import 'package:app_platform/adapters.dart';
import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app_dependencies.dart';
import 'package:banca_digital/bootstrap.dart';
import 'package:banca_digital/saved_customer_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:feature_accounts/adapters.dart';
import 'package:feature_auth/adapters.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the app's dependencies on Firebase and the device plugins.
///
/// This is the only place that knows the concrete implementations.
Future<AppDependencies> composeDependencies(Telemetry telemetry) async {
  final preferences = await SharedPreferences.getInstance();

  // The policy asks the cubit whether the device is offline, and the cubit
  // listens to the policy to know when requests are slow.
  late final ConnectivityCubit connectivity;
  final policy = ResiliencePolicy(
    // False unless the build sets the flag, which the analyzer cannot know.
    // The faults themselves arrive with the published configuration, once
    // the home starts listening to it.
    // ignore: avoid_redundant_argument_values
    allowFaultInjection: BuildFlags.allowFaultInjection,
    isOffline: () => connectivity.state == ConnectivityStatus.offline,
    telemetry: telemetry,
  );
  connectivity = ConnectivityCubit(
    monitor: ConnectivityPlusMonitor(Connectivity()),
    slowChanges: policy.slowChanges,
  )..start();

  return AppDependencies(
    telemetry: telemetry,
    connectivity: connectivity,
    authRepository: DefaultAuthRepository(
      gateway: FirebaseAuthGateway(FirebaseAuth.instance),
      profiles: FirestoreProfileStore(FirebaseFirestore.instance),
      unlockPreferences: SharedPreferencesUnlockPreferences(preferences),
      policy: policy,
      telemetry: telemetry,
    ),
    biometrics: LocalAuthBiometricAuthenticator(LocalAuthentication()),
    // Firestore keeps its own saved copy on the device, which is the cache
    // the repository reads from when there is no connection.
    accountsRepositoryFor: (uid) => DefaultAccountsRepository(
      source: FirestoreAccountsSource(FirebaseFirestore.instance, uid: uid),
      syncTimes: SharedPreferencesSyncTimes(preferences, uid: uid),
      policy: policy,
      telemetry: telemetry,
    ),
    savedCustomerData: StepwiseSavedCustomerData(
      telemetry: telemetry,
      steps: [
        (name: _databaseStep, run: _clearDatabase),
        (
          name: _syncTimesStep,
          run: () => SharedPreferencesSyncTimes.clearAll(preferences),
        ),
      ],
    ),
  );
}

const String _databaseStep = 'database';
const String _syncTimesStep = 'sync_times';

/// Removes Firestore's saved copy from the device. The database refuses to
/// delete it while it is running, so it is shut down first; the next read
/// starts it again by itself.
Future<void> _clearDatabase() async {
  final firestore = FirebaseFirestore.instance;
  await firestore.terminate();
  await firestore.clearPersistence();
}
