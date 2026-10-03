import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';
import 'package:feature_accounts/src/domain/movement.dart';

/// The accounts and movements of the signed-in customer. Read only: money
/// is moved by the server, never from here.
///
/// Each data set has two entry points. `watch` follows it in real time and
/// also answers from what the device saved, so there is something to show
/// without a connection. `refresh` asks the backend once, with a timeout and
/// retries, and says how it went.
abstract interface class AccountsRepository {
  Stream<DataSnapshot<List<Account>>> watchAccounts();

  Future<Result<DataSnapshot<List<Account>>>> refreshAccounts();

  /// The latest [limit] movements of the account, newest first.
  Stream<DataSnapshot<List<Movement>>> watchMovements(
    String accountId, {
    required int limit,
  });

  Future<Result<DataSnapshot<List<Movement>>>> refreshMovements(
    String accountId, {
    required int limit,
  });
}
