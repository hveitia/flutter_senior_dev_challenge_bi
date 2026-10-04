import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/data/default_accounts_repository.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  late FakeAccountsSource source;
  late InMemorySyncTimes syncTimes;
  late InMemoryTelemetry telemetry;
  late bool offline;
  late ResilienceSettings faults;

  final earlier = now.subtract(const Duration(minutes: 8));

  DefaultAccountsRepository repository() {
    return DefaultAccountsRepository(
      source: source,
      syncTimes: syncTimes,
      telemetry: telemetry,
      now: () => now,
      policy: ResiliencePolicy(
        isOffline: () => offline,
        faults: () => faults,
        allowFaultInjection: true,
        // Backoff ends at once: the test is about what happens, not when.
        delay: (_) async {},
      ),
    );
  }

  /// What the listener emits after [push] has run.
  Future<List<DataSnapshot<List<T>>>> emitted<T>(
    Stream<DataSnapshot<List<T>>> stream,
    void Function() push,
  ) async {
    final received = <DataSnapshot<List<T>>>[];
    final subscription = stream.listen(received.add);
    push();
    await pumpEventQueue();
    await subscription.cancel();
    return received;
  }

  List<TelemetryEvent> eventsNamed(String name) =>
      telemetry.events.where((event) => event.name == name).toList();

  setUp(() {
    source = FakeAccountsSource();
    syncTimes = InMemorySyncTimes();
    telemetry = InMemoryTelemetry();
    offline = false;
    faults = ResilienceSettings.none;
  });

  group('watchAccounts', () {
    test('data confirmed by the backend is fresh as of now', () async {
      final received = await emitted(
        repository().watchAccounts(),
        () => source.accounts.add(
          const SourceSnapshot([savings], fromCache: false),
        ),
      );

      expect(received, [
        DataSnapshot<List<Account>>(
          value: const [savings],
          origin: DataOrigin.server,
          syncedAt: now,
        ),
      ]);
      expect(syncTimes.times.values, [now]);
    });

    test('saved data carries the time of the last synchronization', () async {
      final repo = repository();
      await syncTimes.record('accounts', earlier);

      final received = await emitted(
        repo.watchAccounts(),
        () => source.accounts.add(
          const SourceSnapshot([savings], fromCache: true),
        ),
      );

      expect(received.single.origin, DataOrigin.cache);
      expect(received.single.syncedAt, earlier);
      expect(syncTimes.times.values, [earlier]);
    });

    test('an empty copy on a device that never synchronized says nothing, '
        'so it is not shown as "no accounts"', () async {
      final received = await emitted(
        repository().watchAccounts(),
        () => source.accounts.add(
          const SourceSnapshot<Account>([], fromCache: true),
        ),
      );

      expect(received, isEmpty);
    });

    test(
      'an empty copy is believed once the device has synchronized',
      () async {
        final repo = repository();
        await syncTimes.record('accounts', earlier);

        final received = await emitted(
          repo.watchAccounts(),
          () => source.accounts.add(
            const SourceSnapshot<Account>([], fromCache: true),
          ),
        );

        expect(received.single.value, isEmpty);
        expect(received.single.origin, DataOrigin.cache);
      },
    );

    test(
      'lists savings before checking whatever order they arrive in',
      () async {
        final received = await emitted(
          repository().watchAccounts(),
          () => source.accounts.add(
            const SourceSnapshot([checking, savings], fromCache: false),
          ),
        );

        expect(received.single.value, [savings, checking]);
      },
    );

    test('keeps delivering when the sync time cannot be stored', () async {
      syncTimes.failsToRecord = true;

      final received = await emitted(
        repository().watchAccounts(),
        () => source.accounts.add(
          const SourceSnapshot([savings], fromCache: false),
        ),
      );

      expect(received.single.syncedAt, now);
    });

    test('reports once that data was served from the saved copy, '
        'with the count only', () async {
      final repo = repository();
      await syncTimes.record('accounts', earlier);

      await emitted(repo.watchAccounts(), () {
        source.accounts
          ..add(const SourceSnapshot([savings, checking], fromCache: true))
          ..add(const SourceSnapshot([savings, checking], fromCache: true));
      });

      final events = eventsNamed(AccountsTelemetry.servedFromCache);
      expect(events, hasLength(1));
      expect(events.single.parameters, {
        AccountsTelemetry.serviceKey: AccountsTelemetry.accountsService,
        AccountsTelemetry.countKey: 2,
      });
    });
  });

  group('documents the source could not read', () {
    test('the listener says how many are missing from what it '
        'delivers', () async {
      final received = await emitted(
        repository().watchAccounts(),
        () => source.accounts.add(
          const SourceSnapshot([savings], fromCache: false, skipped: 1),
        ),
      );

      expect(received.single.value, [savings]);
      expect(received.single.skipped, 1);
    });

    test('a refresh says it too', () async {
      source
        ..onFetchAccounts = (() async => [savings])
        ..skippedOnFetch = 2;

      final result = await repository().refreshAccounts();

      expect((result as Success<DataSnapshot<List<Account>>>).value.skipped, 2);
    });

    test('are reported with the service and the count only, once per '
        'change', () async {
      await emitted(repository().watchAccounts(), () {
        source.accounts
          ..add(const SourceSnapshot([savings], fromCache: true, skipped: 1))
          ..add(const SourceSnapshot([savings], fromCache: false, skipped: 1))
          ..add(const SourceSnapshot([savings], fromCache: false, skipped: 2))
          ..add(const SourceSnapshot([savings], fromCache: false));
      });

      final events = eventsNamed(AccountsTelemetry.documentsSkipped);
      expect(events.map((event) => event.parameters), [
        {
          AccountsTelemetry.serviceKey: AccountsTelemetry.accountsService,
          AccountsTelemetry.countKey: 1,
        },
        {
          AccountsTelemetry.serviceKey: AccountsTelemetry.accountsService,
          AccountsTelemetry.countKey: 2,
        },
      ]);
    });

    test('a refresh reports them against its own service', () async {
      source
        ..onFetchMovements = (() async => [salary])
        ..skippedOnFetch = 3;

      await repository().refreshMovements('savings', limit: 20);

      expect(
        eventsNamed(AccountsTelemetry.documentsSkipped).single.parameters,
        {
          AccountsTelemetry.serviceKey: AccountsTelemetry.movementsService,
          AccountsTelemetry.countKey: 3,
        },
      );
    });

    test('nothing is reported when everything was read', () async {
      source.onFetchAccounts = () async => [savings];

      await repository().refreshAccounts();

      expect(eventsNamed(AccountsTelemetry.documentsSkipped), isEmpty);
    });
  });

  group('refreshAccounts', () {
    test(
      'returns what the backend has and records the synchronization',
      () async {
        source.onFetchAccounts = () async => const [checking, savings];

        final result = await repository().refreshAccounts();

        expect(
          result,
          isA<Success<DataSnapshot<List<Account>>>>().having(
            (success) => success.value,
            'value',
            DataSnapshot<List<Account>>(
              value: const [savings, checking],
              origin: DataOrigin.server,
              syncedAt: now,
            ),
          ),
        );
        expect(syncTimes.lastSync('accounts'), now);
      },
    );

    test('does not ask the backend when the device is offline', () async {
      offline = true;

      final result = await repository().refreshAccounts();

      expect(
        result,
        isA<Failed<DataSnapshot<List<Account>>>>().having(
          (failed) => failed.failure,
          'failure',
          isA<OfflineFailure>(),
        ),
      );
      expect(source.accountFetches, 0);
    });

    test(
      'tries three times when the backend is unavailable, then gives up',
      () async {
        source.onFetchAccounts = () async =>
            throw const ServiceUnavailableFailure();

        final result = await repository().refreshAccounts();

        expect(result, isA<Failed<DataSnapshot<List<Account>>>>());
        expect(source.accountFetches, ResiliencePolicy.maxAttempts);
        expect(syncTimes.times, isEmpty);
      },
    );

    test('reports a failure with the service and its kind only', () async {
      source.onFetchAccounts = () async =>
          throw const ServiceUnavailableFailure();

      await repository().refreshAccounts();

      expect(eventsNamed(AccountsTelemetry.loadFailed).single.parameters, {
        AccountsTelemetry.serviceKey: AccountsTelemetry.accountsService,
        AccountsTelemetry.reasonKey: 'unavailable',
      });
    });

    test('reports an unexpected error without its message', () async {
      source.onFetchAccounts = () async =>
          throw StateError('account 22004821 holds 3570.35');

      final result = await repository().refreshAccounts();

      expect(result, isA<Failed<DataSnapshot<List<Account>>>>());
      expect(source.accountFetches, 1);
      final report = telemetry.errors.single;
      expect(report.error, isA<RedactedError>());
      expect('${report.error}', isNot(contains('22004821')));
      expect(report.reason, AccountsTelemetry.unexpectedError);
      expect(report.fatal, isFalse);
    });
  });

  group('movements', () {
    test('listens to the requested account and page', () async {
      final received = await emitted(
        repository().watchMovements('savings', limit: 20),
        () => source.movements.add(
          SourceSnapshot([salary, groceries], fromCache: false),
        ),
      );

      expect(source.movementRequests, [('savings', 20)]);
      expect(received.single.value, [salary, groceries]);
      expect(received.single.origin, DataOrigin.server);
    });

    test('keeps a synchronization time per account', () async {
      final repo = repository();
      await emitted(
        repo.watchMovements('savings', limit: 20),
        () => source.movements.add(
          SourceSnapshot([salary], fromCache: false),
        ),
      );

      final other = await emitted(
        repo.watchMovements('checking', limit: 20),
        () => source.movements.add(SourceSnapshot([coffee], fromCache: true)),
      );

      expect(other.single.syncedAt, isNull);
    });

    test('refresh returns the page the backend has', () async {
      source.onFetchMovements = () async => [salary, groceries];

      final result = await repository().refreshMovements('savings', limit: 20);

      expect(
        result,
        isA<Success<DataSnapshot<List<Movement>>>>().having(
          (success) => success.value.value,
          'movements',
          [salary, groceries],
        ),
      );
      expect(source.movementRequests, [('savings', 20)]);
    });

    test('movements can be down while accounts keep answering', () async {
      faults = const ResilienceSettings(
        latency: Duration.zero,
        unavailableServices: {ServiceIds.movements},
      );
      Future<List<Account>> accountsFromBackend() async => const [savings];
      Future<List<Movement>> movementsFromBackend() async => [salary];
      source
        ..onFetchAccounts = accountsFromBackend
        ..onFetchMovements = movementsFromBackend;
      final repo = repository();

      final accounts = await repo.refreshAccounts();
      final movementsResult = await repo.refreshMovements('savings', limit: 20);

      expect(accounts, isA<Success<DataSnapshot<List<Account>>>>());
      expect(
        movementsResult,
        isA<Failed<DataSnapshot<List<Movement>>>>().having(
          (failed) => failed.failure,
          'failure',
          isA<ServiceUnavailableFailure>(),
        ),
      );
      expect(source.movementFetches, 0);
      expect(eventsNamed(AccountsTelemetry.loadFailed).single.parameters, {
        AccountsTelemetry.serviceKey: AccountsTelemetry.movementsService,
        AccountsTelemetry.reasonKey: 'unavailable',
      });
    });
  });

  group('a listener whose service was taken down', () {
    const movementsDown = ResilienceSettings(
      latency: Duration.zero,
      unavailableServices: {ServiceIds.movements},
    );

    /// What the listener emits, with errors kept in their place.
    Future<List<Object>> outcomes<T>(
      Stream<DataSnapshot<List<T>>> stream,
      void Function() push,
    ) async {
      final received = <Object>[];
      final subscription = stream.listen(
        received.add,
        onError: received.add,
      );
      push();
      await pumpEventQueue();
      await subscription.cancel();
      return received;
    }

    test('fails as unavailable instead of delivering', () async {
      faults = movementsDown;

      final received = await outcomes(
        repository().watchMovements('savings', limit: 20),
        () => source.movements.add(SourceSnapshot([salary], fromCache: false)),
      );

      expect(received.single, isA<ServiceUnavailableFailure>());
      expect(syncTimes.times, isEmpty);
    });

    test('delivers again once the service is back', () async {
      faults = movementsDown;
      final received = <Object>[];
      final subscription = repository()
          .watchMovements('savings', limit: 20)
          .listen(
            received.add,
            onError: received.add,
          );

      source.movements.add(SourceSnapshot([salary], fromCache: false));
      await pumpEventQueue();
      faults = ResilienceSettings.none;
      source.movements.add(SourceSnapshot([salary], fromCache: false));
      await pumpEventQueue();
      await subscription.cancel();

      expect(received, [
        isA<ServiceUnavailableFailure>(),
        isA<DataSnapshot<List<Movement>>>(),
      ]);
    });

    test('leaves the listeners of other services alone', () async {
      faults = movementsDown;

      final received = await outcomes(
        repository().watchAccounts(),
        () => source.accounts.add(
          const SourceSnapshot([savings], fromCache: false),
        ),
      );

      expect(received.single, isA<DataSnapshot<List<Account>>>());
    });
  });

  group('recent movements', () {
    test('are followed across accounts, up to the limit', () async {
      final received = await emitted(
        repository().watchRecentMovements(limit: 4),
        () => source.recentMovements.add(
          SourceSnapshot([salary, coffee], fromCache: false),
        ),
      );

      expect(source.recentLimits, [4]);
      expect(received.single.value, [salary, coffee]);
      expect(received.single.origin, DataOrigin.server);
    });

    test('keep a synchronization time of their own', () async {
      final repo = repository();
      await emitted(
        repo.watchMovements('savings', limit: 20),
        () => source.movements.add(SourceSnapshot([salary], fromCache: false)),
      );

      final recent = await emitted(
        repo.watchRecentMovements(limit: 4),
        () => source.recentMovements.add(
          SourceSnapshot([salary], fromCache: true),
        ),
      );

      expect(recent.single.syncedAt, isNull);
    });

    test('refresh asks the backend through the movements service', () async {
      source.onFetchRecentMovements = () async => [salary, groceries];

      final result = await repository().refreshRecentMovements(limit: 4);

      expect(
        result,
        isA<Success<DataSnapshot<List<Movement>>>>().having(
          (success) => success.value.value,
          'movements',
          [salary, groceries],
        ),
      );
      expect(source.recentLimits, [4]);
    });

    test('go down with the movements service', () async {
      faults = const ResilienceSettings(
        latency: Duration.zero,
        unavailableServices: {ServiceIds.movements},
      );
      source.onFetchRecentMovements = () async => [salary];

      final result = await repository().refreshRecentMovements(limit: 4);

      expect(
        result,
        isA<Failed<DataSnapshot<List<Movement>>>>().having(
          (failed) => failed.failure,
          'failure',
          isA<ServiceUnavailableFailure>(),
        ),
      );
      expect(source.recentFetches, 0);
    });
  });
}
