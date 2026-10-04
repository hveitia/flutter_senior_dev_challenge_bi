import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/presentation/home/balance_trend_cubit.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

typedef _Snapshot = DataSnapshot<List<Movement>>;

void main() {
  late FakeAccountsRepository repository;

  BalanceTrendCubit build({int days = 30}) =>
      BalanceTrendCubit(repository: repository, days: days, now: () => now);

  _Snapshot fetched(List<Movement> movements) =>
      _Snapshot(value: movements, origin: DataOrigin.server, syncedAt: now);

  setUp(() => repository = FakeAccountsRepository());

  test('knows nothing before it is asked to load', () {
    final cubit = build();

    expect(cubit.state.movements, isNull);
    expect(cubit.state.hasFailed, isFalse);
  });

  test('asks for the movements since the first day of the period, at its '
      'start', () async {
    repository.onMovementsSince = () async => Success(fetched([salary]));
    final cubit = build();

    await cubit.load();

    // 30 days ending on 3 October start on 4 September.
    expect(repository.sinceRequests.single, (
      DateTime(2026, 9, 4),
      BalanceTrendCubit.fetchLimit,
    ));
    expect(cubit.state.movements, [salary]);
    expect(cubit.state.isComplete, isTrue);
  });

  test('says the read is not complete when it came back full: older '
      'movements of the period may be missing', () async {
    repository.onMovementsSince = () async => Success(
      fetched(List.filled(BalanceTrendCubit.fetchLimit, salary)),
    );
    final cubit = build();

    await cubit.load();

    expect(cubit.state.isComplete, isFalse);
  });

  test('says it failed, and keeps what it had from an earlier load', () async {
    repository.onMovementsSince = () async => Success(fetched([salary]));
    final cubit = build();
    await cubit.load();

    repository.onMovementsSince = () async =>
        const Failed(ServiceUnavailableFailure(ServiceIds.movements));
    await cubit.load();

    expect(cubit.state.hasFailed, isTrue);
    expect(cubit.state.movements, [salary]);
  });

  test('ignores an answer that arrives after it was closed', () async {
    final gate = Completer<Result<_Snapshot>>();
    repository.onMovementsSince = () => gate.future;
    final cubit = build();

    final loading = cubit.load();
    await cubit.close();
    gate.complete(Success(fetched([salary])));

    await expectLater(loading, completes);
  });
}
