import 'package:flutter/widgets.dart';
import 'package:module_kit/src/destination_resolver.dart';
import 'package:module_kit/src/home_module.dart';

/// A [DestinationResolver] that opens only the destinations in [available]
/// and records which ones were opened.
final class FakeDestinationResolver implements DestinationResolver {
  FakeDestinationResolver({Set<String> available = const {}})
    : available = {...available};

  /// Destinations this resolver can open. Tests may change it.
  final Set<String> available;

  /// Every destination opened, in order.
  final List<String> opened = [];

  @override
  DestinationOpener? resolve(String destination) {
    if (!available.contains(destination)) return null;
    return (context) => opened.add(destination);
  }
}

/// A [HomeModuleHost] that records what modules report and keeps the
/// refreshers they register.
final class RecordingModuleHost implements HomeModuleHost {
  /// The last status reported by each module.
  final Map<String, HomeModuleStatus> statuses = {};

  /// Every report, in order.
  final List<(String moduleId, HomeModuleStatus status)> reports = [];

  final List<Future<void> Function()> refreshers = [];

  @override
  void report(String moduleId, HomeModuleStatus status) {
    statuses[moduleId] = status;
    reports.add((moduleId, status));
  }

  @override
  VoidCallback addRefresher(Future<void> Function() refresh) {
    refreshers.add(refresh);
    return () => refreshers.remove(refresh);
  }

  /// Runs every registered refresher, as the home does on pull to refresh.
  Future<void> refreshAll() => Future.wait([
    for (final refresh in [...refreshers]) refresh(),
  ]);
}

/// A module context for tests, with defaults for everything but the props.
HomeModuleContext moduleContext({
  String id = 'module',
  String type = 'type',
  Map<String, Object?> props = const {},
  DestinationResolver? destinations,
  HomeModuleHost? host,
}) {
  return HomeModuleContext(
    id: id,
    type: type,
    props: props,
    destinations: destinations ?? FakeDestinationResolver(),
    host: host ?? RecordingModuleHost(),
  );
}
