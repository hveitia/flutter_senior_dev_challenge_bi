import 'dart:ui';

import 'package:app_platform/adapters.dart';
import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:banca_digital/bootstrap.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('installTelemetry', () {
    late InMemoryTelemetry telemetry;
    late BlocObserver previousObserver;
    late FlutterExceptionHandler? previousFlutterHandler;
    late ErrorCallback? previousPlatformHandler;

    setUp(() {
      telemetry = InMemoryTelemetry();
      previousObserver = Bloc.observer;
      previousFlutterHandler = FlutterError.onError;
      previousPlatformHandler = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      Bloc.observer = previousObserver;
      FlutterError.onError = previousFlutterHandler;
      PlatformDispatcher.instance.onError = previousPlatformHandler;
    });

    test('reports framework errors as fatal', () {
      installTelemetry(telemetry, presentError: (_) {});
      final error = StateError('layout');
      final stackTrace = StackTrace.current;

      FlutterError.onError!(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );

      final report = telemetry.errors.single;
      expect(report.error, same(error));
      expect(report.stackTrace, same(stackTrace));
      expect(report.reason, ErrorReasons.framework);
      expect(report.fatal, isTrue);
    });

    test('still shows framework errors in the console', () {
      final presented = <FlutterErrorDetails>[];
      installTelemetry(telemetry, presentError: presented.add);

      FlutterError.onError!(FlutterErrorDetails(exception: StateError('x')));

      expect(presented, hasLength(1));
    });

    test('reports uncaught asynchronous errors as non-fatal', () {
      installTelemetry(telemetry, presentError: (_) {});
      final error = StateError('async');

      PlatformDispatcher.instance.onError!(error, StackTrace.empty);

      expect(telemetry.errors.single.error, same(error));
      expect(telemetry.errors.single.reason, ErrorReasons.uncaught);
      expect(telemetry.errors.single.fatal, isFalse);
    });

    test('reports an uncaught error the isolate cannot recover from as '
        'fatal', () {
      installTelemetry(telemetry, presentError: (_) {});

      PlatformDispatcher.instance.onError!(
        const OutOfMemoryError(),
        StackTrace.empty,
      );
      PlatformDispatcher.instance.onError!(
        const StackOverflowError(),
        StackTrace.empty,
      );

      expect(telemetry.errors.map((report) => report.fatal), [true, true]);
    });

    test('marks uncaught errors as handled in a release build', () {
      installTelemetry(telemetry, presentError: (_) {}, debug: false);

      final handled = PlatformDispatcher.instance.onError!(
        StateError('async'),
        StackTrace.empty,
      );

      expect(handled, isTrue);
    });

    test('leaves uncaught errors to the console in a debug build, and still '
        'reports them', () {
      // The default follows the build mode; this test must not depend on it.
      // ignore: avoid_redundant_argument_values
      installTelemetry(telemetry, presentError: (_) {}, debug: true);

      final handled = PlatformDispatcher.instance.onError!(
        StateError('async'),
        StackTrace.empty,
      );

      expect(handled, isFalse);
      expect(telemetry.errors, hasLength(1));
    });

    test('observes every Bloc', () {
      installTelemetry(telemetry, presentError: (_) {});

      expect(Bloc.observer, isA<AppBlocObserver>());
    });
  });

  group('connectTelemetry', () {
    test('returns the telemetry the backend provides', () async {
      final connected = InMemoryTelemetry();

      final telemetry = await connectTelemetry(
        () async => connected,
        presentError: (_) {},
      );

      expect(telemetry, same(connected));
    });

    test('starts the app without telemetry when the backend cannot be '
        'initialized, and shows why in the console', () async {
      final presented = <FlutterErrorDetails>[];
      final failure = StateError('no Firebase app');

      final telemetry = await connectTelemetry(
        () async => throw failure,
        presentError: presented.add,
      );

      expect(telemetry, isA<NoopTelemetry>());
      expect(presented.single.exception, same(failure));
    });
  });

  group('build flags', () {
    test('fault injection is off unless the build asks for it', () {
      expect(BuildFlags.allowFaultInjection, isFalse);
    });
  });

  group('bundled configuration', () {
    test('ships with the app and is accepted by the parser', () async {
      final document = await bundledConfigLoader(rootBundle)();

      expect(
        const HomeConfigParser().parseJson(document),
        isA<ConfigAccepted>(),
      );
    });
  });
}
