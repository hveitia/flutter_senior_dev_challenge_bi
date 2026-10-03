import 'package:app_platform/src/observability/telemetry.dart';

/// Keeps everything it receives so tests can assert on what was reported.
final class InMemoryTelemetry implements Telemetry {
  final List<LogEntry> logs = [];
  final List<ErrorReport> errors = [];
  final List<TelemetryEvent> events = [];
  final List<RecordedTrace> traces = [];
  final Map<String, String> context = {};

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object> context = const {},
  }) {
    logs.add(LogEntry(level: level, message: message, context: context));
  }

  @override
  void recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    errors.add(
      ErrorReport(
        error: error,
        stackTrace: stackTrace,
        reason: reason,
        fatal: fatal,
      ),
    );
  }

  @override
  void event(String name, {Map<String, Object> parameters = const {}}) {
    events.add(TelemetryEvent(name: name, parameters: parameters));
  }

  @override
  TelemetryTrace startTrace(String name) {
    final trace = RecordedTrace(name);
    traces.add(trace);
    return trace;
  }

  @override
  void setContext(String key, String value) => context[key] = value;
}

final class LogEntry {
  const LogEntry({
    required this.level,
    required this.message,
    required this.context,
  });

  final LogLevel level;
  final String message;
  final Map<String, Object> context;
}

final class ErrorReport {
  const ErrorReport({
    required this.error,
    required this.stackTrace,
    required this.reason,
    required this.fatal,
  });

  final Object error;
  final StackTrace stackTrace;
  final String? reason;
  final bool fatal;
}

final class TelemetryEvent {
  const TelemetryEvent({required this.name, required this.parameters});

  final String name;
  final Map<String, Object> parameters;
}

final class RecordedTrace implements TelemetryTrace {
  RecordedTrace(this.name);

  final String name;
  final Map<String, String> attributes = {};
  bool isRunning = true;

  @override
  void setAttribute(String key, String value) => attributes[key] = value;

  @override
  void stop() => isRunning = false;
}
