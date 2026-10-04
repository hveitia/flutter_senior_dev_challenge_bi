import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/movement.dart';

/// What a listener delivered: the items, and whether the backend confirmed
/// them or they are what the device had saved.
final class SourceSnapshot<T> {
  const SourceSnapshot(
    this.items, {
    required this.fromCache,
    this.skipped = 0,
  });

  final List<T> items;
  final bool fromCache;

  /// How many documents of the data set could not be read and are missing
  /// from [items].
  final int skipped;
}

/// Where the accounts and movements of one customer are read from.
///
/// `watch` follows a data set and may answer from the device's own copy.
/// `fetch` asks the backend and fails when it cannot be reached; failures
/// are thrown, and the repository turns them into typed results. What a
/// fetch returns never comes from the device's copy.
abstract interface class AccountsSource {
  Stream<SourceSnapshot<Account>> watchAccounts();

  Future<SourceSnapshot<Account>> fetchAccounts();

  /// The latest [limit] movements of the account, newest first.
  Stream<SourceSnapshot<Movement>> watchMovements(
    String accountId, {
    required int limit,
  });

  Future<SourceSnapshot<Movement>> fetchMovements(
    String accountId, {
    required int limit,
  });

  /// The latest [limit] movements across every account, newest first.
  Stream<SourceSnapshot<Movement>> watchRecentMovements({required int limit});

  Future<SourceSnapshot<Movement>> fetchRecentMovements({required int limit});
}

/// Remembers when each data set was last confirmed by the backend, so data
/// shown from the device's copy can say how old it is, even after a restart.
abstract interface class SyncTimes {
  DateTime? lastSync(String dataSet);

  Future<void> record(String dataSet, DateTime at);
}
