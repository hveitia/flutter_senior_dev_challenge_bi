import 'dart:convert';

import 'package:app_platform/src/config/home_config.dart';

/// Why a published document was not accepted.
enum ConfigRejectionReason {
  invalidJson,
  notAnObject,
  invalidSchemaVersion,
  unsupportedSchemaVersion,
  noUsableSegments,

  /// A module's props nest deeper than [HomeConfigParser.maxPropsDepth].
  propsTooDeep,

  /// Reading the document failed in a way the parser did not anticipate.
  unreadable,
}

/// Outcome of parsing a published document. Parsing never throws: callers
/// switch on the outcome and keep their last valid configuration on rejection.
sealed class ConfigParseResult {
  const ConfigParseResult();
}

final class ConfigAccepted extends ConfigParseResult {
  const ConfigAccepted(this.config);

  final HomeConfig config;
}

final class ConfigRejected extends ConfigParseResult {
  const ConfigRejected(this.reason);

  final ConfigRejectionReason reason;
}

/// Turns the raw published document into a [HomeConfig].
///
/// The document is written by another team and read by app versions that are
/// already installed, so the parser is tolerant by design: unknown fields are
/// ignored, missing or mistyped fields take the value in [ConfigDefaults],
/// malformed modules are skipped and actions pointing outside the destination
/// allow-list are dropped. Only a document this version cannot interpret at
/// all is rejected.
final class HomeConfigParser {
  const HomeConfigParser();

  /// Highest contract version this app version understands.
  static const int supportedSchemaVersion = 1;

  /// Levels of nested objects and lists a module's props may have, the props
  /// object included. Real props use three or four; the limit keeps a hostile
  /// or broken document from exhausting the stack.
  static const int maxPropsDepth = 32;

  static const int _firstSchemaVersion = 1;
  static const String _destinationKey = 'destination';

  ConfigParseResult parseJson(String source) {
    final Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException {
      return const ConfigRejected(ConfigRejectionReason.invalidJson);
    }
    return parse(raw);
  }

  ConfigParseResult parse(Object? raw) {
    try {
      return _parse(raw);
    } on _PropsTooDeep {
      return const ConfigRejected(ConfigRejectionReason.propsTooDeep);
    } on Object {
      // Last line of defense: the document comes from outside the app, so no
      // defect in reading it may take down the code that asked.
      return const ConfigRejected(ConfigRejectionReason.unreadable);
    }
  }

  ConfigParseResult _parse(Object? raw) {
    if (raw is! Map) {
      return const ConfigRejected(ConfigRejectionReason.notAnObject);
    }

    final schemaVersion = raw['schemaVersion'];
    if (schemaVersion is! int || schemaVersion < _firstSchemaVersion) {
      return const ConfigRejected(ConfigRejectionReason.invalidSchemaVersion);
    }
    if (schemaVersion > supportedSchemaVersion) {
      return const ConfigRejected(
        ConfigRejectionReason.unsupportedSchemaVersion,
      );
    }

    final destinations = _destinations(raw['destinations']);
    final segments = _segments(raw['segments'], destinations);
    if (segments.isEmpty) {
      return const ConfigRejected(ConfigRejectionReason.noUsableSegments);
    }

    return ConfigAccepted(
      HomeConfig(
        schemaVersion: schemaVersion,
        configVersion: _configVersion(raw['configVersion']),
        destinations: destinations,
        resilience: _resilience(raw['resilience']),
        segments: segments,
      ),
    );
  }

  Set<String> _destinations(Object? raw) {
    if (raw is! List) return const {};
    return Set.unmodifiable(
      raw.whereType<String>().where((destination) => destination.isNotEmpty),
    );
  }

  ResilienceSettings _resilience(Object? raw) {
    if (raw is! Map) return ResilienceSettings.none;

    return ResilienceSettings(
      latency: _injectedLatency(raw['latencyMs']),
      unavailableServices: Set.unmodifiable({
        if (raw['movementsUnavailable'] == true) ServiceIds.movements,
        if (raw['partnerInsuranceUnavailable'] == true)
          ServiceIds.partnerInsurance,
      }),
    );
  }

