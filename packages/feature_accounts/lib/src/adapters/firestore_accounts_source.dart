import 'package:app_platform/app_platform.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_accounts/src/accounts_telemetry.dart';
import 'package:feature_accounts/src/data/ports.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/movement.dart';

/// Field names of an account document. The seed tool in `firebase/seed`
/// writes the same names; they change together.
abstract final class AccountFields {
  static const String name = 'name';
  static const String kind = 'kind';
  static const String number = 'number';
  static const String availableCents = 'availableCents';
  static const String ledgerCents = 'ledgerCents';
  static const String currency = 'currency';
}

/// Field names of a movement document.
abstract final class MovementFields {
  static const String accountId = 'accountId';
  static const String description = 'description';
  static const String category = 'category';
  static const String amountCents = 'amountCents';
  static const String postedAt = 'postedAt';
  static const String reference = 'reference';
  static const String channel = 'channel';
  static const String status = 'status';
}

/// [AccountsSource] on the documents under `users/{uid}` in Firestore.
///
/// The listeners ask for metadata changes too, so the same documents are
/// delivered again when the server confirms what the device had saved. The
/// SDK's own persistence is the cache; nothing is stored twice.
final class FirestoreAccountsSource implements AccountsSource {
  const FirestoreAccountsSource(this._firestore, {required this.uid});

  static const String usersCollection = 'users';
  static const String accountsCollection = 'accounts';
  static const String movementsCollection = 'movements';
  static const String defaultCurrency = 'USD';

  /// Firestore codes for a backend that cannot be reached right now.
  static const String _unavailable = 'unavailable';
  static const String _deadlineExceeded = 'deadline-exceeded';

  /// A fetch must be answered by the server: the point of asking is to know
  /// whether the backend is reachable.
  static const GetOptions _fromServer = GetOptions(source: Source.server);

  final FirebaseFirestore _firestore;
  final String uid;

  DocumentReference<Map<String, dynamic>> get _customer =>
      _firestore.collection(usersCollection).doc(uid);

  CollectionReference<Map<String, dynamic>> get _accounts =>
      _customer.collection(accountsCollection);

  /// Needs the composite index on `accountId` and `postedAt` declared in
  /// `firebase/firestore.indexes.json`.
  Query<Map<String, dynamic>> _movementsOf(String accountId, int limit) =>
      _customer
          .collection(movementsCollection)
          .where(MovementFields.accountId, isEqualTo: accountId)
          .orderBy(MovementFields.postedAt, descending: true)
          .limit(limit);

  @override
  Stream<SourceSnapshot<Account>> watchAccounts() => _accounts
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) => _delivery(snapshot, decodeAccount));

  @override
  Future<SourceSnapshot<Account>> fetchAccounts() => _translating(
    AccountsTelemetry.accountsService,
    () async => _delivery(await _accounts.get(_fromServer), decodeAccount),
  );

  @override
  Stream<SourceSnapshot<Movement>> watchMovements(
    String accountId, {
    required int limit,
  }) => _movementsOf(accountId, limit)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) => _delivery(snapshot, decodeMovement));

  @override
  Future<SourceSnapshot<Movement>> fetchMovements(
    String accountId, {
    required int limit,
  }) => _translating(
    AccountsTelemetry.movementsService,
    () async => _delivery(
      await _movementsOf(accountId, limit).get(_fromServer),
      decodeMovement,
    ),
  );

  /// Ordered by a single field, so it needs no index of its own.
  Query<Map<String, dynamic>> _latestMovements(int limit) => _customer
      .collection(movementsCollection)
      .orderBy(MovementFields.postedAt, descending: true)
      .limit(limit);

  /// A range and an order on the same field, so it needs no index of its
  /// own either.
  @override
  Future<SourceSnapshot<Movement>> fetchMovementsSince(
    DateTime since, {
    required int limit,
  }) => _translating(
    AccountsTelemetry.movementsService,
    () async => _delivery(
      await _customer
          .collection(movementsCollection)
          .where(
            MovementFields.postedAt,
            isGreaterThanOrEqualTo: Timestamp.fromDate(since),
          )
          .orderBy(MovementFields.postedAt, descending: true)
          .limit(limit)
          .get(_fromServer),
      decodeMovement,
    ),
  );

  @override
  Stream<SourceSnapshot<Movement>> watchRecentMovements({required int limit}) =>
      _latestMovements(limit)
          .snapshots(includeMetadataChanges: true)
          .map((snapshot) => _delivery(snapshot, decodeMovement));

  @override
  Future<SourceSnapshot<Movement>> fetchRecentMovements({required int limit}) =>
      _translating(
        AccountsTelemetry.movementsService,
        () async => _delivery(
          await _latestMovements(limit).get(_fromServer),
          decodeMovement,
        ),
      );

  /// Reads an account leniently: unknown fields are ignored, but an account
  /// it cannot state truthfully (no whole-cent balance, no number, a kind
  /// this version does not know) is left out instead of being guessed.
  static Account? decodeAccount(String id, Map<String, Object?> data) {
    final name = data[AccountFields.name];
    final number = data[AccountFields.number];
    final available = data[AccountFields.availableCents];
    final kind = AccountKind.fromId(data[AccountFields.kind]);
    if (name is! String || number is! String || available is! int) return null;
    if (kind == null) return null;

    return Account(
      id: id,
      name: name,
      kind: kind,
      number: number,
      availableCents: available,
      ledgerCents: switch (data[AccountFields.ledgerCents]) {
        final int ledger => ledger,
        _ => available,
      },
      currency: switch (data[AccountFields.currency]) {
        final String currency => currency,
        _ => defaultCurrency,
      },
    );
  }

  /// Reads a movement leniently. It needs an account, a whole-cent amount
  /// and a date; everything else has a safe fallback.
  static Movement? decodeMovement(String id, Map<String, Object?> data) {
    final accountId = data[MovementFields.accountId];
    final amount = data[MovementFields.amountCents];
    final postedAt = data[MovementFields.postedAt];
    if (accountId is! String || amount is! int || postedAt is! Timestamp) {
      return null;
    }

    String text(String field) => switch (data[field]) {
      final String value => value,
      _ => '',
    };

    return Movement(
      id: id,
      accountId: accountId,
      description: text(MovementFields.description),
      category: MovementCategory.fromId(data[MovementFields.category]),
      amountCents: amount,
      postedAt: postedAt.toDate(),
      reference: text(MovementFields.reference),
      channel: MovementChannel.fromId(data[MovementFields.channel]),
      status: MovementStatus.fromId(data[MovementFields.status]),
    );
  }

  /// What a query returned, with the documents that could not be read left
  /// out and counted: whoever shows the rest must know it is not everything.
  static SourceSnapshot<T> _delivery<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    T? Function(String id, Map<String, Object?> data) decode,
  ) {
    final documents = snapshot.docs;
    final items = [
      for (final document in documents) ?decode(document.id, document.data()),
    ];

    return SourceSnapshot(
      items,
      fromCache: snapshot.metadata.isFromCache,
      skipped: documents.length - items.length,
    );
  }

  Future<T> _translating<T>(String service, Future<T> Function() call) async {
    try {
      return await call();
    } on FirebaseException catch (error) {
      if (error.code == _unavailable) {
        throw ServiceUnavailableFailure(service);
      }
      if (error.code == _deadlineExceeded) throw const TimeoutFailure();
      rethrow;
    }
  }
}
