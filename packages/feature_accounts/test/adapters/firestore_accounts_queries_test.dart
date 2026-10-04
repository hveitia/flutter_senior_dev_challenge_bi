import 'package:app_platform/app_platform.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_accounts/adapters.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

// The Firestore reference types are sealed in the plugin's API.
// ignore: subtype_of_sealed_class
class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// Sealed in the plugin's API, as above.
// ignore: subtype_of_sealed_class
class _MockDocument extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// Sealed in the plugin's API, as above.
// ignore: subtype_of_sealed_class
class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

// Sealed in the plugin's API, as above.
// ignore: subtype_of_sealed_class
class _MockQueryDocument extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _MockMetadata extends Mock implements SnapshotMetadata {}

void main() {
  const uid = 'uid-1';
  const pageSize = 20;

  late _MockFirestore firestore;
  late _MockCollection accounts;
  late _MockCollection movements;
  late _MockQuery ofAccount;
  late _MockQuery newestFirst;
  late _MockQuery page;
  late FirestoreAccountsSource source;

  _MockQuerySnapshot snapshot(
    List<(String id, Map<String, dynamic> data)> documents, {
    bool fromCache = false,
  }) {
    final metadata = _MockMetadata();
    when(() => metadata.isFromCache).thenReturn(fromCache);

    final read = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final (id, data) in documents) {
      final document = _MockQueryDocument();
      when(() => document.id).thenReturn(id);
      when(document.data).thenReturn(data);
      read.add(document);
    }

    final result = _MockQuerySnapshot();
    when(() => result.metadata).thenReturn(metadata);
    when(() => result.docs).thenReturn(read);
    return result;
  }

  Map<String, dynamic> accountDocument() => {
    AccountFields.name: 'Cuenta de ahorros',
    AccountFields.kind: 'savings',
    AccountFields.number: '22004821',
    AccountFields.availableCents: 357035,
  };

  Map<String, dynamic> movementDocument() => {
    MovementFields.accountId: 'savings',
    MovementFields.amountCents: -6480,
    MovementFields.postedAt: Timestamp.fromDate(DateTime(2026, 10, 3, 8, 45)),
  };

  setUpAll(() => registerFallbackValue(const GetOptions()));

  setUp(() {
    firestore = _MockFirestore();
    final users = _MockCollection();
    final customer = _MockDocument();
    accounts = _MockCollection();
    movements = _MockCollection();
    ofAccount = _MockQuery();
    newestFirst = _MockQuery();
    page = _MockQuery();

    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(uid)).thenReturn(customer);
    when(() => customer.collection('accounts')).thenReturn(accounts);
    when(() => customer.collection('movements')).thenReturn(movements);
    when(
      () => movements.where('accountId', isEqualTo: 'savings'),
    ).thenReturn(ofAccount);
    when(
      () => ofAccount.orderBy('postedAt', descending: true),
    ).thenReturn(newestFirst);
    when(() => newestFirst.limit(pageSize)).thenReturn(page);

    source = FirestoreAccountsSource(firestore, uid: uid);
  });

  group('movements', () {
    test('a fetch asks the server for one page of that account, '
        'newest first', () async {
      final answer = snapshot([('m1', movementDocument())]);
      when(() => page.get(any())).thenAnswer((_) async => answer);

      final fetched = await source.fetchMovements('savings', limit: pageSize);

      expect(fetched.map((movement) => movement.id), ['m1']);
      verify(() => movements.where('accountId', isEqualTo: 'savings'));
      verify(() => ofAccount.orderBy('postedAt', descending: true));
      verify(() => newestFirst.limit(pageSize));
      final options = verify(() => page.get(captureAny())).captured.single;
      expect((options as GetOptions).source, Source.server);
    });

    test('the listener follows the same page and also hears when the '
        'server confirms what was saved', () async {
      final deliveredInOrder = [
        snapshot([('m1', movementDocument())], fromCache: true),
        snapshot([('m1', movementDocument())]),
      ];
      when(
        () => page.snapshots(includeMetadataChanges: true),
      ).thenAnswer((_) => Stream.fromIterable(deliveredInOrder));

      final deliveries = await source
          .watchMovements('savings', limit: pageSize)
          .toList();

      expect(deliveries.map((delivery) => delivery.fromCache), [true, false]);
      expect(deliveries.last.items.single.amountCents, -6480);
      verify(() => newestFirst.limit(pageSize));
    });
  });

  group('accounts', () {
    test('a fetch asks the server for the accounts of the customer', () async {
      final answer = snapshot([('savings', accountDocument())]);
      when(() => accounts.get(any())).thenAnswer((_) async => answer);

      final fetched = await source.fetchAccounts();

      expect(fetched.single.id, 'savings');
      final options = verify(() => accounts.get(captureAny())).captured.single;
      expect((options as GetOptions).source, Source.server);
      verify(() => firestore.collection('users'));
    });

    test('the listener says whether a delivery came from the saved '
        'copy', () async {
      final saved = snapshot([('savings', accountDocument())], fromCache: true);
      when(
        () => accounts.snapshots(includeMetadataChanges: true),
      ).thenAnswer((_) => Stream.value(saved));

      final delivery = await source.watchAccounts().first;

      expect(delivery.fromCache, isTrue);
      expect(delivery.items.single.number, '22004821');
    });
  });

  group('a fetch that Firestore rejects', () {
    Future<Object> failureOf(String code) async {
      when(() => accounts.get(any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: code),
      );
      try {
        await source.fetchAccounts();
      } on Object catch (error) {
        return error;
      }
      return fail('the fetch should not succeed');
    }

    test('names the service when the backend is unavailable', () async {
      final failure = await failureOf('unavailable');

      expect(failure, isA<ServiceUnavailableFailure>());
      expect(
        (failure as ServiceUnavailableFailure).serviceId,
        AccountsTelemetry.accountsService,
      );
    });

    test('is a timeout when the deadline is exceeded', () async {
      expect(await failureOf('deadline-exceeded'), isA<TimeoutFailure>());
    });

    test('lets any other error through untouched', () async {
      final failure = await failureOf('permission-denied');

      expect(failure, isA<FirebaseException>());
      expect((failure as FirebaseException).code, 'permission-denied');
    });
  });
}
