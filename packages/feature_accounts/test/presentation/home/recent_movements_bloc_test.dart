import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

typedef _Snapshot = DataSnapshot<List<Movement>>;

void main() {
  const limit = 4;

  late FakeAccountsRepository repository;
  late InMemoryTelemetry telemetry;

  final earlier = now.subtract(const Duration(minutes: 8));
  final saved = _Snapshot(
    value: [salary, coffee],
    origin: DataOrigin.cache,
    syncedAt: earlier,
  );
  final fresh = _Snapshot(
    value: [salary, coffee],
    origin: DataOrigin.server,
    syncedAt: now,
  );
  const unavailable = Failed<_Snapshot>(
    ServiceUnavailableFailure(ServiceIds.movements),
  );

  RecentMovementsBloc build() => RecentMovementsBloc(
    repository: repository,
    limit: limit,
    telemetry: telemetry,
  );

  Completer<Result<_Snapshot>> holdRefresh() {
    final completer = Completer<Result<_Snapshot>>();
    repository.onRefreshRecentMovements = () => completer.future;
    return completer;
  }

  List<TelemetryEvent> eventsNamed(String name) =>
      telemetry.events.where((event) => event.name == name).toList();

  setUp(() {
    repository = FakeAccountsRepository();
    telemetry = InMemoryTelemetry();
  });

  blocTest<RecentMovementsBloc, RecentMovementsState>(
    'shows saved movements while the backend is asked, then its answer',
    build: build,
    act: (bloc) async {
      final refresh = holdRefresh();
      bloc.add(const RecentMovementsStarted());
      await pumpEventQueue();
      repository.recentMovements.add(saved);
      await pumpEventQueue();
      refresh.complete(Success(fresh));
    },
    expect: () => [
      const RecentMovementsState(movements: LoadState(isLoading: true)),
      RecentMovementsState(
        movements: LoadState(
          data: [salary, coffee],
          origin: DataOrigin.cache,
          syncedAt: earlier,
          isLoading: true,
        ),
      ),
      RecentMovementsState(
        movements: LoadState(
          data: [salary, coffee],
          origin: DataOrigin.server,
          syncedAt: now,
        ),
      ),
    ],
    verify: (_) => expect(repository.recentListeners, [limit]),
  );

  blocTest<RecentMovementsBloc, RecentMovementsState>(
    'has nothing to show when the service is down and nothing was saved',
    build: build,
    setUp: () => repository.onRefreshRecentMovements = () async => unavailable,
    act: (bloc) => bloc.add(const RecentMovementsStarted()),
    skip: 1,
    expect: () => [
      const RecentMovementsState(
        movements: LoadState(failure: LoadFailure.unavailable),
      ),
    ],
    verify: (bloc) => expect(bloc.state.movements.hasFailed, isTrue),
  );

  blocTest<RecentMovementsBloc, RecentMovementsState>(
    'keeps what it was showing when a refresh fails',
    build: build,
    act: (bloc) async {
      repository.onRefreshRecentMovements = () async => Success(fresh);
      bloc.add(const RecentMovementsStarted());
      await pumpEventQueue();
      repository.onRefreshRecentMovements = () async => unavailable;
      bloc.add(const RecentMovementsRefreshRequested());
    },
    skip: 3,
    expect: () => [
      RecentMovementsState(
        movements: LoadState(
          data: [salary, coffee],
          origin: DataOrigin.server,
          syncedAt: now,
          failure: LoadFailure.unavailable,
        ),
      ),
    ],
    verify: (bloc) => expect(bloc.state.movements.isOutdated, isTrue),
  );

  group('a listener that fails', () {
    test('as unavailable is shown as that, without an error report', () async {
      final bloc = build()..add(const RecentMovementsStarted());
      await pumpEventQueue();

      repository.recentMovements.addError(
        const ServiceUnavailableFailure(ServiceIds.movements),
        StackTrace.current,
      );
      await pumpEventQueue();

      expect(bloc.state.movements.failure, LoadFailure.unavailable);
      expect(telemetry.errors, isEmpty);
      expect(eventsNamed(AccountsTelemetry.loadFailed).last.parameters, {
        AccountsTelemetry.serviceKey: AccountsTelemetry.movementsService,
        AccountsTelemetry.reasonKey: 'unavailable',
      });
      await bloc.close();
    });

    test('for an unknown reason is reported without its message', () async {
      final bloc = build()..add(const RecentMovementsStarted());
      await pumpEventQueue();

      repository.recentMovements.addError(
        StateError('account 22004821'),
        StackTrace.current,
      );
      await pumpEventQueue();

      expect(bloc.state.movements.failure, LoadFailure.unexpected);
      expect(telemetry.errors.single.error, isA<RedactedError>());
      await bloc.close();
    });

    test('is followed again when the customer retries', () async {
      final bloc = build()..add(const RecentMovementsStarted());
      await pumpEventQueue();
      repository.recentMovements.addError(
        const ServiceUnavailableFailure(ServiceIds.movements),
        StackTrace.current,
      );
      await pumpEventQueue();

      repository.onRefreshRecentMovements = () async => Success(fresh);
      bloc.add(const RecentMovementsRefreshRequested(isRetry: true));
      await pumpEventQueue();

      expect(repository.recentListeners, [limit, limit]);
      expect(bloc.state.movements.failure, isNull);
      expect(
        eventsNamed(AccountsTelemetry.retryRequested).single.parameters,
        {AccountsTelemetry.serviceKey: AccountsTelemetry.movementsService},
      );
      await bloc.close();
    });
  });

  test('a refresh in flight is not started twice', () async {
    final refresh = holdRefresh();
    final bloc = build()..add(const RecentMovementsStarted());
    await pumpEventQueue();

    bloc.add(const RecentMovementsRefreshRequested());
    await pumpEventQueue();

    expect(repository.recentRefreshes, 1);
    refresh.complete(Success(fresh));
    await bloc.close();
  });

  test('stops listening and ignores a late answer once closed', () async {
    final refresh = holdRefresh();
    final bloc = build()..add(const RecentMovementsStarted());
    await pumpEventQueue();

    await bloc.close();
    refresh.complete(Success(fresh));
    await pumpEventQueue();

    expect(repository.recentMovements.hasListener, isFalse);
    expect(bloc.state.movements.hasData, isFalse);
  });
}
