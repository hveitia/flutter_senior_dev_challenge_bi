import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:feature_notifications/adapters.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  late FakeInboxSource source;
  late InMemoryTelemetry telemetry;
  late ResilienceSettings faults;
  late ResiliencePolicy policy;
  late DefaultNotificationsRepository repository;

  const down = ResilienceSettings(
    latency: Duration.zero,
    unavailableServices: {NotificationsTelemetry.service},
  );

  setUp(() {
    source = FakeInboxSource();
    telemetry = InMemoryTelemetry();
    faults = ResilienceSettings.none;
    policy = ResiliencePolicy(
      faults: () => faults,
      allowFaultInjection: true,
    );
    repository = DefaultNotificationsRepository(
      source: source,
      policy: policy,
      telemetry: telemetry,
    );
  });

  test('passes on what the listener delivers, saved or fresh', () async {
    final deliveries = <InboxSnapshot>[];
    final subscription = repository.watchInbox().listen(deliveries.add);

    source.deliveries
      ..add(saved([salary]))
      ..add(fresh([salary, signIn]));
    await pumpEventQueue();

    expect(deliveries, [
      saved([salary]),
      fresh([salary, signIn]),
    ]);
    await subscription.cancel();
  });

  test('a service taken down fails its listener at once and recovers when '
      'the fault is lifted', () async {
    final deliveries = <InboxSnapshot>[];
    final errors = <Object>[];
    final subscription = repository.watchInbox().listen(
      deliveries.add,
      onError: errors.add,
    );
    source.deliveries.add(fresh([salary]));
    await pumpEventQueue();

    faults = down;
    policy.faultsChanged();
    await pumpEventQueue();

    expect(errors.single, isA<ServiceUnavailableFailure>());

    faults = ResilienceSettings.none;
    policy.faultsChanged();
    await pumpEventQueue();

    expect(deliveries, [
      fresh([salary]),
      fresh([salary]),
    ]);
    await subscription.cancel();
  });

  test('a refresh that cannot reach the backend is a typed failure, reported '
      'by reason only', () async {
    source.onFetch = () async => throw StateError(salary.title);

    final result = await repository.refreshInbox();

    expect(result, isA<Failed<InboxSnapshot>>());
    expect(telemetry.events.single.name, NotificationsTelemetry.loadFailed);
    expect(telemetry.events.single.parameters, {
      NotificationsTelemetry.reasonKey: 'unexpected',
    });
    expect(
      telemetry.errors.single.error.toString(),
      isNot(contains(salary.title)),
    );
  });

  test('marks a notification as read through the source', () async {
    final result = await repository.markRead(salary.id);

    expect(result, isA<Success<void>>());
    expect(source.markedRead, [salary.id]);
  });

  test('marking as read fails as a result, never as an exception', () async {
    source.onMarkRead = (_) async => throw StateError('down');

    final result = await repository.markRead(salary.id);

    expect(result, isA<Failed<void>>());
    expect(source.markedRead, isEmpty);
  });
}
