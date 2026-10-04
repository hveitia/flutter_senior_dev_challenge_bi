/// The home of the signed-in customer, assembled at runtime from the
/// published configuration.
///
/// The app provides a `RemoteConfigCubit` and a `ConnectivityCubit` in the
/// tree, registers every domain's modules in a `HomeModuleRegistry` and
/// mounts `HomeScreen`. This package knows no other domain: modules reach it
/// only through the registry.
library;

export 'src/home_composition.dart';
export 'src/home_composition_cubit.dart';
export 'src/home_screen.dart';
export 'src/home_strings.dart' show initialsOf;
export 'src/home_telemetry.dart';
export 'src/modules/home_modules.dart';
