import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/api_base_url.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

/// Switches decided when the app is built, set with `--dart-define`.
abstract final class BuildFlags {
  /// Whether this build applies the faults published in the configuration
  /// (added latency, services taken down). Off unless the build is made with
  /// `--dart-define=ALLOW_FAULT_INJECTION=true`, so a production build cannot
  /// be degraded from the backoffice.
  static const bool allowFaultInjection = bool.fromEnvironment(
    'ALLOW_FAULT_INJECTION',
  );

  /// Where the customer API lives (`docs/operacion/api.md`), as given with
  /// `--dart-define=API_BASE_URL=https://…/`. Empty when not given. It is
  /// never used as it is: `apiBaseUrlFor` decides what this build may use.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// How this app was built.
  static const BuildMode mode = kReleaseMode
      ? BuildMode.release
      : (kProfileMode ? BuildMode.profile : BuildMode.debug);
}

/// Reasons attached to errors that no feature caught.
abstract final class ErrorReasons {
  static const String framework = 'flutter_framework';
  static const String uncaught = 'uncaught_async';
  static const String startup = 'startup';
}

/// Returns the telemetry [connect] provides, or one that discards everything
/// when the backend cannot be initialized.
///
/// A failure here must not leave the customer on a blank screen: the app
/// starts anyway and the cause goes to the console through [presentError].
Future<Telemetry> connectTelemetry(
  Future<Telemetry> Function() connect, {
  void Function(FlutterErrorDetails details)? presentError,
}) async {
  try {
    return await connect();
  } on Object catch (error, stackTrace) {
    (presentError ?? FlutterError.presentError)(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: ErrorReasons.startup,
      ),
    );
    return const NoopTelemetry();
  }
}

/// Routes everything nobody handled to [telemetry]: Bloc activity, errors
/// thrown while building or laying out, and uncaught asynchronous errors.
///
/// [presentError] prints a framework error to the console; tests replace it.
/// [debug] tells whether this is a debug build.
void installTelemetry(
  Telemetry telemetry, {
  void Function(FlutterErrorDetails details)? presentError,
  bool debug = kDebugMode,
}) {
  Bloc.observer = AppBlocObserver(telemetry);

  FlutterError.onError = (details) {
    (presentError ?? FlutterError.presentError)(details);
    // Fatal: a build or layout that throws leaves the customer looking at a
    // broken screen, which is what the crash-free metric should count.
    telemetry.recordError(
      details.exception,
      details.stack ?? StackTrace.current,
      reason: ErrorReasons.framework,
      fatal: true,
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    telemetry.recordError(
      error,
      stackTrace,
      reason: ErrorReasons.uncaught,
      fatal: _endsTheIsolate(error),
    );
    // Returning false hands the error back to the engine, which prints it.
    // A developer needs that in the console; a release build has no console.
    return !debug;
  };
}

/// An uncaught asynchronous error usually leaves the app running, so it is
/// reported as non-fatal. These two leave nothing to keep running.
bool _endsTheIsolate(Object error) =>
    error is OutOfMemoryError || error is StackOverflowError;
