import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

typedef _Snapshot = DataSnapshot<List<Account>>;

void main() {
  late FakeAccountsRepository repository;
  late InMemoryTelemetry telemetry;

  final earlier = now.subtract(const Duration(minutes: 8));
  final saved = _Snapshot(
    value: const [savings, checking],
    origin: DataOrigin.cache,
    syncedAt: earlier,
  );
  final fresh = _Snapshot(
    value: const [savings, checking],
    origin: DataOrigin.server,
    syncedAt: now,
  );
  const timedOut = Failed<_Snapshot>(TimeoutFailure());

  AccountsBloc build() =>
      AccountsBloc(repository: repository, telemetry: telemetry);

  /// Makes every refresh wait until the returned completer is completed.
  Completer<Result<_Snapshot>> holdRefresh() {
    final completer = Completer<Result<_Snapshot>>();
    repository.onRefreshAccounts = () => completer.future;
    return completer;
  }

  setUp(() {
    repository = FakeAccountsRepository();
    telemetry = InMemoryTelemetry();
  });

  blocTest<AccountsBloc, AccountsState>(
    'shows saved data while the backend is asked, then what it answers',
    build: build,
    act: (bloc) async {
      final refresh = holdRefresh();
      bloc.add(const AccountsStarted());
      await pumpEventQueue();
      repository.accounts.add(saved);
      await pumpEventQueue();
      refresh.complete(Success(fresh));
    },
    expect: () => [
      const AccountsState(accounts: LoadState(isLoading: true)),
      AccountsState(
        accounts: LoadState(
          data: const [savings, checking],
          origin: DataOrigin.cache,
          syncedAt: earlier,
          isLoading: true,
        ),
      ),
      AccountsState(
        accounts: LoadState(
          data: const [savings, checking],
          origin: DataOrigin.server,
          syncedAt: now,
        ),
      ),
    ],
    verify: (bloc) {
      expect(bloc.state.totalCents, 482035);
      expect(bloc.state.byId('checking'), checking);
      expect(bloc.state.byId('unknown'), isNull);
    },
  );

  blocTest<AccountsBloc, AccountsState>(
    'fails when the backend does not answer and nothing was saved',
    build: build,
    setUp: () => repository.onRefreshAccounts = () async => timedOut,
    act: (bloc) => bloc.add(const AccountsStarted()),
    expect: () => [
      const AccountsState(accounts: LoadState(isLoading: true)),
      const AccountsState(accounts: LoadState(failure: LoadFailure.timeout)),
    ],
    verify: (bloc) => expect(bloc.state.accounts.hasFailed, isTrue),
  );

  blocTest<AccountsBloc, AccountsState>(
    'keeps the saved data on screen when the refresh fails',
    build: build,
    act: (bloc) async {
      final refresh = holdRefresh();
      bloc.add(const AccountsStarted());
      await pumpEventQueue();
      repository.accounts.add(saved);
      await pumpEventQueue();
      refresh.complete(timedOut);
    },
    skip: 2,
    expect: () => [
      AccountsState(
        accounts: LoadState(
          data: const [savings, checking],
          origin: DataOrigin.cache,
          syncedAt: earlier,
          failure: LoadFailure.timeout,
        ),
      ),
    ],
    verify: (bloc) => expect(bloc.state.accounts.isOutdated, isTrue),
  );

  blocTest<AccountsBloc, AccountsState>(
    'a retry keeps the error visible while it runs, then shows the data',
    build: build,
    setUp: () => repository.onRefreshAccounts = () async => timedOut,
    act: (bloc) async {
      bloc.add(const AccountsStarted());
      await pumpEventQueue();
      repository.onRefreshAccounts = () async => Success(fresh);
      bloc.add(const AccountsRefreshRequested(isRetry: true));
    },
    skip: 2,
    expect: () => [
      const AccountsState(
        accounts: LoadState(failure: LoadFailure.timeout, isLoading: true),
      ),
      AccountsState(
        accounts: LoadState(
          data: const [savings, checking],
          origin: DataOrigin.server,
          syncedAt: now,
        ),
      ),
    ],
    verify: (_) {
      final retries = telemetry.events.where(
        (event) => event.name == AccountsTelemetry.retryRequested,
      );
      expect(retries.single.parameters, {
        AccountsTelemetry.serviceKey: AccountsTelemetry.accountsService,
      });
    },
  );

  blocTest<AccountsBloc, AccountsState>(
    'a pull to refresh is not counted as a retry',
    build: build,
    setUp: () => repository.onRefreshAccounts = () async => Success(fresh),
    act: (bloc) async {
      bloc.add(const AccountsStarted());
      await pumpEventQueue();
      bloc.add(const AccountsRefreshRequested());
    },
    verify: (_) {
      expect(repository.accountRefreshes, 2);
      expect(
        telemetry.events.map((event) => event.name),
        isNot(contains(AccountsTelemetry.retryRequested)),
      );
    },
  );

  blocTest<AccountsBloc, AccountsState>(
    'does not ask twice while a refresh is in flight',
    build: build,
    act: (bloc) async {
      final refresh = holdRefresh();
      bloc
        ..add(const AccountsStarted())
        ..add(const AccountsRefreshRequested())
        ..add(const AccountsRefreshRequested(isRetry: true));
      await pumpEventQueue();
      refresh.complete(Success(fresh));
    },
    verify: (_) => expect(repository.accountRefreshes, 1),
  );

  blocTest<AccountsBloc, AccountsState>(
    'fresh data from the listener clears an earlier failure',
    build: build,
    setUp: () => repository.onRefreshAccounts = () async => timedOut,
    act: (bloc) async {
      bloc.add(const AccountsStarted());
      await pumpEventQueue();
      repository.accounts.add(fresh);
    },
    skip: 2,
    expect: () => [
      AccountsState(
        accounts: LoadState(
          data: const [savings, checking],
          origin: DataOrigin.server,
          syncedAt: now,
        ),
      ),
    ],
  );

  blocTest<AccountsBloc, AccountsState>(
    'a listener that breaks is a failure, reported without its message',
    build: build,
    act: (bloc) async {
      final refresh = holdRefresh();
      bloc.add(const AccountsStarted());
      await pumpEventQueue();
      repository.accounts.addError(StateError('account 22004821'));
      await pumpEventQueue();
      refresh.complete(timedOut);
    },
    skip: 1,
    expect: () => [
      const AccountsState(accounts: LoadState(failure: LoadFailure.unexpected)),
      const AccountsState(accounts: LoadState(failure: LoadFailure.timeout)),
    ],
    verify: (_) {
      final report = telemetry.errors.single;
      expect(report.error, isA<RedactedError>());
      expect('${report.error}', isNot(contains('22004821')));
      expect(report.reason, AccountsTelemetry.unexpectedError);
    },
  );

  group('after the listener broke', () {
    Future<AccountsBloc> broken() async {
      repository.onRefreshAccounts = () async => Success(fresh);
      final bloc = build()..add(const AccountsStarted());
      addTearDown(bloc.close);
      await pumpEventQueue();
      repository.accounts.addError(StateError('permission denied'));
      await pumpEventQueue();
      return bloc;
    }

    test('it counts as a failed load of the accounts service', () async {
      await broken();

      final failures = telemetry.events.where(
        (event) => event.name == AccountsTelemetry.loadFailed,
      );
      expect(failures.single.parameters, {
        AccountsTelemetry.serviceKey: AccountsTelemetry.accountsService,
        AccountsTelemetry.reasonKey: LoadFailure.unexpected.name,
      });
    });

    test(
      'a retry follows the accounts again, so changes keep arriving',
      () async {
        final bloc = await broken();
        expect(repository.accountListeners, 1);

        bloc.add(const AccountsRefreshRequested(isRetry: true));
        await pumpEventQueue();
        expect(repository.accountListeners, 2);
        expect(bloc.state.accounts.failure, isNull);

        repository.accounts.add(
          _Snapshot(
            value: const [savings],
            origin: DataOrigin.server,
            syncedAt: now,
          ),
        );
        await pumpEventQueue();

        expect(bloc.state.accounts.data, [savings]);
      },
    );

    test('a refresh while the listener works does not listen twice', () async {
      repository.onRefreshAccounts = () async => Success(fresh);
      final bloc = build()..add(const AccountsStarted());
      addTearDown(bloc.close);
      await pumpEventQueue();

      bloc.add(const AccountsRefreshRequested());
      await pumpEventQueue();

      expect(repository.accountListeners, 1);
    });
  });

  blocTest<AccountsBloc, AccountsState>(
    'starting twice listens and asks only once',
    build: build,
    setUp: () => repository.onRefreshAccounts = () async => Success(fresh),
    act: (bloc) async {
      bloc
        ..add(const AccountsStarted())
        ..add(const AccountsStarted());
      await pumpEventQueue();
      repository.accounts.add(fresh);
    },
    verify: (_) => expect(repository.accountRefreshes, 1),
  );

  test('stops listening and ignores a late answer once closed', () async {
    final refresh = holdRefresh();
    final bloc = build()..add(const AccountsStarted());
    await pumpEventQueue();

    await bloc.close();
    refresh.complete(Success(fresh));
    await pumpEventQueue();

    expect(repository.accounts.hasListener, isFalse);
    expect(bloc.state.accounts.hasData, isFalse);
  });

  group('first load trace', () {
    test('ends with the origin and the count when data is shown', () async {
      final refresh = holdRefresh();
      final bloc = build()..add(const AccountsStarted());
      await pumpEventQueue();
      final trace = telemetry.traces.single;
      expect(trace.name, AccountsTelemetry.accountsFirstLoad);
      expect(trace.isRunning, isTrue);

      repository.accounts.add(saved);
      await pumpEventQueue();

      expect(trace.isRunning, isFalse);
      expect(trace.attributes, {
        AccountsTelemetry.originKey: 'cache',
        AccountsTelemetry.countKey: '2',
      });
      refresh.complete(Success(fresh));
      await bloc.close();
      expect(telemetry.traces, hasLength(1));
    });

    test('ends as failed when there is nothing to show', () async {
      repository.onRefreshAccounts = () async => timedOut;
      final bloc = build()..add(const AccountsStarted());
      await pumpEventQueue();

      final trace = telemetry.traces.single;
      expect(trace.isRunning, isFalse);
      expect(trace.attributes, {
        AccountsTelemetry.outcomeKey: AccountsTelemetry.failedOutcome,
      });
      await bloc.close();
    });

    test('is stopped if the customer leaves before anything arrives', () async {
      holdRefresh();
      final bloc = build()..add(const AccountsStarted());
      await pumpEventQueue();

      await bloc.close();

      expect(telemetry.traces.single.isRunning, isFalse);
    });
  });
}
