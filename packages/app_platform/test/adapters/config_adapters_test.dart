import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_platform/adapters.dart';
import 'package:app_platform/app_platform.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

// The Firestore types are sealed for production code; mocking them is the
// only way to test the adapter without an emulator.
// ignore: subtype_of_sealed_class
class _MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// Same reason as the reference above.
// ignore: subtype_of_sealed_class
class _MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

final class _RecordingBundle extends CachingAssetBundle {
  final List<String> requestedKeys = [];

  @override
  Future<ByteData> load(String key) async {
    requestedKeys.add(key);
    return ByteData.sublistView(utf8.encode('{"schemaVersion":1}'));
  }
}

const _bundledAsset = 'assets/default-home-config.json';
const _contractExample = '../../contracts/home-config.example.json';

void main() {
  group('FirestoreConfigSource', () {
    late _MockFirestore firestore;
    late _MockDocumentReference reference;
    late StreamController<DocumentSnapshot<Map<String, dynamic>>> snapshots;

    _MockDocumentSnapshot snapshot(Map<String, dynamic>? data) {
      final document = _MockDocumentSnapshot();
      when(document.data).thenReturn(data);
      return document;
    }

    setUp(() {
      firestore = _MockFirestore();
      reference = _MockDocumentReference();
      snapshots = StreamController();
      when(() => firestore.doc(any())).thenReturn(reference);
      when(() => reference.snapshots()).thenAnswer((_) => snapshots.stream);
    });

    test('listens to the published configuration document', () {
      FirestoreConfigSource(firestore).watch();

      verify(() => firestore.doc(FirestoreConfigSource.documentPath)).called(1);
      expect(FirestoreConfigSource.documentPath, 'config/home');
    });

    test('emits the raw data of every snapshot', () async {
      final documents = <Object?>[];
      final subscription = FirestoreConfigSource(
        firestore,
      ).watch().listen(documents.add);

      snapshots
        ..add(snapshot({'schemaVersion': 1}))
        ..add(snapshot({'schemaVersion': 2}));
      await pumpEventQueue();

      expect(documents, [
        {'schemaVersion': 1},
        {'schemaVersion': 2},
      ]);
      await subscription.cancel();
    });

    test('emits null when the document does not exist', () async {
      final documents = <Object?>[];
      final subscription = FirestoreConfigSource(
        firestore,
      ).watch().listen(documents.add);

      snapshots.add(snapshot(null));
      await pumpEventQueue();

      expect(documents, [null]);
      await subscription.cancel();
    });
  });

  group('SharedPreferencesConfigStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('has nothing before the first write', () async {
      final store = SharedPreferencesConfigStore(
        await SharedPreferences.getInstance(),
      );

      expect(await store.read(), isNull);
    });

    test('returns the last document written', () async {
      final store = SharedPreferencesConfigStore(
        await SharedPreferences.getInstance(),
      );

      await store.write('{"configVersion":13}');
      await store.write('{"configVersion":14}');

      expect(await store.read(), '{"configVersion":14}');
    });

    test('keeps the document for the next instance', () async {
      final preferences = await SharedPreferences.getInstance();
      await SharedPreferencesConfigStore(preferences).write('{"a":1}');

      expect(await SharedPreferencesConfigStore(preferences).read(), '{"a":1}');
    });
  });

  group('bundled configuration', () {
    test('is loaded from the asset shipped by this package', () async {
      final bundle = _RecordingBundle();

      final document = await bundledConfigLoader(bundle)();

      expect(bundle.requestedKeys, ['packages/app_platform/$_bundledAsset']);
      expect(document, '{"schemaVersion":1}');
    });

    test('is the same document as the contract example', () {
      final bundled = jsonDecode(File(_bundledAsset).readAsStringSync());
      final contract = jsonDecode(File(_contractExample).readAsStringSync());

      expect(bundled, contract);
    });

    test('is accepted by the parser', () {
      final result = const HomeConfigParser().parseJson(
        File(_bundledAsset).readAsStringSync(),
      );

      expect(result, isA<ConfigAccepted>());
    });
  });
}
