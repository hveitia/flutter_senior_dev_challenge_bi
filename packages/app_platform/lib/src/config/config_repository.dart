import 'dart:async';
import 'dart:convert';

import 'package:app_platform/src/async/delay.dart';
import 'package:app_platform/src/config/home_config.dart';
import 'package:app_platform/src/config/home_config_parser.dart';
import 'package:app_platform/src/observability/telemetry.dart';

/// Where the configuration in use came from.
enum ConfigOrigin {
  /// Written in the code. Used only when not even the bundled document can
  /// be read, so the app still starts.
  lastResort,

  /// Shipped inside the app. Used on first launch, before anything is cached.
  bundled,

  /// The last valid document received, saved on the device.
  cached,

  /// Received from the backend during this session.
  remote,
}

final class ConfigSnapshot {
  const ConfigSnapshot({required this.config, required this.origin});

  final HomeConfig config;
  final ConfigOrigin origin;
}

/// Emits the raw published document every time it changes.
// Kept as an interface so adapters are named classes, like every other port.
// ignore: one_member_abstracts
abstract interface class ConfigSource {
  Stream<Object?> watch();
}

/// Keeps one raw document on the device between launches.
abstract interface class ConfigStore {
  Future<String?> read();

  Future<void> write(String document);
}

/// Returns the document shipped with the app, as JSON.
typedef BundledConfigLoader = Future<String> Function();

/// Names used when reporting about the configuration.
abstract final class ConfigTelemetry {
  /// Event: a configuration started being used. Carries origin and version.
  static const String applied = 'config_applied';

  /// Event: a published document was not accepted. Carries the reason.
  static const String rejected = 'config_rejected';

  /// Event: the document saved on the device is no longer valid.
  static const String cacheInvalid = 'config_cache_invalid';

  /// Event and error reason: the document shipped with the app is unusable.
  static const String bundledInvalid = 'config_bundled_invalid';

  /// Event and error reason: the remote source failed or ended.
  static const String sourceFailed = 'config_source_failed';

  /// Error reason: reading or writing the device storage failed.
  static const String cacheFailed = 'config_cache_failed';

  static const String reasonKey = 'reason';
  static const String versionKey = 'config_version';
  static const String originKey = 'config_origin';
  static const String attemptKey = 'attempt';
  static const String causeKey = 'cause';

  static const String loadFailedReason = 'load_failed';
  static const String errorCause = 'error';
  static const String closedCause = 'closed';
}

/// Decides which configuration the app runs with.
///
/// There is always one: the cached document if it is still valid, otherwise
/// the bundled one, otherwise [lastResort]. Remote documents replace it only
/// when the parser accepts them; a rejected document, a failing source or a
/// failing cache never take the current configuration away, and each of those
/// is reported.
///
/// The remote document is the authority: the last one received wins even if
/// its `configVersion` is lower than the one in use. An environment that is
/// seeded again restarts the counter, and devices must follow it instead of
/// staying on the higher version they had cached.
final class ConfigRepository {
  ConfigRepository({
    required ConfigSource source,
    required ConfigStore store,
    required BundledConfigLoader loadBundled,
    Telemetry telemetry = const NoopTelemetry(),
    HomeConfigParser parser = const HomeConfigParser(),
    Delay? delay,
  }) : _source = source,
       _store = store,
       _loadBundled = loadBundled,
       _telemetry = telemetry,
       _parser = parser,
       _delay = delay ?? Future<void>.delayed;

  /// Wait before subscribing again after the first failure of the source.
  /// It doubles on every consecutive failure, up to [resubscribeMaxDelay].
  static const Duration resubscribeBaseDelay = Duration(seconds: 2);
  static const Duration resubscribeMaxDelay = Duration(minutes: 1);

  /// One segment, no modules and every feature off. It carries no layout on
  /// purpose: the platform does not know which module types exist.
  static const HomeConfig lastResort = HomeConfig(
    schemaVersion: HomeConfigParser.supportedSchemaVersion,
    configVersion: ConfigDefaults.configVersion,
    destinations: {},
    resilience: ResilienceSettings.none,
    segments: {
      HomeConfig.defaultSegmentId: SegmentConfig(
        id: HomeConfig.defaultSegmentId,
        label: HomeConfig.defaultSegmentId,
        modules: [],
        features: FeatureFlags.allOff,
      ),
    },
  );

  final ConfigSource _source;
  final ConfigStore _store;
  final BundledConfigLoader _loadBundled;
  final Telemetry _telemetry;
  final HomeConfigParser _parser;
  final Delay _delay;

  /// The starting configuration first, then every valid remote document.
  ///
  /// The stream never fails and never ends by itself: when the remote source
  /// fails or completes, the repository subscribes to it again after a wait.
  Stream<ConfigSnapshot> watch() => _ConfigWatch(this).stream;

  Future<ConfigSnapshot> _startingPoint() async {
    final config = await _cached();
    if (config != null) {
      return ConfigSnapshot(config: config, origin: ConfigOrigin.cached);
    }

    final bundled = await _bundled();
    if (bundled != null) {
      return ConfigSnapshot(config: bundled, origin: ConfigOrigin.bundled);
    }

    return const ConfigSnapshot(
      config: lastResort,
      origin: ConfigOrigin.lastResort,
    );
  }

