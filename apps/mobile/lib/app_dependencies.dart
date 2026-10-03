import 'package:app_platform/app_platform.dart';
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
  });

  final Telemetry telemetry;

  /// Already started. The app closes it when it is disposed.
  final ConnectivityCubit connectivity;
  final AuthRepository authRepository;
  final BiometricAuthenticator biometrics;
}
