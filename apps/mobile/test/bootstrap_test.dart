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

    test('reports uncaught asynchronous errors as fatal and handled', () {
      installTelemetry(telemetry, presentError: (_) {});
      final error = StateError('async');

      final handled = PlatformDispatcher.instance.onError!(
        error,
        StackTrace.empty,
      );

      expect(handled, isTrue);
      expect(telemetry.errors.single.error, same(error));
      expect(telemetry.errors.single.reason, ErrorReasons.uncaught);
      expect(telemetry.errors.single.fatal, isTrue);
    });

    test('observes every Bloc', () {
      installTelemetry(telemetry, presentError: (_) {});

      expect(Bloc.observer, isA<AppBlocObserver>());
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
