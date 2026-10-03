/// Implementations of the `app_platform` ports on top of Firebase and device
/// plugins. Imported by the composition root only; domain packages depend on
/// the interfaces in `package:app_platform/app_platform.dart`.
library;

export 'src/adapters/bundled_config.dart';
export 'src/adapters/connectivity_plus_monitor.dart';
export 'src/adapters/firebase_telemetry.dart';
export 'src/adapters/firestore_config_source.dart';
export 'src/adapters/shared_preferences_config_store.dart';
