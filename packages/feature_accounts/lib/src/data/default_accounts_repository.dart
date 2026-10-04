import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/src/accounts_telemetry.dart';
import 'package:feature_accounts/src/data/ports.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/accounts_repository.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/load_state.dart';
import 'package:feature_accounts/src/domain/movement.dart';

/// [AccountsRepository] over a source that listens in real time and a store
/// of synchronization times.
///
/// The source's own saved copy is the cache: nothing is duplicated here.
/// What this class adds is the meaning of each delivery (fresh or saved,
/// and from when), and a refresh that goes through the resilience policy.
final class DefaultAccountsRepository implements AccountsRepository {
  DefaultAccountsRepository({
    required AccountsSource source,
    required SyncTimes syncTimes,
    required ResiliencePolicy policy,
    Telemetry telemetry = const NoopTelemetry(),
    DateTime Function() now = DateTime.now,
  }) : _source = source,
       _syncTimes = syncTimes,
       _policy = policy,
       _telemetry = telemetry,
       _now = now;

  /// Names under which synchronization times are stored.
  static const String _accountsDataSet = 'accounts';
  static String _movementsDataSet(String accountId) => 'movements_$accountId';

  final AccountsSource _source;
  final SyncTimes _syncTimes;
  final ResiliencePolicy _policy;
  final Telemetry _telemetry;
  final DateTime Function() _now;

  @override
  Stream<DataSnapshot<List<Account>>> watchAccounts() => _watch(
    _source.watchAccounts(),
    dataSet: _accountsDataSet,
    service: AccountsTelemetry.accountsService,
    arrange: inListingOrder,
  );

  @override
  Future<Result<DataSnapshot<List<Account>>>> refreshAccounts() => _refresh(
    _source.fetchAccounts,
    dataSet: _accountsDataSet,
    service: AccountsTelemetry.accountsService,
    arrange: inListingOrder,
  );

  @override
  Stream<DataSnapshot<List<Movement>>> watchMovements(
    String accountId, {
    required int limit,
  }) => _watch(
    _source.watchMovements(accountId, limit: limit),
    dataSet: _movementsDataSet(accountId),
    service: AccountsTelemetry.movementsService,
  );

  @override
  Future<Result<DataSnapshot<List<Movement>>>> refreshMovements(
    String accountId, {
    required int limit,
  }) => _refresh(
    () => _source.fetchMovements(accountId, limit: limit),
    dataSet: _movementsDataSet(accountId),
    service: AccountsTelemetry.movementsService,
  );

  Stream<DataSnapshot<List<T>>> _watch<T>(
    Stream<SourceSnapshot<T>> deliveries, {
    required String dataSet,
    required String service,
    List<T> Function(Iterable<T> items)? arrange,
  }) {
    var reportedCache = false;
    // A listener delivers the same documents again on every change, so the
    // unreadable ones are reported when their number changes, not each time.
    var reportedSkipped = 0;

    return deliveries.expand((delivery) {
      final items = arrange?.call(delivery.items) ?? delivery.items;
      final skipped = delivery.skipped;
      if (skipped != reportedSkipped) {
        reportedSkipped = skipped;
        _reportSkipped(skipped, service);
      }
      if (!delivery.fromCache) return [_fresh(items, dataSet, skipped)];

      final syncedAt = _syncTimes.lastSync(dataSet);
      // A device that never synchronized has an empty copy whatever the
      // customer owns. Showing it would claim "no accounts" without knowing.
      if (items.isEmpty && syncedAt == null) return const [];

      if (!reportedCache) {
        reportedCache = true;
        _telemetry.event(
          AccountsTelemetry.servedFromCache,
          parameters: {
            AccountsTelemetry.serviceKey: service,
            AccountsTelemetry.countKey: items.length,
          },
        );
      }
      return [
        DataSnapshot(
          value: items,
          origin: DataOrigin.cache,
          syncedAt: syncedAt,
          skipped: skipped,
        ),
      ];
    });
  }

  Future<Result<DataSnapshot<List<T>>>> _refresh<T>(
    Future<SourceSnapshot<T>> Function() fetch, {
    required String dataSet,
    required String service,
    List<T> Function(Iterable<T> items)? arrange,
  }) async {
    // Reading is safe to repeat, so the policy may retry it.
    final result = await _policy.run(
      fetch,
      idempotent: true,
      serviceId: service,
    );

    switch (result) {
      case Success(value: final fetched):
        final items = fetched.items;
        _reportSkipped(fetched.skipped, service);
        return Success(
          _fresh(arrange?.call(items) ?? items, dataSet, fetched.skipped),
        );
      case Failed(:final failure):
        _reportFailure(failure, service);
        return Failed(failure);
    }
  }

  /// A snapshot the backend just confirmed. The moment is remembered so the
  /// saved copy can later say how old it is.
  DataSnapshot<List<T>> _fresh<T>(List<T> items, String dataSet, int skipped) {
    final at = _now();
    unawaited(_remember(dataSet, at));
    return DataSnapshot(
      value: items,
      origin: DataOrigin.server,
      syncedAt: at,
      skipped: skipped,
    );
  }

  /// Documents left out are a defect in the data or a version of it this
  /// app does not know. Only how many is reported, never which.
  void _reportSkipped(int skipped, String service) {
    if (skipped == 0) return;
    _telemetry.event(
      AccountsTelemetry.documentsSkipped,
      parameters: {
        AccountsTelemetry.serviceKey: service,
        AccountsTelemetry.countKey: skipped,
      },
    );
  }

  /// Losing a synchronization time only makes the saved copy say less about
  /// its age, so a storage failure must not interrupt the data itself.
  Future<void> _remember(String dataSet, DateTime at) async {
    try {
      await _syncTimes.record(dataSet, at);
    } on Object catch (error, stackTrace) {
      _reportUnexpected(error, stackTrace);
    }
  }

  void _reportFailure(AppFailure failure, String service) {
    _telemetry.event(
      AccountsTelemetry.loadFailed,
      parameters: {
        AccountsTelemetry.serviceKey: service,
        AccountsTelemetry.reasonKey: LoadFailure.of(failure).name,
      },
    );
    if (failure is UnexpectedFailure) {
      _reportUnexpected(failure.cause, failure.stackTrace);
    }
  }

  /// The message of an unexpected error may quote the data it failed on, so
  /// only its type is reported.
  void _reportUnexpected(Object error, StackTrace stackTrace) {
    _telemetry.recordError(
      RedactedError(error.runtimeType),
      stackTrace,
      reason: AccountsTelemetry.unexpectedError,
    );
  }
}
