import 'package:app_platform/app_platform.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

/// Reasons attached to errors that no feature caught.
abstract final class ErrorReasons {
  static const String framework = 'flutter_framework';
  static const String uncaught = 'uncaught_async';
}

/// Routes everything nobody handled to [telemetry]: Bloc activity, errors
/// thrown while building or laying out, and uncaught asynchronous errors.
///
/// [presentError] prints a framework error to the console; tests replace it.
void installTelemetry(
  Telemetry telemetry, {
  void Function(FlutterErrorDetails details)? presentError,
}) {
  Bloc.observer = AppBlocObserver(telemetry);

  FlutterError.onError = (details) {
    (presentError ?? FlutterError.presentError)(details);
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
      fatal: true,
    );
    return true;
  };
}
