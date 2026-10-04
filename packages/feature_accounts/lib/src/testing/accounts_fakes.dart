import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/src/data/ports.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/accounts_repository.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/movement.dart';

/// An [AccountsSource] driven by the test: it pushes what the listeners
/// deliver and decides how each fetch ends.
final class FakeAccountsSource implements AccountsSource {
  final StreamController<SourceSnapshot<Account>> accounts =
      StreamController.broadcast();
  final StreamController<SourceSnapshot<Movement>> movements =
      StreamController.broadcast();

  /// How `fetchAccounts` ends. Replace it to make the backend fail.
  Future<List<Account>> Function() onFetchAccounts = () async => const [];

  /// How `fetchMovements` ends.
  Future<List<Movement>> Function() onFetchMovements = () async => const [];

  int accountFetches = 0;
  int movementFetches = 0;

  /// The account and limit of every movements listener and fetch, in order.
  final List<(String accountId, int limit)> movementRequests = [];

  @override
  Stream<SourceSnapshot<Account>> watchAccounts() => accounts.stream;

  @override
  Future<List<Account>> fetchAccounts() {
    accountFetches++;
    return onFetchAccounts();
  }

  @override
  Stream<SourceSnapshot<Movement>> watchMovements(
    String accountId, {
    required int limit,
  }) {
    movementRequests.add((accountId, limit));
    return movements.stream;
  }

  @override
  Future<List<Movement>> fetchMovements(
    String accountId, {
    required int limit,
  }) {
    movementFetches++;
    movementRequests.add((accountId, limit));
    return onFetchMovements();
  }
}

/// [SyncTimes] kept in memory. Set [failsToRecord] to simulate storage that
/// cannot be written.
final class InMemorySyncTimes implements SyncTimes {
  final Map<String, DateTime> times = {};
  bool failsToRecord = false;

  @override
  DateTime? lastSync(String dataSet) => times[dataSet];

  @override
  Future<void> record(String dataSet, DateTime at) async {
    if (failsToRecord) throw StateError('storage unavailable');
    times[dataSet] = at;
  }
}

/// An [AccountsRepository] driven by the test.
final class FakeAccountsRepository implements AccountsRepository {
  final StreamController<DataSnapshot<List<Account>>> accounts =
      StreamController.broadcast();

  /// One stream of movements per listener, newest last, so a test can tell
  /// the listener of one page from the listener of the next.
  final List<StreamController<DataSnapshot<List<Movement>>>> movementStreams =
      [];

  /// How `refreshAccounts` ends. Replace it to make the refresh fail or to
  /// hold it until the test completes it.
  Future<Result<DataSnapshot<List<Account>>>> Function() onRefreshAccounts =
      () async => const Failed(OfflineFailure());

  /// How `refreshMovements` ends.
  Future<Result<DataSnapshot<List<Movement>>>> Function() onRefreshMovements =
      () async => const Failed(OfflineFailure());

  int accountRefreshes = 0;
  int movementRefreshes = 0;

  /// How many times the accounts were asked to be followed.
  int accountListeners = 0;

  /// The account and limit of every movements listener, in order.
  final List<(String accountId, int limit)> movementListeners = [];

  /// The stream of the most recent movements listener.
  StreamController<DataSnapshot<List<Movement>>> get movements =>
      movementStreams.last;

  @override
  Stream<DataSnapshot<List<Account>>> watchAccounts() {
    accountListeners++;
    return accounts.stream;
  }

  @override
  Future<Result<DataSnapshot<List<Account>>>> refreshAccounts() {
    accountRefreshes++;
    return onRefreshAccounts();
  }

  @override
  Stream<DataSnapshot<List<Movement>>> watchMovements(
    String accountId, {
    required int limit,
  }) {
    movementListeners.add((accountId, limit));
    final controller =
        StreamController<DataSnapshot<List<Movement>>>.broadcast();
    movementStreams.add(controller);
    return controller.stream;
  }

  @override
  Future<Result<DataSnapshot<List<Movement>>>> refreshMovements(
    String accountId, {
    required int limit,
  }) {
    movementRefreshes++;
    return onRefreshMovements();
  }
}
