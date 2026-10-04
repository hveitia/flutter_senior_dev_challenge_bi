import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/destinations.dart';
import 'package:feature_services/adapters.dart';
import 'package:feature_services/feature_services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where partner content lives, decided when the app is built.
///
/// It is a build setting and not part of the published configuration on
/// purpose: what is published can switch a partner on or off, but it cannot
/// point the app at another server.
abstract final class PartnerBuildFlags {
  /// The origin partners' mini apps are loaded from, set with
  /// `--dart-define=PARTNER_BASE_URL=https://partners.example.com`. Empty
  /// when the build was not told, and then the app offers no mini app.
  static const String baseUrl = String.fromEnvironment('PARTNER_BASE_URL');

  /// Marks [baseUrl] as a developer's own machine, which is the only case
  /// where plain `http` is accepted. Off unless the build is made with
  /// `--dart-define=PARTNER_DEV_ORIGIN=true`.
  static const bool isDevelopmentOrigin = bool.fromEnvironment(
    'PARTNER_DEV_ORIGIN',
  );
}

/// Name of the step of the sign-out clean-up that removes what partners'
/// pages left on the device.
const String miniAppDataStep = 'mini_app_data';

/// What partners' pages leave in the web view, removed step by step, with a
/// note kept in [preferences] while a clean-up is unfinished.
MiniAppData composeMiniAppData(SharedPreferences preferences) {
  return StepwiseMiniAppData(
    steps: webViewDataSteps(),
    pending: SharedPreferencesPendingCleanUp(preferences),
  );
}

/// Builds what the services screens need on the device plugins.
///
/// [isReleaseBuild] is the build mode. A release build never loads partner
/// content over plain `http`, whatever the flags say.
ServicesDependencies composeServices({
  required ResiliencePolicy policy,
  required Telemetry telemetry,
  required MiniAppData data,
  bool isReleaseBuild = kReleaseMode,
}) {
  return ServicesDependencies(
    origin: PartnerOrigin.parse(
      PartnerBuildFlags.baseUrl,
      isDevelopment: PartnerBuildFlags.isDevelopmentOrigin,
      isReleaseBuild: isReleaseBuild,
    ),
    policy: policy,
    telemetry: telemetry,
    surfaceFactory: WebViewMiniAppSurface.new,
    externalLinks: const UrlLauncherExternalLinks(),
    data: data,
  );
}

/// [PendingCleanUp] kept in the device's preferences: one boolean that says
/// nothing about any customer.
final class SharedPreferencesPendingCleanUp implements PendingCleanUp {
  const SharedPreferencesPendingCleanUp(this._preferences);

  static const String _key = 'mini_apps.clean_up_pending';

  final SharedPreferences _preferences;

  @override
  Future<bool> isPending() async => _preferences.getBool(_key) ?? false;

  @override
  Future<void> setPending({required bool pending}) async {
    if (pending) {
      await _preferences.setBool(_key, true);
    } else {
      await _preferences.remove(_key);
    }
  }
}

/// The destinations of the partners' mini apps this build can open, each
/// behind the feature flag that switches partners on.
///
/// A build that was not told where partner content lives has none, so no
/// action anywhere in the app leads to a mini app that could not load.
Map<String, AppDestination> partnerDestinations(ServicesDependencies services) {
  return {
    for (final entry in services.miniApps)
      entry.destination: AppDestination(
        open: (context) =>
            unawaited(context.push(ServicesPaths.miniApp(entry.miniApp!.key))),
        isEnabled: _partnersEnabled,
      ),
  };
}

bool _partnersEnabled(FeatureFlags features) => features.partnerServices;

/// The app's one resolver, for whoever draws actions: the home, Servicios
/// and anything else that receives a destination by name.
///
/// It reads [RemoteConfigCubit] from the tree every time it is asked, so an
/// answer always reflects what is published at that moment.
AppDestinationResolver appDestinations(
  BuildContext context,
  ServicesDependencies services,
) {
  final config = context.read<RemoteConfigCubit>();

  return AppDestinationResolver(
    features: () => config.state.segment?.features ?? FeatureFlags.allOff,
    routes: {
      ...AppDestinationResolver.builtRoutes,
      ...partnerDestinations(services),
    },
  );
}