  Future<HomeConfig?> _cached() async {
    final String? document;
    try {
      document = await _store.read();
    } on Object catch (error, stackTrace) {
      _reportCacheFailure(error, stackTrace);
      return null;
    }
    if (document == null) return null;

    switch (_parser.parseJson(document)) {
      case ConfigAccepted(:final config):
        return config;
      case ConfigRejected(:final reason):
        _reportReason(ConfigTelemetry.cacheInvalid, reason.name);
        return null;
    }
  }

  Future<HomeConfig?> _bundled() async {
    final String document;
    try {
      document = await _loadBundled();
    } on Object catch (error, stackTrace) {
      _telemetry.recordError(
        error,
        stackTrace,
        reason: ConfigTelemetry.bundledInvalid,
      );
      _reportReason(
        ConfigTelemetry.bundledInvalid,
        ConfigTelemetry.loadFailedReason,
      );
      return null;
    }

    switch (_parser.parseJson(document)) {
      case ConfigAccepted(:final config):
        return config;
      case ConfigRejected(:final reason):
        _reportReason(ConfigTelemetry.bundledInvalid, reason.name);
        return null;
    }
  }

  /// Saves the raw document, so fields this version ignores are still there
  /// for a later one. Values JSON cannot represent, such as a backend
  /// timestamp, are saved as null instead of making the whole save fail.
  Future<void> _save(Object? document) async {
    try {
      await _store.write(
        jsonEncode(document, toEncodable: (unsupported) => null),
      );
    } on Object catch (error, stackTrace) {
      _reportCacheFailure(error, stackTrace);
    }
  }

  ConfigSnapshot _announce(ConfigSnapshot snapshot) {
    final version = snapshot.config.configVersion;
    final origin = snapshot.origin.name;

    _telemetry
      ..setContext(ConfigTelemetry.versionKey, '$version')
      ..setContext(ConfigTelemetry.originKey, origin)
      ..event(
        ConfigTelemetry.applied,
        parameters: {
          ConfigTelemetry.originKey: origin,
          ConfigTelemetry.versionKey: version,
        },
      );
    return snapshot;
  }

  void _reportReason(String event, String reason) {
    _telemetry.event(event, parameters: {ConfigTelemetry.reasonKey: reason});
  }

  void _reportCacheFailure(Object error, StackTrace stackTrace) {
    _telemetry.recordError(
      error,
      stackTrace,
      reason: ConfigTelemetry.cacheFailed,
    );
  }

  Duration _resubscribeDelay(int consecutiveFailures) {
    var delay = resubscribeBaseDelay;
    for (
      var failure = 1;
      failure < consecutiveFailures && delay < resubscribeMaxDelay;
      failure++
    ) {
      delay *= 2;
    }
    return delay > resubscribeMaxDelay ? resubscribeMaxDelay : delay;
  }
}

/// One listener of [ConfigRepository.watch] and its subscription to the
/// remote source.
///
/// Built on a controller instead of `async*`: a generator suspended on the
/// remote stream only notices a cancellation at its next `yield`, so
/// cancelling while the backend is quiet would never complete.
final class _ConfigWatch {
  _ConfigWatch(this._repository) {
    _controller = StreamController<ConfigSnapshot>(
      onListen: _start,
      onCancel: _cancel,
    );
  }

  final ConfigRepository _repository;
  late final StreamController<ConfigSnapshot> _controller;

  StreamSubscription<Object?>? _remote;
  bool _cancelled = false;
  int _consecutiveFailures = 0;

  Stream<ConfigSnapshot> get stream => _controller.stream;

  Future<void> _start() async {
    final startingPoint = await _repository._startingPoint();
    if (_cancelled) return;

    _controller.add(_repository._announce(startingPoint));
    _subscribe();
  }

  Future<void> _cancel() async {
    _cancelled = true;
    await _remote?.cancel();
  }

  void _subscribe() {
    _remote = _repository._source.watch().listen(
      _onDocument,
      onError: _onSourceError,
      onDone: () =>
          unawaited(_subscribeAgain(cause: ConfigTelemetry.closedCause)),
    );
  }

  void _onDocument(Object? document) {
    // Any document, valid or not, proves the source is answering again.
    _consecutiveFailures = 0;

    switch (_repository._parser.parse(document)) {
      case ConfigAccepted(:final config):
        _controller.add(
          _repository._announce(
            ConfigSnapshot(config: config, origin: ConfigOrigin.remote),
          ),
        );
        // Applying the configuration does not wait for the device storage.
        unawaited(_repository._save(document));
      case ConfigRejected(:final reason):
        _repository._reportReason(ConfigTelemetry.rejected, reason.name);
    }
  }

  void _onSourceError(Object error, StackTrace stackTrace) {
    _repository._telemetry.recordError(
      error,
      stackTrace,
      reason: ConfigTelemetry.sourceFailed,
    );
    unawaited(_subscribeAgain(cause: ConfigTelemetry.errorCause));
  }

  /// A source that failed is not expected to emit again (a Firestore listener
  /// is removed after an error), so the subscription is replaced by a new one
  /// instead of being kept.
  Future<void> _subscribeAgain({required String cause}) async {
    final failed = _remote;
    if (failed == null) return;
    _remote = null;

    final attempt = ++_consecutiveFailures;
    _repository._telemetry.event(
      ConfigTelemetry.sourceFailed,
      parameters: {
        ConfigTelemetry.attemptKey: attempt,
        ConfigTelemetry.causeKey: cause,
      },
    );

    await failed.cancel();
    await _repository._delay(_repository._resubscribeDelay(attempt));
    if (_cancelled) return;

    _subscribe();
  }
}
