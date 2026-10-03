/// Cross-cutting capabilities for domain packages: published configuration,
/// resilience, connectivity and telemetry.
///
/// Nothing exported here depends on Flutter widgets, Firebase or any plugin.
/// The adapters that do live in `package:app_platform/adapters.dart` and are
/// meant for the composition root only.
library;

export 'src/async/delay.dart';
export 'src/config/config_repository.dart';
export 'src/config/home_config.dart';
export 'src/config/home_config_parser.dart';
export 'src/config/remote_config_cubit.dart';
export 'src/connectivity/connectivity_cubit.dart';
export 'src/observability/app_bloc_observer.dart';
export 'src/observability/telemetry.dart';
export 'src/resilience/failure.dart';
export 'src/resilience/resilience_policy.dart';
