import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

typedef _Snapshot = DataSnapshot<List<Movement>>;

void main() {
  late FakeAccountsRepository repository;
  late InMemoryTelemetry telemetry;

  /// A page small enough for four movements to fill two of them.
  const pageSize = 2;

  _Snapshot page(
    List<Movement> items, {
    DataOrigin origin = DataOrigin.server,
  }) {
    return _Snapshot(value: items, origin: origin, syncedAt: now);
  }

  const offline = Failed<_Snapshot>(OfflineFailure());

  Future<MovementsBloc> started({
    Future<Result<_Snapshot>> Function()? onRefresh,
    int size = pageSize,
  }) async {
    repository.onRefreshMovements = onRefresh ?? () async => offline;
    final bloc = MovementsBloc(
      repository: repository,
      accountId: 'savings',
      telemetry: telemetry,
      now: () => now,
      pageSize: size,
    )..add(const MovementsStarted());
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  Future<void> deliver(_Snapshot snapshot) async {
    repository.movements.add(snapshot);
    await pumpEventQueue();
  }

  List<String> visibleIds(MovementsBloc bloc) =>
      bloc.state.visible.map((movement) => movement.id).toList();

  setUp(() {
    repository = FakeAccountsRepository();
    telemetry = InMemoryTelemetry();
  });

  test('follows the first page of the account and asks the backend', () async {
    final bloc = await started(onRefresh: () async => page(movements).ok);

    expect(repository.movementListeners, [('savings', pageSize)]);
    expect(repository.movementRefreshes, 1);
    expect(bloc.state.movements.data, movements);
    expect(bloc.state.movements.isLoading, isFalse);
    expect(visibleIds(bloc), ['salary', 'groceries', 'coffee', 'received']);
  });

  test('shows saved movements while the backend has not answered', () async {
    final refresh = Completer<Result<_Snapshot>>();
    final bloc = await started(onRefresh: () => refresh.future);

    expect(bloc.state.movements.isWaiting, isTrue);
    await deliver(page([salary], origin: DataOrigin.cache));

    expect(visibleIds(bloc), ['salary']);
    expect(bloc.state.movements.origin, DataOrigin.cache);
    expect(bloc.state.movements.isLoading, isTrue);
    refresh.complete(offline);
  });

  test(
    'fails when nothing was saved and the backend cannot be reached',
    () async {
      final bloc = await started();

      expect(bloc.state.movements.hasFailed, isTrue);
      expect(bloc.state.movements.failure, LoadFailure.offline);
      expect(bloc.state.visible, isEmpty);
    },
  );

  test('a retry is reported with the movements service only', () async {
    final bloc = await started();

    repository.onRefreshMovements = () async => page([salary]).ok;
    bloc.add(const MovementsRefreshRequested(isRetry: true));
    await pumpEventQueue();

    expect(visibleIds(bloc), ['salary']);
    final retries = telemetry.events.where(
      (event) => event.name == AccountsTelemetry.retryRequested,
    );
    expect(retries.single.parameters, {
      AccountsTelemetry.serviceKey: AccountsTelemetry.movementsService,
    });
  });

  group('narrowing the list', () {
    late MovementsBloc bloc;

    setUp(() async {
      bloc = await started(size: 20);
      await deliver(page(movements));
    });

    test('a filter keeps only what passes it', () async {
      bloc.add(const MovementsFilterChanged(MovementFilter.income));
      await pumpEventQueue();

      expect(visibleIds(bloc), ['salary', 'received']);
      expect(bloc.state.isNarrowed, isTrue);
      expect(bloc.state.movements.data, movements);
    });

    test('this month is decided by the injected clock', () async {
      bloc.add(const MovementsFilterChanged(MovementFilter.thisMonth));
      await pumpEventQueue();

      expect(visibleIds(bloc), ['salary', 'groceries', 'coffee']);
    });

    test('the search and the filter apply together', () async {
      bloc
        ..add(const MovementsFilterChanged(MovementFilter.expenses))
        ..add(const MovementsSearchChanged('cafe'));
      await pumpEventQueue();

      expect(visibleIds(bloc), ['coffee']);
    });

    test('clearing the search shows the list again', () async {
      bloc.add(const MovementsSearchChanged('super'));
      await pumpEventQueue();
      bloc.add(const MovementsSearchChanged(''));
      await pumpEventQueue();

      expect(bloc.state.visible, movements);
      expect(bloc.state.isNarrowed, isFalse);
    });

    test('a new delivery is narrowed the same way', () async {
      bloc.add(const MovementsFilterChanged(MovementFilter.income));
      await pumpEventQueue();

      await deliver(page([salary, groceries]));

      expect(visibleIds(bloc), ['salary']);
    });
  });

  group('older movements', () {
    test('a full page means there may be more', () async {
      final bloc = await started();
      await deliver(page([salary, groceries]));

      expect(bloc.state.hasMore, isTrue);
    });

    test('a short page means there are no more', () async {
      final bloc = await started();
      await deliver(page([salary]));

      expect(bloc.state.hasMore, isFalse);
    });

    test('asking for more follows a longer page of the same account', () async {
      final bloc = await started();
      await deliver(page([salary, groceries]));
      final firstPage = repository.movements;

      bloc.add(const MovementsMoreRequested());
      await pumpEventQueue();

      expect(repository.movementListeners, [
        ('savings', pageSize),
        ('savings', pageSize * 2),
      ]);
      expect(firstPage.hasListener, isFalse);
      expect(bloc.state.isLoadingMore, isTrue);
      expect(visibleIds(bloc), ['salary', 'groceries']);

      await deliver(page(movements));

      expect(bloc.state.isLoadingMore, isFalse);
      expect(bloc.state.visible, movements);
      expect(bloc.state.hasMore, isTrue);
    });

    test('does nothing when there are no more', () async {
      final bloc = await started();
      await deliver(page([salary]));

      bloc.add(const MovementsMoreRequested());
      await pumpEventQueue();

      expect(repository.movementListeners, hasLength(1));
      expect(bloc.state.isLoadingMore, isFalse);
    });

    test('a refresh answered after the page grew does not shrink it', () async {
      final refresh = Completer<Result<_Snapshot>>();
      final bloc = await started(onRefresh: () => refresh.future);
      await deliver(page([salary, groceries]));

      bloc.add(const MovementsMoreRequested());
      await pumpEventQueue();
      await deliver(page(movements));

      // The answer to the refresh of the first, shorter page.
      refresh.complete(page([salary, groceries]).ok);
      await pumpEventQueue();

      expect(bloc.state.visible, movements);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.movements.isLoading, isFalse);
      expect(bloc.state.movements.failure, isNull);
    });

    test('a refresh that fails after the page grew is still a failure, and '
        'keeps the longer page', () async {
      final refresh = Completer<Result<_Snapshot>>();
      final bloc = await started(onRefresh: () => refresh.future);
      await deliver(page([salary, groceries], origin: DataOrigin.cache));

      bloc.add(const MovementsMoreRequested());
      await pumpEventQueue();
      await deliver(page(movements, origin: DataOrigin.cache));

      refresh.complete(const Failed(TimeoutFailure()));
      await pumpEventQueue();

      expect(bloc.state.visible, movements);
      expect(bloc.state.movements.failure, LoadFailure.timeout);
    });

    test('does not skip a page when asked twice in a row', () async {
      final bloc = await started();
      await deliver(page([salary, groceries]));

      bloc
        ..add(const MovementsMoreRequested())
        ..add(const MovementsMoreRequested());
      await pumpEventQueue();

      expect(repository.movementListeners.last, ('savings', pageSize * 2));
    });
  });

  test('a listener that breaks is reported without its message', () async {
    final bloc = await started();

    repository.movements.addError(StateError('Nómina 1850.00'));
    await pumpEventQueue();

    expect(bloc.state.movements.failure, LoadFailure.unexpected);
    final report = telemetry.errors.single;
    expect(report.error, isA<RedactedError>());
    expect('${report.error}', isNot(contains('1850')));
  });

  test('times the first load and says how many movements were shown', () async {
    final refresh = Completer<Result<_Snapshot>>();
    await started(onRefresh: () => refresh.future);

    final trace = telemetry.traces.single;
    expect(trace.name, AccountsTelemetry.movementsFirstLoad);
    expect(trace.isRunning, isTrue);

    await deliver(page([salary, groceries]));

    expect(trace.isRunning, isFalse);
    expect(trace.attributes, {
      AccountsTelemetry.originKey: 'server',
      AccountsTelemetry.countKey: '2',
    });
    refresh.complete(offline);
  });

  test('stops listening once closed', () async {
    final bloc = await started();

    await bloc.close();

    expect(repository.movements.hasListener, isFalse);
  });
}

extension on DataSnapshot<List<Movement>> {
  /// This snapshot as the successful answer of a refresh.
  Result<DataSnapshot<List<Movement>>> get ok => Success(this);
}
