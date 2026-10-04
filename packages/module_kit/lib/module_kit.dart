/// What a domain package needs to take part in the home without knowing the
/// other domains: a registry of home modules, the destinations an action may
/// open and the host a module reports to.
///
/// Domain packages depend on this package and never on each other.
library;

export 'src/connection_banner.dart';
export 'src/destination_resolver.dart';
export 'src/home_module.dart';
export 'src/home_module_binding.dart';
export 'src/home_module_registry.dart';
