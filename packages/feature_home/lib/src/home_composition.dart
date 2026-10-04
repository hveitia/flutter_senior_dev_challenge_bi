import 'package:app_platform/app_platform.dart';
import 'package:equatable/equatable.dart';

/// What the home of one customer is made of, after matching the published
/// configuration against what this version of the app can draw.
final class HomeComposition extends Equatable {
  const HomeComposition({required this.modules, required this.skippedTypes});

  /// The modules to draw, top to bottom.
  final List<ModuleConfig> modules;

  /// Types that were published as visible but nobody registered.
  final Set<String> skippedTypes;

  @override
  List<Object?> get props => [modules, skippedTypes];
}

/// Decides what to draw for [segment] given the module types this build
/// registered.
///
/// The order is the published one. A module published as not visible is left
/// out. So is a module of a type nobody registered, which is what lets the
/// backoffice publish a new kind of module before every installed version
/// knows how to draw it.
HomeComposition composeHome(SegmentConfig segment, Set<String> registered) {
  final modules = <ModuleConfig>[];
  final skippedTypes = <String>{};

  for (final module in segment.modules) {
    if (!module.visible) continue;
    if (registered.contains(module.type)) {
      modules.add(module);
    } else {
      skippedTypes.add(module.type);
    }
  }

  return HomeComposition(modules: modules, skippedTypes: skippedTypes);
}
