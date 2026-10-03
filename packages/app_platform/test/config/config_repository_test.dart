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
const int _unsupportedSchema = 99;

/// Stands in for the clock: records every wait and ends it on demand.
final class _ManualDelay {
  final List<Duration> requested = [];
  late Completer<void> _pending;

  Future<void> call(Duration duration) {
    requested.add(duration);
    return (_pending = Completer<void>()).future;
  }

  /// Ends the wait in progress and lets its continuation run.
  Future<void> elapse() async {
    _pending.complete();
    await pumpEventQueue();
  }
}

void main() {
  late FakeConfigSource source;
  late InMemoryConfigStore store;
  late InMemoryTelemetry telemetry;
  late _ManualDelay delay;

  ConfigRepository repository({
    ConfigStore? withStore,
    BundledConfigLoader? loadBundled,
  }) {
    return ConfigRepository(
      source: source,
      store: withStore ?? store,
      loadBundled:
          loadBundled ??
          () async => jsonEncode(_document(configVersion: _bundledVersion)),
      telemetry: telemetry,
      delay: delay.call,
    );
  }

  /// Listens to [watched] until the test ends and returns what it emits,
  /// once its starting point was delivered.
  Future<List<ConfigSnapshot>> listenTo(ConfigRepository watched) async {
    final snapshots = <ConfigSnapshot>[];
    final subscription = watched.watch().listen(snapshots.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    return snapshots;
  }

  List<TelemetryEvent> eventsNamed(String name) =>
      telemetry.events.where((event) => event.name == name).toList();

  setUp(() {
    source = FakeConfigSource();
    store = InMemoryConfigStore();
    telemetry = InMemoryTelemetry();
    delay = _ManualDelay();
  });

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

    test('is the bundled one when the cached document is corrupt, and the '
        'discarded cache is reported', () async {
      store.document = '{corrupt';

      final first = await repository().watch().first;

      expect(first.origin, ConfigOrigin.bundled);
      expect(eventsNamed(ConfigTelemetry.cacheInvalid).single.parameters, {
        ConfigTelemetry.reasonKey: ConfigRejectionReason.invalidJson.name,
      });
    });

    test('is the bundled one when the cached document is from a newer schema '
        'than this app supports', () async {
      store.document = jsonEncode(_document(schemaVersion: _unsupportedSchema));

      final first = await repository().watch().first;

      expect(first.origin, ConfigOrigin.bundled);
      expect(eventsNamed(ConfigTelemetry.cacheInvalid).single.parameters, {
        ConfigTelemetry.reasonKey:
            ConfigRejectionReason.unsupportedSchemaVersion.name,
      });
    });

    test('is the bundled one when the cache cannot be read, and the failure '
        'is reported', () async {
      final first = await repository(
        withStore: _FailingConfigStore(),
      ).watch().first;

      expect(first.origin, ConfigOrigin.bundled);
      expect(telemetry.errors.single.reason, ConfigTelemetry.cacheFailed);
    });
  });

  group('last resort', () {
    test('is used when the bundled configuration is invalid', () async {
      final first = await repository(
        loadBundled: () async => '{corrupt',
      ).watch().first;

      expect(first.origin, ConfigOrigin.lastResort);
      expect(first.config, same(ConfigRepository.lastResort));
      expect(eventsNamed(ConfigTelemetry.bundledInvalid).single.parameters, {
        ConfigTelemetry.reasonKey: ConfigRejectionReason.invalidJson.name,
      });
    });

    test('is used when the bundled configuration cannot be loaded', () async {
      final first = await repository(
        loadBundled: () async => throw StateError('asset missing'),
      ).watch().first;

      expect(first.origin, ConfigOrigin.lastResort);
      expect(telemetry.errors.single.reason, ConfigTelemetry.bundledInvalid);
      expect(eventsNamed(ConfigTelemetry.bundledInvalid).single.parameters, {
        ConfigTelemetry.reasonKey: ConfigTelemetry.loadFailedReason,
      });
    });

    test('has a segment to resolve and switches every feature off', () {
      final segment = ConfigRepository.lastResort.segmentFor(null);

      expect(segment.id, HomeConfig.defaultSegmentId);
      expect(segment.modules, isEmpty);
      expect(segment.features.transfers, isFalse);
      expect(segment.features.partnerServices, isFalse);
      expect(
        ConfigRepository.lastResort.resilience.unavailableServices,
        isEmpty,
      );
    });

    test('still gives way to a valid remote document', () async {
      final snapshots = await listenTo(
        repository(loadBundled: () async => '{corrupt'),
      );

      source.publish(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      expect(snapshots.map((snapshot) => snapshot.origin), [
        ConfigOrigin.lastResort,
        ConfigOrigin.remote,
      ]);
    });
  });

  group('a valid remote document', () {
    test('replaces the current configuration', () async {
      final snapshots = await listenTo(repository());

      source.publish(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      expect(snapshots.map((snapshot) => snapshot.origin), [
        ConfigOrigin.bundled,
        ConfigOrigin.remote,
      ]);
      expect(snapshots.last.config.configVersion, _remoteVersion);
    });

    test('wins over a cached configuration with a higher version', () async {
      store.document = jsonEncode(_document(configVersion: _remoteVersion));
      final snapshots = await listenTo(repository());

      source.publish(_document(configVersion: _cachedVersion));
      await pumpEventQueue();

      expect(snapshots.last.origin, ConfigOrigin.remote);
      expect(snapshots.last.config.configVersion, _cachedVersion);
    });

    test('wins over an earlier remote one with a higher version', () async {
      final snapshots = await listenTo(repository());

      source
        ..publish(_document(configVersion: _remoteVersion))
        ..publish(_document(configVersion: _cachedVersion));
      await pumpEventQueue();

      expect(
        snapshots.map((snapshot) => snapshot.config.configVersion),
        [_bundledVersion, _remoteVersion, _cachedVersion],
      );
    });

    test('is saved so the next cold start can use it offline', () async {
      await listenTo(repository());

      source.publish(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      final saved = const HomeConfigParser().parseJson(store.document!);
      expect((saved as ConfigAccepted).config.configVersion, _remoteVersion);
    });

    test('is saved without the values JSON cannot represent', () async {
      await listenTo(repository());

      source.publish({
        ..._document(configVersion: _remoteVersion),
        'publishedAt': DateTime(2026, 10, 3),
        'resilience': {'latencyMs': double.nan},
      });
      await pumpEventQueue();

      final saved = const HomeConfigParser().parseJson(store.document!);
      expect((saved as ConfigAccepted).config.configVersion, _remoteVersion);
      expect(telemetry.errors, isEmpty);
    });

    test('is still applied when saving it fails, and the failure is '
        'reported', () async {
      final snapshots = await listenTo(
        repository(withStore: _FailingConfigStore()),
      );
      telemetry.errors.clear();

      source.publish(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      expect(snapshots.last.origin, ConfigOrigin.remote);
      expect(telemetry.errors.single.reason, ConfigTelemetry.cacheFailed);
    });

    test('is still applied when it cannot be encoded at all, and the failure '
        'is reported', () async {
      final snapshots = await listenTo(repository());
      final cyclic = _document(configVersion: _remoteVersion);
      cyclic['self'] = cyclic;

      source.publish(cyclic);
      await pumpEventQueue();

      expect(snapshots.last.origin, ConfigOrigin.remote);
      expect(store.document, isNull);
      expect(telemetry.errors.single.reason, ConfigTelemetry.cacheFailed);
    });
  });

  group('a rejected remote document', () {
    test('keeps the last valid configuration and is not saved', () async {
      store.document = jsonEncode(_document(configVersion: _cachedVersion));
      final cachedDocument = store.document;
      final snapshots = await listenTo(repository());

      source.publish(
        _document(
          configVersion: _remoteVersion,
          schemaVersion: _unsupportedSchema,
        ),
      );
      await pumpEventQueue();

      expect(snapshots.single.config.configVersion, _cachedVersion);
      expect(store.document, cachedDocument);
    });

    test('is reported with the reason', () async {
      await listenTo(repository());

      source.publish(_document(schemaVersion: _unsupportedSchema));
      await pumpEventQueue();

      expect(eventsNamed(ConfigTelemetry.rejected).single.parameters, {
        ConfigTelemetry.reasonKey:
            ConfigRejectionReason.unsupportedSchemaVersion.name,
      });
    });

    test('does not stop later valid documents from being applied', () async {
      final snapshots = await listenTo(repository());

      source
        ..publish('not a document')
        ..publish(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      expect(snapshots.last.config.configVersion, _remoteVersion);
    });
  });

  group('a failing remote source', () {
    test('keeps the current configuration and does not fail the '
        'stream', () async {
      final snapshots = <ConfigSnapshot>[];
      Object? streamError;
      final subscription = repository().watch().listen(
        snapshots.add,
        onError: (Object error) => streamError = error,
      );
      await pumpEventQueue();

      source.fail(StateError('permission-denied'));
      await pumpEventQueue();

      expect(streamError, isNull);
      expect(snapshots.single.origin, ConfigOrigin.bundled);
      await subscription.cancel();
    });

    test('is reported with the number of the failure', () async {
      await listenTo(repository());

      source.fail(StateError('permission-denied'));
      await pumpEventQueue();

      expect(telemetry.errors.single.reason, ConfigTelemetry.sourceFailed);
      expect(eventsNamed(ConfigTelemetry.sourceFailed).single.parameters, {
        ConfigTelemetry.attemptKey: 1,
        ConfigTelemetry.causeKey: ConfigTelemetry.errorCause,
      });
    });

    test('is subscribed to again after a wait, and recovers', () async {
      final snapshots = await listenTo(repository());

      source.fail(StateError('permission-denied'));
      await pumpEventQueue();

      expect(source.subscriptions, 1);
      expect(delay.requested, [ConfigRepository.resubscribeBaseDelay]);

      await delay.elapse();
      source.publish(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      expect(source.subscriptions, 2);
      expect(snapshots.last.config.configVersion, _remoteVersion);
    });

    test('is subscribed to again when it ends without an error', () async {
      await listenTo(repository());

      source.complete();
      await pumpEventQueue();
      await delay.elapse();

      expect(source.subscriptions, 2);
      expect(eventsNamed(ConfigTelemetry.sourceFailed).single.parameters, {
        ConfigTelemetry.attemptKey: 1,
        ConfigTelemetry.causeKey: ConfigTelemetry.closedCause,
      });
      expect(telemetry.errors, isEmpty);
    });

    test('waits twice as long after every failure in a row, up to a '
        'limit', () async {
      const failures = 7;
      await listenTo(repository());

      for (var failure = 0; failure < failures; failure++) {
        source.fail(StateError('permission-denied'));
        await pumpEventQueue();
        await delay.elapse();
      }

      expect(delay.requested, const [
        Duration(seconds: 2),
        Duration(seconds: 4),
        Duration(seconds: 8),
        Duration(seconds: 16),
        Duration(seconds: 32),
        ConfigRepository.resubscribeMaxDelay,
        ConfigRepository.resubscribeMaxDelay,
      ]);
      expect(ConfigRepository.resubscribeBaseDelay, const Duration(seconds: 2));
      expect(
        eventsNamed(
          ConfigTelemetry.sourceFailed,
        ).map((event) => event.parameters[ConfigTelemetry.attemptKey]),
        [for (var attempt = 1; attempt <= failures; attempt++) attempt],
      );
    });

    test('goes back to the short wait once a document arrives', () async {
      await listenTo(repository());

      source.fail(StateError('first'));
      await pumpEventQueue();
      await delay.elapse();
      source.fail(StateError('second'));
      await pumpEventQueue();
      await delay.elapse();
      source
        ..publish(_document(configVersion: _remoteVersion))
        ..fail(StateError('third'));
      await pumpEventQueue();

      expect(delay.requested.last, ConfigRepository.resubscribeBaseDelay);
    });

    test('is not subscribed to again once nobody is listening', () async {
      final subscription = repository().watch().listen((_) {});
      await pumpEventQueue();

      source.fail(StateError('permission-denied'));
      await pumpEventQueue();
      await subscription.cancel();
      await delay.elapse();

      expect(source.subscriptions, 1);
    });
  });

  group('telemetry', () {
    test('context carries the version and origin of the configuration in '
        'use', () async {
      await listenTo(repository());

      expect(telemetry.context, {
        ConfigTelemetry.versionKey: '$_bundledVersion',
        ConfigTelemetry.originKey: ConfigOrigin.bundled.name,
      });

      source.publish(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      expect(telemetry.context, {
        ConfigTelemetry.versionKey: '$_remoteVersion',
        ConfigTelemetry.originKey: ConfigOrigin.remote.name,
      });
    });

    test('an event is emitted for every configuration applied, with its '
        'origin', () async {
      store.document = jsonEncode(_document(configVersion: _cachedVersion));
      await listenTo(repository());

      source.publish(_document(configVersion: _remoteVersion));
      await pumpEventQueue();

      expect(
        eventsNamed(ConfigTelemetry.applied).map((event) => event.parameters),
        [
          {
            ConfigTelemetry.originKey: ConfigOrigin.cached.name,
            ConfigTelemetry.versionKey: _cachedVersion,
          },
          {
            ConfigTelemetry.originKey: ConfigOrigin.remote.name,
            ConfigTelemetry.versionKey: _remoteVersion,
          },
        ],
      );
    });
  });
}

final class _FailingConfigStore implements ConfigStore {
  @override
  Future<String?> read() async => throw StateError('storage unavailable');

  @override
  Future<void> write(String document) async =>
      throw StateError('storage unavailable');
}
