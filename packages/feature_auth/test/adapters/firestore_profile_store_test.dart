import 'package:app_platform/app_platform.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_auth/src/adapters/firestore_profile_store.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fixtures.dart';

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
class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  const account = AuthAccount(uid: 'uid-1', email: email);
  final profile = UserProfile.fromDraft(account, draft);

  group('encode', () {
    test('writes exactly the fields the rules allow', () {
      final document = FirestoreProfileStore.encode(profile);

      expect(document.keys, {
        'fullName',
        'nationalId',
        'email',
        'phone',
        'segment',
        'interests',
        'createdAt',
      });
      expect(document['fullName'], 'Valentina Andrade');
      expect(document['nationalId'], '1710034065');
      expect(document['email'], email);
      expect(document['phone'], '0991234567');
      expect(document['segment'], 'family');
      expect(document['interests'], ['saving', 'travel']);
    });

    test('leaves the creation time to the server', () {
      expect(
        FirestoreProfileStore.encode(profile)['createdAt'],
        FieldValue.serverTimestamp(),
      );
    });
  });

  group('decode', () {
    test('reads back what encode wrote', () {
      final document = FirestoreProfileStore.encode(profile)
        ..['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(0);

      expect(FirestoreProfileStore.decode('uid-1', document), profile);
    });

    test('falls back to the default segment for one it does not know', () {
      final decoded = FirestoreProfileStore.decode('uid-1', {
        'segment': 'platinum',
      });

      expect(decoded.segment, Segment.starting);
    });

    test('drops interests it does not know and tolerates wrong types', () {
      final decoded = FirestoreProfileStore.decode('uid-1', {
        'fullName': 7,
        'interests': ['saving', 'crypto', 3],
      });

      expect(decoded.interests, {Interest.saving});
      expect(decoded.fullName, isEmpty);
    });
  });

  group('against Firestore', () {
    late _MockFirestore firestore;
    late _MockDocument document;
    late FirestoreProfileStore store;

    setUp(() {
      firestore = _MockFirestore();
      final collection = _MockCollection();
      document = _MockDocument();
      store = FirestoreProfileStore(firestore);
      when(() => firestore.collection('users')).thenReturn(collection);
      when(() => collection.doc('uid-1')).thenReturn(document);
    });

    void whenGet(
      Future<DocumentSnapshot<Map<String, dynamic>>> Function() answer,
    ) {
      when(() => document.get()).thenAnswer((_) => answer());
    }

    test('reads the profile at users/{uid}', () async {
      final snapshot = _MockSnapshot();
      when(snapshot.data).thenReturn({
        ...FirestoreProfileStore.encode(profile),
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(0),
      });
      whenGet(() async => snapshot);

      expect(await store.read('uid-1'), profile);
    });

    test('answers null for a document that does not exist', () async {
      final snapshot = _MockSnapshot();
      when(snapshot.data).thenReturn(null);
      whenGet(() async => snapshot);

      expect(await store.read('uid-1'), isNull);
    });

    test('creates the profile at users/{uid}', () async {
      when(() => document.set(any())).thenAnswer((_) async {});

      await store.create(profile);

      final written =
          verify(() => document.set(captureAny())).captured.single
              as Map<String, Object?>;
      expect(written, FirestoreProfileStore.encode(profile));
    });

    test('reports an unreachable backend as service unavailable', () {
      whenGet(
        () async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );

      expect(
        store.read('uid-1'),
        throwsA(isA<ServiceUnavailableFailure>()),
      );
    });

    test('reports an exceeded deadline as a timeout', () {
      whenGet(
        () async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'deadline-exceeded',
        ),
      );

      expect(store.read('uid-1'), throwsA(isA<TimeoutFailure>()));
    });

    test('lets a denied write through untouched', () {
      when(() => document.set(any())).thenAnswer(
        (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );

      expect(store.create(profile), throwsA(isA<FirebaseException>()));
    });
  });
}
