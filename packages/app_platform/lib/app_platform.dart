/// Cross-cutting capabilities for domain packages: published configuration,
/// resilience, connectivity and telemetry.
///
/// Nothing exported here depends on Flutter widgets, Firebase or any plugin.
/// The adapters that do live in `package:app_platform/adapters.dart` and are
/// meant for the composition root only.
library;

export 'src/config/home_config.dart';
export 'src/config/home_config_parser.dart';
export 'src/observability/telemetry.dart';
