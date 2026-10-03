import 'dart:async';
import 'dart:convert';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _document({int configVersion = 0, int schemaVersion = 1}) {
  return {
    'schemaVersion': schemaVersion,
    'configVersion': configVersion,
    'segments': {
      'starting': {'modules': <Object?>[]},
    },
  };
}

const int _bundledVersion = 1;
const int _cachedVersion = 7;
const int _remoteVersion = 14;

void main() {
  late StreamController<Object?> remote;
  late InMemoryConfigStore store;
  late InMemoryTelemetry telemetry;

  ConfigRepository repository({
    ConfigStore? withStore,
    String? bundled,
  }) {
    return ConfigRepository(
      source: StreamConfigSource(remote.stream),
      store: withStore ?? store,
      loadBundled: () async =>
          bundled ?? jsonEncode(_document(configVersion: _bundledVersion)),
      telemetry: telemetry,
    );
  }

  setUp(() {
    remote = StreamController<Object?>();
    store = InMemoryConfigStore();
    telemetry = InMemoryTelemetry();
  });

  // Not awaited: closing a controller nobody listened to never completes.
  tearDown(() => unawaited(remote.close()));

  group('starting point', () {
    test('is the bundled configuration on first launch', () async {
      final first = await repository().watch().first;

      expect(first.origin, ConfigOrigin.bundled);
      expect(first.config.configVersion, _bundledVersion);
    });

    test('is the cached configuration when one was saved before', () async {
      store.document = jsonEncode(_document(configVersion: _cachedVersion));

      final first = await repository().watch().first;

      expect(first.origin, ConfigOrigin.cached);
      expect(first.config.configVersion, _cachedVersion);
    });

    test('is the bundled one when the cached document is corrupt', () async {
      store.document = '{corrupt';

      final first = await repository().watch().first;

      expect(first.origin, ConfigOrigin.bundled);
    });

    test('is the bundled one when the cached document is from a newer schema '
        'than this app supports', () async {
      store.document = jsonEncode(_document(schemaVersion: 99));

      final first = await repository().watch().first;

      expect(first.origin, ConfigOrigin.bundled);
    });

    test('is the bundled one when the cache cannot be read', () async {
      final first = await repository(
        withStore: _FailingConfigStore(),
      ).watch().first;

      expect(first.origin, ConfigOrigin.bundled);
    });

    test(
      'fails loudly when the bundled configuration itself is invalid',
      () async {
        final watching = repository(bundled: '{corrupt').watch().first;

        await expectLater(watching, throwsStateError);
      },
    );
  });

  group('a valid remote document', () {
    test('replaces the current configuration', () async {
      final snapshots = <ConfigSnapshot>[];
      final subscription = repository().watch().listen(snapshots.add);
      await pumpEventQueue();

      remote.add(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      expect(snapshots.map((snapshot) => snapshot.origin), [
        ConfigOrigin.bundled,
        ConfigOrigin.remote,
      ]);
      expect(snapshots.last.config.configVersion, _remoteVersion);
      await subscription.cancel();
    });

    test('is saved so the next cold start can use it offline', () async {
      final subscription = repository().watch().listen((_) {});
      await pumpEventQueue();

      remote.add(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      final saved = const HomeConfigParser().parseJson(store.document!);
      expect((saved as ConfigAccepted).config.configVersion, _remoteVersion);
      await subscription.cancel();
    });

    test('is still applied when saving it fails', () async {
      final snapshots = <ConfigSnapshot>[];
      final subscription = repository(
        withStore: _FailingConfigStore(),
      ).watch().listen(snapshots.add);
      await pumpEventQueue();

      remote.add(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      expect(snapshots.last.origin, ConfigOrigin.remote);
      await subscription.cancel();
    });

    test('is still applied when it cannot be encoded for the cache', () async {
      final snapshots = <ConfigSnapshot>[];
      final subscription = repository().watch().listen(snapshots.add);
      await pumpEventQueue();

      remote.add({
        ..._document(configVersion: _remoteVersion),
        'publishedAt': DateTime(2026, 10, 3),
      });
      await pumpEventQueue();

      expect(snapshots.last.origin, ConfigOrigin.remote);
      expect(store.document, isNull);
      await subscription.cancel();
    });
  });

  group('a rejected remote document', () {
    test('keeps the last valid configuration and is not saved', () async {
      store.document = jsonEncode(_document(configVersion: _cachedVersion));
      final cachedDocument = store.document;
      final snapshots = <ConfigSnapshot>[];
      final subscription = repository().watch().listen(snapshots.add);
      await pumpEventQueue();

      remote.add(_document(configVersion: _remoteVersion, schemaVersion: 99));
      await pumpEventQueue();

      expect(snapshots.single.config.configVersion, _cachedVersion);
      expect(store.document, cachedDocument);
      await subscription.cancel();
    });

    test('is reported with the reason', () async {
      final subscription = repository().watch().listen((_) {});
      await pumpEventQueue();

      remote.add(_document(schemaVersion: 99));
      await pumpEventQueue();

      final warning = telemetry.logs.singleWhere(
        (entry) => entry.level == LogLevel.warning,
      );
      expect(warning.message, ConfigTelemetry.rejected);
      expect(warning.context, {
        ConfigTelemetry.reasonKey:
            ConfigRejectionReason.unsupportedSchemaVersion.name,
      });
      await subscription.cancel();
    });

    test('does not stop later valid documents from being applied', () async {
      final snapshots = <ConfigSnapshot>[];
      final subscription = repository().watch().listen(snapshots.add);
      await pumpEventQueue();

      remote
        ..add('not a document')
        ..add(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      expect(snapshots.last.config.configVersion, _remoteVersion);
      await subscription.cancel();
    });
  });

  group('a failing remote source', () {
    test('keeps the current configuration and the stream alive', () async {
      final snapshots = <ConfigSnapshot>[];
      Object? streamError;
      final subscription = repository().watch().listen(
        snapshots.add,
        onError: (Object error) => streamError = error,
      );
      await pumpEventQueue();

      remote
        ..addError(StateError('permission-denied'))
        ..add(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      expect(streamError, isNull);
      expect(snapshots.last.config.configVersion, _remoteVersion);
      expect(telemetry.errors.single.reason, ConfigTelemetry.sourceFailed);
      await subscription.cancel();
    });
  });

  group('telemetry context', () {
    test(
      'carries the version and origin of the configuration in use',
      () async {
        final subscription = repository().watch().listen((_) {});
        await pumpEventQueue();

        expect(telemetry.context, {
          ConfigTelemetry.versionKey: '$_bundledVersion',
          ConfigTelemetry.originKey: ConfigOrigin.bundled.name,
        });

        remote.add(_document(configVersion: _remoteVersion));
        await pumpEventQueue();

        expect(telemetry.context, {
          ConfigTelemetry.versionKey: '$_remoteVersion',
          ConfigTelemetry.originKey: ConfigOrigin.remote.name,
        });
        await subscription.cancel();
      },
    );
  });
}

final class _FailingConfigStore implements ConfigStore {
  @override
  Future<String?> read() async => throw StateError('storage unavailable');

  @override
  Future<void> write(String document) async =>
      throw StateError('storage unavailable');
}
