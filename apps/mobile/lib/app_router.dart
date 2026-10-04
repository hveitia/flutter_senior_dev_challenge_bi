import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app_dependencies.dart';
import 'package:banca_digital/notifications_wiring.dart';
import 'package:banca_digital/services_wiring.dart';
import 'package:banca_digital/shell/app_shell.dart';
import 'package:banca_digital/shell/customer_scope.dart';
import 'package:banca_digital/shell/section_screens.dart';
import 'package:banca_digital/splash_screen.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_home/feature_home.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_services/feature_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:module_kit/module_kit.dart';

/// Locations owned by the app itself. Each feature owns its own.
abstract final class AppPaths {
  /// Shown while the session is unknown.
  static const String splash = '/';

  /// Where a signed-in customer lands.
  static const String home = '/inicio';
  static const String services = '/servicios';
  static const String profile = '/perfil';
}

/// The sections of the bottom navigation, in order.
const List<AppSection> appSections = [
  AppSection(
    path: AppPaths.home,
    label: ShellStrings.home,
    icon: Icons.home_outlined,
  ),
  AppSection(
    path: AccountsPaths.accounts,
    label: ShellStrings.accounts,
    icon: Icons.account_balance_wallet_outlined,
  ),
  AppSection(
    path: AppPaths.services,
    label: ShellStrings.services,
    icon: Icons.grid_view,
  ),
  AppSection(
    path: AppPaths.profile,
    label: ShellStrings.profile,
    icon: Icons.person_outline,
  ),
];

/// The app's router: every feature's routes, with the session deciding which
/// of them the customer may see.
///
/// Everything that needs a signed-in customer hangs from one scope that
/// provides their data. Inside it, the roots of the four sections share the
/// bottom navigation, and screens opened from them cover it.
GoRouter createAppRouter({
  required SessionBloc session,
  required String productName,
  required AppDependencies dependencies,
}) {
  final refresh = _StreamListenable(session.stream);

  return GoRouter(
    initialLocation: AppPaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      session.state,
      location: state.matchedLocation,
      splash: AppPaths.splash,
      home: AppPaths.home,
    ),
    routes: [
      GoRoute(
        path: AppPaths.splash,
        builder: (context, state) => SplashScreen(productName: productName),
      ),
      ...authRoutes(),
      ShellRoute(
        builder: (context, state, child) => CustomerScope(
          accountsRepositoryFor: dependencies.accountsRepositoryFor,
          transfersRepositoryFor: dependencies.transfersRepositoryFor,
          configRepository: dependencies.configRepository,
          publishedFaults: dependencies.publishedFaults,
          child: CustomerNotifications(
            dependencies: dependencies.notifications,
            child: child,
          ),
        ),
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(
              sections: appSections,
              location: state.uri.path,
              onSectionSelected: (section) => context.go(section.path),
              child: child,
            ),
            routes: [
              GoRoute(
                path: AppPaths.home,
                builder: (context, state) => _home(
                  context,
                  productName: productName,
                  registry: dependencies.homeModules,
                  services: dependencies.services,
                ),
              ),
              accountsTabRoute(
                // --- transfers (stage 8) ---
                notices: const [QueuedTransfersNotice(), ProvisioningNotice()],
              ),
              servicesTabRoute(
                path: AppPaths.services,
                catalog: dependencies.services.catalog,
                destinations: (context) =>
                    appDestinations(context, dependencies.services),
              ),
              GoRoute(
                path: AppPaths.profile,
                builder: (context, state) =>
                    ProfileScreen(appInfo: dependencies.appInfo),
              ),
            ],
          ),
          // --- transfers (stage 8) ---
          accountDetailRoute(
            // Offered only while the published configuration has transfers
            // on for the customer's segment; watched, so it follows live.
            canTransfer: (context) =>
                context
                    .watch<RemoteConfigCubit>()
                    .state
                    .segment
                    ?.features
                    .transfers ??
                false,
          ),
          transferRoute(onDone: (context) => context.go(AppPaths.home)),
          preferencesRoute(),
          ...notificationsRoutes(destinations: destinationsFor),
          miniAppRoute(dependencies.services, servicesPath: AppPaths.services),
        ],
      ),
    ],
  );
}

/// The home of the signed-in customer: drawn from the published
/// configuration, with the modules every domain registered. Its actions
/// lead only where this build has a screen and the customer's feature
/// flags allow.
Widget _home(
  BuildContext context, {
  required String productName,
  required HomeModuleRegistry registry,
  required ServicesDependencies services,
}) {
  final session = context.watch<SessionBloc>().state;
  final profile = session is SessionSignedIn ? session.profile : null;

  return HomeScreen(
    registry: registry,
    destinations: appDestinations(context, services),
    productName: productName,
    firstName: profile?.firstName ?? '',
    fullName: profile?.fullName ?? '',
    headerAction: NotificationsBell(onOpen: () => openInbox(context)),
  );
}

/// Makes the router re-run its redirect on every event of a stream.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
