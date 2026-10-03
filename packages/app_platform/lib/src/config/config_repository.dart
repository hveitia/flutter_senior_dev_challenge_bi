import 'dart:async';
import 'dart:convert';

import 'package:app_platform/src/config/home_config.dart';
import 'package:app_platform/src/config/home_config_parser.dart';
import 'package:app_platform/src/observability/telemetry.dart';

/// Where the configuration in use came from.
enum ConfigOrigin {
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
  static const String rejected = 'config_rejected';
  static const String sourceFailed = 'config_source_failed';
  static const String cacheFailed = 'config_cache_failed';
  static const String reasonKey = 'reason';
  static const String versionKey = 'config_version';
  static const String originKey = 'config_origin';
}

/// Decides which configuration the app runs with.
///
/// There is always one: the cached document if it is still valid, otherwise
/// the bundled one. Remote documents replace it only when the parser accepts
/// them; a rejected document, a failing source or a failing cache never take
/// the current configuration away.
final class ConfigRepository {
  const ConfigRepository({
    required ConfigSource source,
    required ConfigStore store,
    required BundledConfigLoader loadBundled,
    Telemetry telemetry = const NoopTelemetry(),
    HomeConfigParser parser = const HomeConfigParser(),
  }) : _source = source,
       _store = store,
       _loadBundled = loadBundled,
       _telemetry = telemetry,
       _parser = parser;

  final ConfigSource _source;
  final ConfigStore _store;
  final BundledConfigLoader _loadBundled;
  final Telemetry _telemetry;
  final HomeConfigParser _parser;

  /// The starting configuration first, then every valid remote document.
  ///
  /// Built on a controller instead of `async*`: a generator suspended on the
  /// remote stream only notices a cancellation at its next `yield`, so
  /// cancelling while the backend is quiet would never complete.
  Stream<ConfigSnapshot> watch() {
    late final StreamController<ConfigSnapshot> controller;
    StreamSubscription<Object?>? remote;
    var cancelled = false;

    Future<void> start() async {
      final ConfigSnapshot startingPoint;
      try {
        startingPoint = await _startingPoint();
      } on Object catch (error, stackTrace) {
        if (cancelled) return;
        controller.addError(error, stackTrace);
        await controller.close();
        return;
      }
      if (cancelled) return;

      controller.add(_announce(startingPoint));
      remote = _source.watch().listen(
        (document) => _onRemoteDocument(document, controller),
        onError: _reportSourceFailure,
        onDone: controller.close,
      );
    }

    controller = StreamController<ConfigSnapshot>(
      onListen: start,
      onCancel: () {
        cancelled = true;
        return remote?.cancel();
      },
    );
    return controller.stream;
  }

  void _onRemoteDocument(
    Object? document,
    StreamController<ConfigSnapshot> controller,
  ) {
    switch (_parser.parse(document)) {
      case ConfigAccepted(:final config):
        controller.add(
          _announce(
            ConfigSnapshot(config: config, origin: ConfigOrigin.remote),
          ),
        );
        // Applying the configuration does not wait for the device storage.
        unawaited(_save(document));
      case ConfigRejected(:final reason):
        _reportRejection(reason);
    }
  }

  Future<ConfigSnapshot> _startingPoint() async {
    final cached = await _readCache();
    if (cached != null) {
      final result = _parser.parseJson(cached);
      if (result is ConfigAccepted) {
        return ConfigSnapshot(
          config: result.config,
          origin: ConfigOrigin.cached,
        );
      }
    }

    final bundled = _parser.parseJson(await _loadBundled());
    return switch (bundled) {
      ConfigAccepted(:final config) => ConfigSnapshot(
        config: config,
        origin: ConfigOrigin.bundled,
      ),
      // The bundled document ships with the app and is covered by a test, so
      // this is a build defect, not a runtime condition to recover from.
      ConfigRejected(:final reason) => throw StateError(
        'The bundled configuration is invalid: ${reason.name}',
      ),
    };
  }

  Future<String?> _readCache() async {
    try {
      return await _store.read();
    } on Object catch (error, stackTrace) {
      _reportCacheFailure(error, stackTrace);
      return null;
    }
  }

  Future<void> _save(Object? document) async {
    try {
      await _store.write(jsonEncode(document));
    } on Object catch (error, stackTrace) {
      _reportCacheFailure(error, stackTrace);
    }
  }

  ConfigSnapshot _announce(ConfigSnapshot snapshot) {
    _telemetry
      ..setContext(
        ConfigTelemetry.versionKey,
        '${snapshot.config.configVersion}',
      )
      ..setContext(ConfigTelemetry.originKey, snapshot.origin.name);
    return snapshot;
  }

  void _reportRejection(ConfigRejectionReason reason) {
    _telemetry.log(
      LogLevel.warning,
      ConfigTelemetry.rejected,
      context: {ConfigTelemetry.reasonKey: reason.name},
    );
  }

  void _reportSourceFailure(Object error, StackTrace stackTrace) {
    _telemetry.recordError(
      error,
      stackTrace,
      reason: ConfigTelemetry.sourceFailed,
    );
  }

  void _reportCacheFailure(Object error, StackTrace stackTrace) {
    _telemetry.recordError(
      error,
      stackTrace,
      reason: ConfigTelemetry.cacheFailed,
    );
  }
}
