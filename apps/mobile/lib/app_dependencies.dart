import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/saved_customer_data.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_auth/feature_auth.dart';

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
    required this.savedCustomerData,
  });

  final Telemetry telemetry;

  /// Already started. The app closes it when it is disposed.
  final ConnectivityCubit connectivity;
  final AuthRepository authRepository;
  final BiometricAuthenticator biometrics;

  /// The accounts of the customer with the given uid. Called once per
  /// signed-in session: each customer gets a repository of their own, so
  /// nothing read for one can be shown to the next.
  final AccountsRepository Function(String uid) accountsRepositoryFor;

  /// Cleared whenever the session ends, so nothing of a customer stays on
  /// the device after they sign out.
  final SavedCustomerData savedCustomerData;
}
