import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

typedef _Snapshot = DataSnapshot<List<Movement>>;

/// `MovementsBloc` without an account: the movements of every account.
void main() {
  late FakeAccountsRepository repository;
  late InMemoryTelemetry telemetry;

  /// A page small enough for four movements to fill two of them.
  const pageSize = 2;

  final checkingFee = movement(
    id: 'fee',
    description: 'Comisión mensual',
    amountCents: -250,
    postedAt: DateTime(2026, 10, 3, 9, 30),
    accountId: 'checking',
  );

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
    repository.onRefreshRecentMovements = onRefresh ?? () async => offline;
    final bloc = MovementsBloc(
      repository: repository,
      telemetry: telemetry,
      now: () => now,
      pageSize: size,
    )..add(const MovementsStarted());
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  Future<void> deliver(_Snapshot snapshot) async {
    repository.recentMovements.add(snapshot);
    await pumpEventQueue();
  }

  List<String> visibleIds(MovementsBloc bloc) =>
      bloc.state.visible.map((movement) => movement.id).toList();

  setUp(() {
    repository = FakeAccountsRepository();
    telemetry = InMemoryTelemetry();
  });

  test('follows the latest movements of every account and asks the backend '
      'for them', () async {
    final bloc = await started(
      onRefresh: () async => Success(page([salary, checkingFee])),
    );

    expect(repository.recentListeners, [pageSize]);
    expect(repository.recentRefreshes, 1);
    expect(repository.movementListeners, isEmpty);
    expect(repository.movementRefreshes, 0);
    expect(visibleIds(bloc), ['salary', 'fee']);
  });

  test('asking for more follows a longer page across accounts', () async {
    final bloc = await started();
    await deliver(page([salary, checkingFee]));

    bloc.add(const MovementsMoreRequested());
    await pumpEventQueue();

    expect(repository.recentListeners, [pageSize, pageSize * 2]);
    expect(bloc.state.isLoadingMore, isTrue);

    await deliver(page([salary, checkingFee, groceries, coffee]));

    expect(bloc.state.isLoadingMore, isFalse);
    expect(visibleIds(bloc), ['salary', 'fee', 'groceries', 'coffee']);
    expect(bloc.state.hasMore, isTrue);
  });

  test('a short page means there are no more', () async {
    final bloc = await started();
    await deliver(page([salary]));

    bloc.add(const MovementsMoreRequested());
    await pumpEventQueue();

    expect(bloc.state.hasMore, isFalse);
    expect(repository.recentListeners, [pageSize]);
  });

  test('the filter and the search look through every account', () async {
    final bloc = await started(size: 20);
    await deliver(page([salary, checkingFee, groceries, coffee]));

    bloc.add(const MovementsFilterChanged(MovementFilter.expenses));
    await pumpEventQueue();
    expect(visibleIds(bloc), ['fee', 'groceries', 'coffee']);

    bloc.add(const MovementsSearchChanged('comisión'));
    await pumpEventQueue();
    expect(visibleIds(bloc), ['fee']);
  });

  test('a refresh answered after the page grew does not shrink it', () async {
    final refresh = Completer<Result<_Snapshot>>();
    final bloc = await started(onRefresh: () => refresh.future);
    await deliver(page([salary, checkingFee]));

    bloc.add(const MovementsMoreRequested());
    await pumpEventQueue();
    await deliver(page([salary, checkingFee, groceries, coffee]));

    // The answer to the refresh of the first, shorter page.
    refresh.complete(Success(page([salary, checkingFee])));
    await pumpEventQueue();

    expect(visibleIds(bloc), ['salary', 'fee', 'groceries', 'coffee']);
    expect(bloc.state.movements.isLoading, isFalse);
    expect(bloc.state.movements.failure, isNull);
  });

  test('a service taken down is shown as unavailable, not as an unexpected '
      'error', () async {
    final bloc = await started(onRefresh: () async => Success(page([salary])));

    repository.recentMovements.addError(
      const ServiceUnavailableFailure(ServiceIds.movements),
    );
    await pumpEventQueue();

    expect(bloc.state.movements.failure, LoadFailure.unavailable);
    expect(visibleIds(bloc), ['salary']);
    expect(telemetry.errors, isEmpty);
  });

  test('a retry after the listener broke follows the movements again, so '
      'changes keep arriving', () async {
    final bloc = await started(onRefresh: () async => Success(page([salary])));
    repository.recentMovements.addError(StateError('permission denied'));
    await pumpEventQueue();
    expect(bloc.state.movements.failure, LoadFailure.unexpected);

    bloc.add(const MovementsRefreshRequested(isRetry: true));
    await pumpEventQueue();

    expect(repository.recentListeners, [pageSize, pageSize]);
    expect(bloc.state.movements.failure, isNull);

    await deliver(page([salary, checkingFee]));

    expect(visibleIds(bloc), ['salary', 'fee']);
  });

  test('stops listening once closed', () async {
    final bloc = await started();

    await bloc.close();

    expect(repository.recentMovements.hasListener, isFalse);
  });
}
