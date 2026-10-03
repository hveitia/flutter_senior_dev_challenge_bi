import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryTelemetry telemetry;

  setUp(() => telemetry = InMemoryTelemetry());

  test('keeps logs with their level and context', () {
    telemetry.log(
      LogLevel.warning,
      'config_rejected',
      context: {'reason': 'unsupportedSchemaVersion'},
    );

    final entry = telemetry.logs.single;
    expect(entry.level, LogLevel.warning);
    expect(entry.message, 'config_rejected');
    expect(entry.context, {'reason': 'unsupportedSchemaVersion'});
  });

  test('keeps reported errors with reason and severity', () {
    final error = StateError('boom');

    telemetry.recordError(
      error,
      StackTrace.empty,
      reason: 'bloc',
      fatal: true,
    );

    final report = telemetry.errors.single;
    expect(report.error, same(error));
    expect(report.reason, 'bloc');
    expect(report.fatal, isTrue);
  });

  test('keeps events with their parameters', () {
    telemetry.event('transfer_queued', parameters: {'attempt': 2});

    expect(telemetry.events.single.name, 'transfer_queued');
    expect(telemetry.events.single.parameters, {'attempt': 2});
  });

  test('keeps the latest value of each context key', () {
    telemetry
      ..setContext('config_version', '13')
      ..setContext('config_version', '14');

    expect(telemetry.context, {'config_version': '14'});
  });

  test('tracks a trace from start to stop with its attributes', () {
    final trace = telemetry.startTrace('home_load')
      ..setAttribute('origin', 'cached');

    expect(telemetry.traces.single.name, 'home_load');
    expect(telemetry.traces.single.isRunning, isTrue);

    trace.stop();

    expect(telemetry.traces.single.isRunning, isFalse);
    expect(telemetry.traces.single.attributes, {'origin': 'cached'});
  });

  test('the no-op implementation accepts every call', () {
    const NoopTelemetry()
      ..log(LogLevel.info, 'ignored')
      ..recordError(StateError('ignored'), StackTrace.empty)
      ..event('ignored')
      ..setContext('key', 'value')
      ..startTrace('ignored').stop();
  });
}
