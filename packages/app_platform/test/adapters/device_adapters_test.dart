import 'dart:async';

import 'package:app_platform/adapters.dart';
import 'package:app_platform/app_platform.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _MockCrashlytics extends Mock implements FirebaseCrashlytics {}

class _MockAnalytics extends Mock implements FirebaseAnalytics {}

class _MockPerformance extends Mock implements FirebasePerformance {}

class _MockTrace extends Mock implements Trace {}

void main() {
  group('ConnectivityPlusMonitor', () {
    late _MockConnectivity connectivity;
    late StreamController<List<ConnectivityResult>> changes;

    setUp(() {
      connectivity = _MockConnectivity();
      changes = StreamController();
      when(
        () => connectivity.onConnectivityChanged,
      ).thenAnswer((_) => changes.stream);
    });

    test('is online with any kind of connection', () async {
      when(
        connectivity.checkConnectivity,
      ).thenAnswer((_) async => [ConnectivityResult.mobile]);

      expect(await ConnectivityPlusMonitor(connectivity).isOnline(), isTrue);
    });

    test('is offline when the only result is none', () async {
      when(
        connectivity.checkConnectivity,
      ).thenAnswer((_) async => [ConnectivityResult.none]);

      expect(await ConnectivityPlusMonitor(connectivity).isOnline(), isFalse);
    });

    test('emits changes once, ignoring a switch between networks', () async {
      final online = <bool>[];
      final subscription = ConnectivityPlusMonitor(
        connectivity,
      ).onlineChanges.listen(online.add);

      changes
        ..add([ConnectivityResult.wifi])
        ..add([ConnectivityResult.mobile])
        ..add([ConnectivityResult.none])
        ..add([ConnectivityResult.wifi, ConnectivityResult.vpn]);
      await pumpEventQueue();

      expect(online, [true, false, true]);
      await subscription.cancel();
    });
  });

  group('FirebaseTelemetry', () {
    late _MockCrashlytics crashlytics;
    late _MockAnalytics analytics;
    late _MockPerformance performance;
    late _MockTrace trace;
    late FirebaseTelemetry telemetry;

    setUp(() {
      crashlytics = _MockCrashlytics();
      analytics = _MockAnalytics();
      performance = _MockPerformance();
      trace = _MockTrace();

      when(() => crashlytics.log(any())).thenAnswer((_) async {});
      when(
        () => crashlytics.setCustomKey(any(), any<Object>()),
      ).thenAnswer((_) async {});
      when(
        () => crashlytics.recordError(
          any<dynamic>(),
          any(),
          reason: any<dynamic>(named: 'reason'),
          fatal: any(named: 'fatal'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      when(() => performance.newTrace(any())).thenReturn(trace);
      when(trace.start).thenAnswer((_) async {});
      when(trace.stop).thenAnswer((_) async {});

      telemetry = FirebaseTelemetry(
        crashlytics: crashlytics,
        analytics: analytics,
        performance: performance,
      );
    });

    test('leaves a breadcrumb for logs from info upwards', () {
      telemetry.log(
        LogLevel.warning,
        'config_rejected',
        context: {'reason': 'unsupportedSchemaVersion'},
      );

      verify(
        () => crashlytics.log(
          'warning config_rejected {reason: unsupportedSchemaVersion}',
        ),
      ).called(1);
    });

    test('keeps debug logs off the crash report', () {
      telemetry.log(LogLevel.debug, 'bloc_state_changed');

      verifyNever(() => crashlytics.log(any()));
    });

    test('sends errors to Crashlytics with reason and severity', () {
      final error = StateError('boom');
      final stackTrace = StackTrace.current;

      telemetry.recordError(error, stackTrace, reason: 'bloc', fatal: true);

      verify(
        () => crashlytics.recordError(
          error,
          stackTrace,
          reason: 'bloc',
          fatal: true,
        ),
      ).called(1);
    });

    test('sends events to Analytics', () {
      telemetry.event('transfer_queued', parameters: {'attempt': 2});

      verify(
        () => analytics.logEvent(
          name: 'transfer_queued',
          parameters: {'attempt': 2},
        ),
      ).called(1);
    });

    test('attaches context to later crash reports', () {
      telemetry.setContext('config_version', '14');

      verify(
        () => crashlytics.setCustomKey('config_version', '14'),
      ).called(1);
    });

    test('times a trace from start to stop with its attributes', () {
      final running = telemetry.startTrace('home_load')
        ..setAttribute('origin', 'cached');

      verify(() => performance.newTrace('home_load')).called(1);
      verify(trace.start).called(1);
      verify(() => trace.putAttribute('origin', 'cached')).called(1);
      verifyNever(trace.stop);

      running.stop();

      verify(trace.stop).called(1);
    });

    test('a failing backend never reaches the caller', () async {
      when(
        () => crashlytics.log(any()),
      ).thenAnswer((_) async => throw StateError('crashlytics down'));
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenThrow(StateError('analytics down'));

      telemetry
        ..log(LogLevel.error, 'anything')
        ..event('anything');
      await pumpEventQueue();
    });
  });
}
