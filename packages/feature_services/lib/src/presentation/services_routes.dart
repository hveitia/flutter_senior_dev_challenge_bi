import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_services/src/domain/host_contract.dart';
import 'package:feature_services/src/domain/service_catalog.dart';
import 'package:feature_services/src/presentation/catalog/services_screen.dart';
import 'package:feature_services/src/presentation/mini_app/mini_app_cubit.dart';
import 'package:feature_services/src/presentation/mini_app/mini_app_screen.dart';
import 'package:feature_services/src/presentation/mini_app/mini_app_unavailable_view.dart';
import 'package:feature_services/src/presentation/services_strings.dart';
import 'package:feature_services/src/services_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:module_kit/module_kit.dart';

/// Locations owned by the services feature. The Servicios section itself is
/// a section of the app, which decides where it lives.
abstract final class ServicesPaths {
  static const String _serviceKey = 'service';
  static const String _miniApp = '/aliados/:$_serviceKey';

  /// The mini app of the partner service with [key]: `travelInsurance`.
  static String miniApp(String key) => '/aliados/${Uri.encodeComponent(key)}';
}

/// The Servicios section. The app mounts it inside its navigation shell, at
/// [path].
///
/// [destinations] gives the app's one resolver. The section follows
/// [RemoteConfigCubit], read from the tree, so a partner switched on or off
/// in the published configuration appears or disappears while the customer
/// is looking.
GoRoute servicesTabRoute({
  required String path,
  required DestinationResolver Function(BuildContext context) destinations,
  ServiceCatalog catalog = ServiceCatalog.standard,
}) => GoRoute(
  path: path,
  builder: (context, state) {
    context.watch<RemoteConfigCubit>();
    return ServicesScreen(
      catalog: catalog,
      destinations: destinations(context),
    );
  },
);

/// A partner's mini app. The app mounts it outside its navigation shell: it
/// covers the whole screen. [servicesPath] is where "Volver a Servicios"
/// leads, and where closing leads when there is nothing to go back to.
///
/// It can be opened by its address, so a banner or a notification can lead
/// straight to it. For that reason it checks again what the listing already
/// checked: a service this version does not have, or partners switched off
/// in the published configuration, show the unavailable screen and load
/// nothing.
GoRoute miniAppRoute(
  ServicesDependencies dependencies, {
  required String servicesPath,
}) => GoRoute(
  path: ServicesPaths._miniApp,
  builder: (context, state) {
    final key = state.pathParameters[ServicesPaths._serviceKey]!;
    final service = dependencies.catalog.partner(key);
    final config = context.watch<RemoteConfigCubit>().state;
    final partnersEnabled = config.segment?.features.partnerServices ?? false;

    void backToServices() => context.go(servicesPath);
    void close() => context.canPop() ? context.pop() : backToServices();

    if (service == null || !partnersEnabled) {
      return _ServiceNotOffered(
        onClose: close,
        onBackToServices: backToServices,
      );
    }

    return BlocProvider<MiniAppCubit>(
      key: ValueKey(key),
      create: (context) {
        final remoteConfig = context.read<RemoteConfigCubit>();
        final cubit = MiniAppCubit(
          service: service,
          origin: dependencies.origin,
          // The segment and the language, and nothing that says who the
          // customer is. Read every time a page is told, not captured: the
          // customer may change segment while the mini app is open, and the
          // page hears the new one on its next load.
          hostContext: () => HostContext(
            locale: dependencies.locale,
            segment:
                remoteConfig.state.segmentId ?? HostContract.unknownSegment,
          ),
          policy: dependencies.policy,
          telemetry: dependencies.telemetry,
          surfaceFactory: dependencies.surfaceFactory,
          ensureClean: dependencies.data?.clearIfPending,
        );
        unawaited(cubit.start());
        return cubit;
      },
      child: MiniAppScreen(
        service: service,
        externalLinks: dependencies.externalLinks,
        onClose: close,
        onBackToServices: backToServices,
      ),
    );
  },
);

/// Shown for a mini app the customer cannot be offered. There is nothing to
/// retry: the way out is back to Servicios.
class _ServiceNotOffered extends StatelessWidget {
  const _ServiceNotOffered({
    required this.onClose,
    required this.onBackToServices,
  });

  final VoidCallback onClose;
  final VoidCallback onBackToServices;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: ServicesStrings.close,
          onPressed: onClose,
        ),
      ),
      body: MiniAppUnavailableView(onBackToServices: onBackToServices),
    );
  }
}
