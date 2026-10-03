import 'dart:async';
import 'dart:developer' as developer;

import 'package:app_platform/src/observability/telemetry.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// Sends telemetry to Firebase: errors, breadcrumbs and context to
/// Crashlytics, product events to Analytics and traces to Performance.
///
/// Reporting is best effort. A failure in any of the three never reaches the
/// code that reported.
final class FirebaseTelemetry implements Telemetry {
  const FirebaseTelemetry({
    required FirebaseCrashlytics crashlytics,
    required FirebaseAnalytics analytics,
    required FirebasePerformance performance,
  }) : _crashlytics = crashlytics,
       _analytics = analytics,
       _performance = performance;

  /// Telemetry for the Firebase app initialized at startup.
  factory FirebaseTelemetry.forDefaultApp() {
    return FirebaseTelemetry(
      crashlytics: FirebaseCrashlytics.instance,
      analytics: FirebaseAnalytics.instance,
      performance: FirebasePerformance.instance,
    );
  }

  static const String _logName = 'app';

  final FirebaseCrashlytics _crashlytics;
  final FirebaseAnalytics _analytics;
  final FirebasePerformance _performance;

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object> context = const {},
  }) {
    final line = context.isEmpty
        ? '${level.name} $message'
        : '${level.name} $message $context';
    developer.log(line, name: _logName);

    // Debug logs are too frequent to be useful as crash breadcrumbs.
    if (level == LogLevel.debug) return;
    _bestEffort(() => _crashlytics.log(line));
  }

  @override
  void recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    _bestEffort(
      () => _crashlytics.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      ),
    );
  }

  @override
  void event(String name, {Map<String, Object> parameters = const {}}) {
    _bestEffort(() => _analytics.logEvent(name: name, parameters: parameters));
  }

  @override
  TelemetryTrace startTrace(String name) {
    final trace = _performance.newTrace(name);
    _bestEffort(trace.start);
    return _FirebaseTrace(trace);
  }

  @override
  void setContext(String key, String value) {
    _bestEffort(() => _crashlytics.setCustomKey(key, value));
  }
}

final class _FirebaseTrace implements TelemetryTrace {
  const _FirebaseTrace(this._trace);

  final Trace _trace;

  @override
  void setAttribute(String key, String value) =>
      _trace.putAttribute(key, value);

  @override
  void stop() => _bestEffort(_trace.stop);
}

void _bestEffort(Future<void> Function() report) {
  try {
    unawaited(report().catchError((Object _) {}));
  } on Object {
    // Telemetry must never break the feature that is reporting.
  }
}