  /// Clamped while still a number: NaN and infinity cannot be rounded, and a
  /// huge value would overflow once converted to a [Duration].
  Duration _injectedLatency(Object? milliseconds) {
    if (milliseconds is! num || !milliseconds.isFinite) return Duration.zero;

    final max = ConfigDefaults.maxInjectedLatency.inMilliseconds;
    return Duration(milliseconds: milliseconds.clamp(0, max).round());
  }

  Map<String, SegmentConfig> _segments(Object? raw, Set<String> destinations) {
    if (raw is! Map) return const {};

    final segments = <String, SegmentConfig>{};
    for (final entry in raw.entries) {
      final id = entry.key;
      final body = entry.value;
      if (id is! String || id.isEmpty || body is! Map) continue;

      segments[id] = SegmentConfig(
        id: id,
        label: _nonEmptyStringOr(body['label'], id),
        modules: _modules(body['modules'], destinations),
        features: _features(body['features']),
      );
    }
    return Map.unmodifiable(segments);
  }

  List<ModuleConfig> _modules(Object? raw, Set<String> destinations) {
    if (raw is! List) return const [];

    final modules = <ModuleConfig>[];
    final seenIds = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;

      final id = item['id'];
      final type = item['type'];
      if (id is! String || id.isEmpty) continue;
      if (type is! String || type.isEmpty) continue;
      if (!seenIds.add(id)) continue;

      modules.add(
        ModuleConfig(
          id: id,
          type: type,
          visible: _boolOr(
            item['visible'],
            fallback: ConfigDefaults.moduleVisible,
          ),
          props: _props(item['props'], destinations),
        ),
      );
    }
    return List.unmodifiable(modules);
  }

  FeatureFlags _features(Object? raw) {
    if (raw is! Map) return FeatureFlags.allOff;
    return FeatureFlags(
      transfers: _boolOr(
        raw['transfers'],
        fallback: ConfigDefaults.featureEnabled,
      ),
      partnerServices: _boolOr(
        raw['partnerServices'],
        fallback: ConfigDefaults.featureEnabled,
      ),
    );
  }

  Map<String, Object?> _props(Object? raw, Set<String> destinations) {
    if (raw is! Map) return const {};
    return _sanitizedMap(raw, destinations, depth: 1);
  }

  /// Copies [raw] into an unmodifiable map, leaving out every nested object
  /// that carries a destination outside the allow-list.
  ///
  /// Props are opaque to the platform, so the rule is structural: whatever
  /// object has a `destination` is an action, wherever it sits.
  Map<String, Object?> _sanitizedMap(
    Map<Object?, Object?> raw,
    Set<String> destinations, {
    required int depth,
  }) {
    if (depth > maxPropsDepth) throw const _PropsTooDeep();

    final copy = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) continue;

      final value = entry.value;
      if (_isForbiddenAction(value, destinations)) continue;
      copy[key] = _sanitized(value, destinations, depth: depth + 1);
    }
    return Map.unmodifiable(copy);
  }

  /// [depth] is the level [value] would occupy if it is an object or a list.
  Object? _sanitized(
    Object? value,
    Set<String> destinations, {
    required int depth,
  }) {
    if (value is Map) return _sanitizedMap(value, destinations, depth: depth);
    if (value is List) {
      if (depth > maxPropsDepth) throw const _PropsTooDeep();
      return List<Object?>.unmodifiable(
        value
            .where((item) => !_isForbiddenAction(item, destinations))
            .map((item) => _sanitized(item, destinations, depth: depth + 1)),
      );
    }
    return value;
  }

  bool _isForbiddenAction(Object? value, Set<String> destinations) {
    if (value is! Map || !value.containsKey(_destinationKey)) return false;
    return !destinations.contains(value[_destinationKey]);
  }

  /// The counter of publishes: a whole number that is never negative.
  int _configVersion(Object? value) =>
      value is int && value >= 0 ? value : ConfigDefaults.configVersion;

  bool _boolOr(Object? value, {required bool fallback}) =>
      value is bool ? value : fallback;

  String _nonEmptyStringOr(Object? value, String fallback) =>
      value is String && value.isNotEmpty ? value : fallback;
}

/// Unwinds the recursion over a module's props once it passes the limit.
final class _PropsTooDeep implements Exception {
  const _PropsTooDeep();
}
