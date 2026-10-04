import 'dart:async';

import 'package:banca_digital/shell/app_shell.dart';
import 'package:banca_digital/shell/customer_scope.dart';
import 'package:banca_digital/shell/section_screens.dart';
import 'package:banca_digital/splash_screen.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  required AccountsRepository Function(String uid) accountsRepositoryFor,
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
          accountsRepositoryFor: accountsRepositoryFor,
          child: child,
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
                builder: (context, state) => const HomePlaceholderScreen(),
              ),
              accountsTabRoute(),
              GoRoute(
                path: AppPaths.services,
                builder: (context, state) => const SectionPlaceholderScreen(
                  title: ShellStrings.services,
                  message: ShellStrings.servicesComing,
                  icon: Icons.grid_view,
                ),
              ),
              GoRoute(
                path: AppPaths.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          accountDetailRoute(),
        ],
      ),
    ],
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
