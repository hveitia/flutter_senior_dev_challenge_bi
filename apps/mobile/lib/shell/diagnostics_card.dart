import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app_dependencies.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the diagnostics card says. Kept apart from the widget so the
/// wording can be tested without a screen.
abstract final class DiagnosticsStrings {
  static const String title = 'Diagnóstico';
  static const String connection = 'Estado de conexión';
  static const String lastSync = 'Última sincronización';
  static const String configVersion = 'Versión de configuración';
  static const String appVersion = 'Versión de la app';

  static const String neverSynced = 'Sin sincronizar';
  static const String noConfig = 'Sin configuración';

  static String connectionStatus(ConnectivityStatus status) => switch (status) {
    ConnectivityStatus.online || ConnectivityStatus.restored => 'En línea',
    ConnectivityStatus.offline => 'Sin conexión',
    ConnectivityStatus.slow => 'Conexión lenta',
  };

  /// How long ago the accounts were last confirmed by the backend.
  ///
  /// A moment later than [now] happens when the device clock is moved back;
  /// it is written as just now rather than as a negative age.
  static String age(DateTime? syncedAt, {required DateTime now}) {
    if (syncedAt == null) return neverSynced;

    final elapsed = now.difference(syncedAt);
    if (elapsed < const Duration(minutes: 1)) return 'hace un momento';
    if (elapsed < const Duration(hours: 1)) {
      return 'hace ${elapsed.inMinutes} min';
    }
    if (elapsed < const Duration(days: 1)) return 'hace ${elapsed.inHours} h';
    return 'hace ${elapsed.inDays} d';
  }

  static String origin(ConfigOrigin origin) => switch (origin) {
    ConfigOrigin.remote => 'publicada',
    ConfigOrigin.cached => 'guardada',
    ConfigOrigin.bundled => 'incluida en la app',
    ConfigOrigin.lastResort => 'mínima',
  };

  /// `v14 · publicada`: the version in use and where it came from.
  static String config(int? version, ConfigOrigin? from) {
    if (version == null || from == null) return noConfig;
    return 'v$version · ${origin(from)}';
  }

  /// `1.0.0 (12)`.
  static String app(AppInfo info) => '${info.version} (${info.build})';
}

/// The state of the app as support would ask for it: connection, how fresh
/// the data is, which configuration is in use and which build this is.
///
/// Every value is the real one. It reads `ConnectivityCubit`, `AccountsBloc`
/// and `RemoteConfigCubit` from the tree, so it is the quickest way to see,
/// on the device, that a newly published configuration arrived.
class DiagnosticsCard extends StatelessWidget {
  const DiagnosticsCard({
    required this.appInfo,
    this.now = DateTime.now,
    super.key,
  });

  final AppInfo appInfo;

  /// The current moment, for the age of the last synchronization.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectivityCubit>().state;
    final accounts = context.watch<AccountsBloc>().state.accounts;
    final config = context.watch<RemoteConfigCubit>().state;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(context.metrics.cardRadius),
        border: Border.all(color: context.colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const GroupHeader(label: DiagnosticsStrings.title),
            DetailRow(
              label: DiagnosticsStrings.connection,
              value: DiagnosticsStrings.connectionStatus(connection),
            ),
            DetailRow(
              label: DiagnosticsStrings.lastSync,
              value: DiagnosticsStrings.age(accounts.syncedAt, now: now()),
            ),
            DetailRow(
              label: DiagnosticsStrings.configVersion,
              value: DiagnosticsStrings.config(config.version, config.origin),
            ),
            DetailRow(
              label: DiagnosticsStrings.appVersion,
              value: DiagnosticsStrings.app(appInfo),
            ),
          ],
        ),
      ),
    );
  }
}
