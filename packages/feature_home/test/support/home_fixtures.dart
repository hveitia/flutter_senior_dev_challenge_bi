import 'dart:convert';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';

/// One module of a published document.
Map<String, Object?> moduleDocument(
  String id,
  String type, {
  bool visible = true,
  Map<String, Object?> props = const {},
}) {
  return {'id': id, 'type': type, 'visible': visible, 'props': props};
}

/// A published document with the given modules per segment.
Map<String, Object?> configDocument({
  required Map<String, List<Map<String, Object?>>> segments,
  int configVersion = 14,
  List<String> destinations = const ['accounts', 'services', 'transfer'],
}) {
  return {
    'schemaVersion': HomeConfigParser.supportedSchemaVersion,
    'configVersion': configVersion,
    'destinations': destinations,
    'resilience': {
      'latencyMs': 0,
      'movementsUnavailable': false,
      'partnerInsuranceUnavailable': false,
    },
    'segments': {
      for (final MapEntry(key: id, value: modules) in segments.entries)
        id: {
          'label': id,
          'modules': modules,
          'features': {'transfers': true, 'partnerServices': true},
        },
    },
  };
}

/// The segment [segmentId] of [document], as the parser accepts it.
SegmentConfig segmentOf(Map<String, Object?> document, String segmentId) {
  final result = const HomeConfigParser().parse(document);
  return (result as ConfigAccepted).config.segmentFor(segmentId);
}

/// A [RemoteConfigCubit] whose remote source the test drives. It starts from
/// the bundled document, as a device does on its first launch.
final class ConfigHarness {
  ConfigHarness({required Map<String, Object?> bundled, String? segmentId})
    : source = FakeConfigSource() {
    cubit = RemoteConfigCubit(
      ConfigRepository(
        source: source,
        store: InMemoryConfigStore(),
        loadBundled: () async => jsonEncode(bundled),
      ),
      segmentId: segmentId,
    )..start();
  }

  final FakeConfigSource source;
  late final RemoteConfigCubit cubit;
}
