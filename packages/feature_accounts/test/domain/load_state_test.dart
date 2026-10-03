import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  final syncedAt = now.subtract(const Duration(minutes: 8));

  DataSnapshot<List<Account>> snapshot(
    DataOrigin origin, {
    List<Account> value = const [savings],
    DateTime? at,
  }) {
    return DataSnapshot(value: value, origin: origin, syncedAt: at);
  }

  const failed = Failed<DataSnapshot<List<Account>>>(TimeoutFailure());

  test('waits while there is nothing to show and nothing failed', () {
    const state = LoadState<List<Account>>();

    expect(state.isWaiting, isTrue);
    expect(state.hasFailed, isFalse);
    expect(state.isOutdated, isFalse);
    expect(state.startLoading().isLoading, isTrue);
    expect(state.startLoading().isWaiting, isTrue);
  });

  test('saved data is shown while the refresh is still in flight', () {
    final state = const LoadState<List<Account>>().startLoading().withSnapshot(
      snapshot(DataOrigin.cache, at: syncedAt),
    );

    expect(state.data, [savings]);
    expect(state.origin, DataOrigin.cache);
    expect(state.syncedAt, syncedAt);
    expect(state.isWaiting, isFalse);
    expect(state.isLoading, isTrue);
  });

  test('a failed refresh with nothing to show is a failure', () {
    final state = const LoadState<List<Account>>().startLoading().withRefresh(
      failed,
    );

    expect(state.hasFailed, isTrue);
    expect(state.isWaiting, isFalse);
    expect(state.isLoading, isFalse);
    expect(state.failure, LoadFailure.timeout);
  });

  test('a failed refresh keeps the saved data and marks it outdated', () {
    final state = const LoadState<List<Account>>()
        .startLoading()
        .withSnapshot(snapshot(DataOrigin.cache, at: syncedAt))
        .withRefresh(failed);

    expect(state.data, [savings]);
    expect(state.isOutdated, isTrue);
    expect(state.hasFailed, isFalse);
    expect(state.syncedAt, syncedAt);
  });

  test('retrying keeps the failure on screen until there is an answer', () {
    final retrying = const LoadState<List<Account>>()
        .withRefresh(failed)
        .startLoading();

    expect(retrying.hasFailed, isTrue);
    expect(retrying.isLoading, isTrue);
  });

  test('a successful refresh replaces the data and clears the failure', () {
    final state = const LoadState<List<Account>>()
        .withRefresh(failed)
        .startLoading()
        .withRefresh(
          Success(snapshot(DataOrigin.server, value: [checking], at: now)),
        );

    expect(state.data, [checking]);
    expect(state.origin, DataOrigin.server);
    expect(state.syncedAt, now);
    expect(state.failure, isNull);
    expect(state.isLoading, isFalse);
  });

  test('fresh data from the listener clears an earlier failure', () {
    final state = const LoadState<List<Account>>()
        .withSnapshot(snapshot(DataOrigin.cache, at: syncedAt))
        .withRefresh(failed)
        .withSnapshot(snapshot(DataOrigin.server, at: now));

    expect(state.isOutdated, isFalse);
    expect(state.origin, DataOrigin.server);
  });

  test('saved data arriving after a failure does not hide the failure', () {
    final state = const LoadState<List<Account>>()
        .withRefresh(failed)
        .withSnapshot(snapshot(DataOrigin.cache, at: syncedAt));

    expect(state.isOutdated, isTrue);
    expect(state.failure, LoadFailure.timeout);
  });

  test('a snapshot without a sync time keeps the one already known', () {
    final state = const LoadState<List<Account>>()
        .withSnapshot(snapshot(DataOrigin.server, at: now))
        .withSnapshot(snapshot(DataOrigin.cache));

    expect(state.syncedAt, now);
  });

  test('an empty list is data, not the absence of it', () {
    final state = const LoadState<List<Account>>().withSnapshot(
      snapshot(DataOrigin.server, value: const [], at: now),
    );

    expect(state.hasData, isTrue);
    expect(state.isWaiting, isFalse);
  });

  group('LoadFailure', () {
    test('names each kind of failure', () {
      expect(LoadFailure.of(const OfflineFailure()), LoadFailure.offline);
      expect(LoadFailure.of(const TimeoutFailure()), LoadFailure.timeout);
      expect(
        LoadFailure.of(const ServiceUnavailableFailure('movements')),
        LoadFailure.unavailable,
      );
      expect(
        LoadFailure.of(UnexpectedFailure(StateError('x'), StackTrace.empty)),
        LoadFailure.unexpected,
      );
    });

    test('only the retried kinds mean every attempt was made', () {
      expect(LoadFailure.timeout.attemptsExhausted, isTrue);
      expect(LoadFailure.unavailable.attemptsExhausted, isTrue);
      expect(LoadFailure.offline.attemptsExhausted, isFalse);
      expect(LoadFailure.unexpected.attemptsExhausted, isFalse);
    });
  });
}
