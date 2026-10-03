/// Values the parser uses when the published document omits a field or sends
/// it with the wrong type. They are the contract's defaults, listed in one
/// place so that the app, the tests and the documentation agree.
abstract final class ConfigDefaults {
  static const int configVersion = 0;
  static const bool moduleVisible = true;

  /// A feature that the document does not switch on explicitly stays off.
  static const bool featureEnabled = false;

  /// Upper bound for injected latency, so a wrong value published from the
  /// backoffice slows the app down but cannot make it unusable.
  static const Duration maxInjectedLatency = Duration(seconds: 10);
}

/// Names of the backend services that the resilience block can take down.
abstract final class ServiceIds {
  static const String movements = 'movements';
  static const String partnerInsurance = 'partnerInsurance';
}

/// The configuration published by the backoffice, already validated.
final class HomeConfig {
  const HomeConfig({
    required this.schemaVersion,
    required this.configVersion,
    required this.destinations,
    required this.resilience,
    required this.segments,
  });

  /// Segment used when the customer's segment is unknown to this document.
  static const String defaultSegmentId = 'starting';

  final int schemaVersion;
  final int configVersion;

  /// The only destinations an action may navigate to.
  final Set<String> destinations;
  final ResilienceSettings resilience;

  /// Never empty: a document without usable segments is rejected.
  final Map<String, SegmentConfig> segments;

  /// The segment for [segmentId], or a stable fallback when it is unknown:
  /// [defaultSegmentId] if present, otherwise the first id alphabetically.
  SegmentConfig segmentFor(String? segmentId) {
    final requested = segments[segmentId];
    if (requested != null) return requested;

    final fallback = segments[defaultSegmentId];
    if (fallback != null) return fallback;

    final ids = segments.keys.toList()..sort();
    return segments[ids.first]!;
  }
}

final class SegmentConfig {
  const SegmentConfig({
    required this.id,
    required this.label,
    required this.modules,
    required this.features,
  });

  final String id;
  final String label;

  /// In display order.
  final List<ModuleConfig> modules;
  final FeatureFlags features;
}

final class ModuleConfig {
  const ModuleConfig({
    required this.id,
    required this.type,
    required this.visible,
    required this.props,
  });

  /// Unique within its segment.
  final String id;

  /// Key of the widget a domain package registered. The platform does not
  /// know the valid types; the registry skips the ones nobody registered.
  final String type;
  final bool visible;

  /// Settings the module interprets itself. Unmodifiable, and already free of
  /// actions that point outside the destination allow-list.
  final Map<String, Object?> props;
}

final class FeatureFlags {
  const FeatureFlags({required this.transfers, required this.partnerServices});

  static const FeatureFlags allOff = FeatureFlags(
    transfers: ConfigDefaults.featureEnabled,
    partnerServices: ConfigDefaults.featureEnabled,
  );

  final bool transfers;
  final bool partnerServices;
}

/// Fault injection published with the configuration. It only has an effect
/// through the resilience policy.
final class ResilienceSettings {
  const ResilienceSettings({
    required this.latency,
    required this.unavailableServices,
  });

  static const ResilienceSettings none = ResilienceSettings(
    latency: Duration.zero,
    unavailableServices: {},
  );

  /// Delay added before every attempt of an operation.
  final Duration latency;

  /// [ServiceIds] that answer as unavailable.
  final Set<String> unavailableServices;

  bool isUnavailable(String serviceId) =>
      unavailableServices.contains(serviceId);
}
