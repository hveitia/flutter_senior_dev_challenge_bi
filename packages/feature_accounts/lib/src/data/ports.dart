import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/movement.dart';

/// What a listener delivered: the items, and whether the backend confirmed
/// them or they are what the device had saved.
final class SourceSnapshot<T> {
  const SourceSnapshot(this.items, {required this.fromCache});

  final List<T> items;
  final bool fromCache;
}

/// Where the accounts and movements of one customer are read from.
///
/// `watch` follows a data set and may answer from the device's own copy.
/// `fetch` asks the backend and fails when it cannot be reached; failures
/// are thrown, and the repository turns them into typed results.
abstract interface class AccountsSource {
  Stream<SourceSnapshot<Account>> watchAccounts();

  Future<List<Account>> fetchAccounts();

  /// The latest [limit] movements of the account, newest first.
  Stream<SourceSnapshot<Movement>> watchMovements(
    String accountId, {
    required int limit,
  });

  Future<List<Movement>> fetchMovements(
    String accountId, {
    required int limit,
  });
}

/// Remembers when each data set was last confirmed by the backend, so data
/// shown from the device's copy can say how old it is, even after a restart.
abstract interface class SyncTimes {
  DateTime? lastSync(String dataSet);

  Future<void> record(String dataSet, DateTime at);
}
