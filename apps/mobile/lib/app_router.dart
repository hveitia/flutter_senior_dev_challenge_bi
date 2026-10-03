import 'dart:async';

import 'package:banca_digital/signed_in_placeholder_screen.dart';
import 'package:banca_digital/splash_screen.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Locations owned by the app itself. Each feature owns its own.
abstract final class AppPaths {
  /// Shown while the session is unknown.
  static const String splash = '/';

  /// Where a signed-in customer lands.
  static const String home = '/inicio';
}

/// The app's router: every feature's routes, with the session deciding which
/// of them the customer may see.
GoRouter createAppRouter({
  required SessionBloc session,
  required String productName,
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
      GoRoute(
        path: AppPaths.home,
        builder: (context, state) => const SignedInPlaceholderScreen(),
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
