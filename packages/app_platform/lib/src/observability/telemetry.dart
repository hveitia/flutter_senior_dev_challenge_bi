enum LogLevel { debug, info, warning, error }

/// What the app reports about itself: logs, errors, product events and timed
/// traces. Domain code talks to this interface only; the Firebase-backed
/// implementation lives with the adapters.
///
/// Callers must not pass personal or financial data (names, document or
/// account numbers, amounts). Use ids of things the app defines, such as a
/// module type or a failure kind.
abstract interface class Telemetry {
  void log(
    LogLevel level,
    String message, {
    Map<String, Object> context = const {},
  });

  void recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  });

  void event(String name, {Map<String, Object> parameters = const {}});

  /// Starts timing [name]. The caller stops the returned trace.
  TelemetryTrace startTrace(String name);

  /// Attaches [value] to every later report, for example the configuration
  /// version in use when a crash happens.
  void setContext(String key, String value);
}

abstract interface class TelemetryTrace {
  void setAttribute(String key, String value);

  void stop();
}

/// Discards everything. Default for code that can run without telemetry.
final class NoopTelemetry implements Telemetry {
  const NoopTelemetry();

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object> context = const {},
  }) {}

  @override
  void recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) {}

  @override
  void event(String name, {Map<String, Object> parameters = const {}}) {}

  @override
  TelemetryTrace startTrace(String name) => const _NoopTrace();

  @override
  void setContext(String key, String value) {}
}

final class _NoopTrace implements TelemetryTrace {
  const _NoopTrace();

  @override
  void setAttribute(String key, String value) {}

  @override
  void stop() {}
}
