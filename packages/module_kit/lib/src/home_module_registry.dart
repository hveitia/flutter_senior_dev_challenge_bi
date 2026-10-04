import 'package:module_kit/src/home_module.dart';

/// The module types this build of the app can draw, and who draws each.
///
/// Every domain package registers its own types when the app is composed.
/// The published configuration only names types; a type nobody registered
/// is simply not drawn, which is what lets the backoffice publish a module
/// before every installed version knows it.
final class HomeModuleRegistry {
  final Map<String, HomeModuleBuilder> _builders = {};

  /// The registered types.
  Set<String> get types => _builders.keys.toSet();

  /// Registers [builder] for [type]. A type has one owner: registering it
  /// twice is a mistake in how the app is composed and fails at once.
  void register(String type, HomeModuleBuilder builder) {
    if (_builders.containsKey(type)) {
      throw StateError('The home module "$type" is already registered.');
    }
    _builders[type] = builder;
  }

  /// Who draws [type], or null when no package registered it.
  HomeModuleBuilder? builderFor(String type) => _builders[type];
}
