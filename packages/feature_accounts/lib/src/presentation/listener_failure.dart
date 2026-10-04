import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/src/accounts_telemetry.dart';
import 'package:feature_accounts/src/domain/load_state.dart';

/// Reports that the listener of [service] failed and returns what the
/// failure is.
///
/// A failure the repository already typed, such as a service that is
/// unavailable, is kept as it is. Anything else is unexpected: its message
/// may quote the data it failed on, so only its type is reported.
AppFailure reportListenerFailure(
  Telemetry telemetry, {
  required String service,
  required Object error,
  required StackTrace stackTrace,
}) {
  final failure = switch (error) {
    final AppFailure typed => typed,
    _ => UnexpectedFailure(error, stackTrace),
  };

  telemetry.event(
    AccountsTelemetry.loadFailed,
    parameters: {
      AccountsTelemetry.serviceKey: service,
      AccountsTelemetry.reasonKey: LoadFailure.of(failure).name,
    },
  );
  if (failure is UnexpectedFailure) {
    telemetry.recordError(
      RedactedError(failure.cause.runtimeType),
      failure.stackTrace,
      reason: AccountsTelemetry.unexpectedError,
    );
  }
  return failure;
}
