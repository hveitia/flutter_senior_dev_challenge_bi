import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_auth/src/domain/auth_repository.dart';
import 'package:feature_auth/src/domain/biometric_authenticator.dart';
import 'package:feature_auth/src/presentation/login/login_cubit.dart';
import 'package:feature_auth/src/presentation/login/login_screen.dart';
import 'package:feature_auth/src/presentation/preferences/preferences_cubit.dart';
import 'package:feature_auth/src/presentation/preferences/preferences_screen.dart';
import 'package:feature_auth/src/presentation/session/session_bloc.dart';
import 'package:feature_auth/src/presentation/session/session_unavailable_screen.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_cubit.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_screen.dart';
import 'package:feature_auth/src/presentation/unlock/unlock_screen.dart';
import 'package:feature_auth/src/presentation/welcome/welcome_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Locations owned by the access feature.
abstract final class AuthPaths {
  static const String welcome = '/bienvenida';
  static const String login = '/ingresar';
  static const String signUp = '/registro';
  static const String completeProfile = '/completar-perfil';
  static const String unlock = '/desbloquear';
  static const String unavailable = '/sesion-no-disponible';

  /// Where a customer who is not signed in may be.
  static const Set<String> signedOut = {welcome, login, signUp};

  static const Set<String> all = {
    ...signedOut,
    completeProfile,
    unlock,
    unavailable,
  };
}

/// Locations of the signed-in customer's profile. They are not part of
/// [AuthPaths.all]: a signed-in customer belongs there.
abstract final class ProfilePaths {
  static const String preferences = '/personalizacion';
}

/// "Personalización" as a route, to mount among the screens of a signed-in
/// customer. It reads [AuthRepository], [SessionBloc] and
/// [ConnectivityCubit] from the tree and closes itself once the change is
/// stored.
GoRoute preferencesRoute() => GoRoute(
  path: ProfilePaths.preferences,
  builder: (context, state) {
    final session = context.read<SessionBloc>().state;
    // Only reachable signed in; anything else is about to be redirected.
    if (session is! SessionSignedIn) return const SizedBox.shrink();

    return BlocProvider(
      create: (context) => PreferencesCubit(
        repository: context.read<AuthRepository>(),
        segment: session.profile.segment,
        interests: session.profile.interests,
      ),
      child: PreferencesScreen(onSaved: () => context.pop()),
    );
  },
);

/// Where the session sends the customer, or null when [location] is already
/// a place they may be.
///
/// [splash] and [home] belong to the app: the first is shown while the
/// session is unknown, the second is where a signed-in customer lands.
String? authRedirect(
  SessionState session, {
  required String location,
  required String splash,
  required String home,
}) {
  String? goTo(String target) => location == target ? null : target;

  return switch (session) {
    SessionStarting() => goTo(splash),
    SessionSignedOut() =>
      AuthPaths.signedOut.contains(location) ? null : AuthPaths.welcome,
    SessionProfilePending() => goTo(AuthPaths.completeProfile),
    SessionLocked() => goTo(AuthPaths.unlock),
    SessionUnavailable() => goTo(AuthPaths.unavailable),
    SessionSignedIn() =>
      AuthPaths.all.contains(location) || location == splash ? home : null,
  };
}

/// The access screens as routes.
///
/// They read [AuthRepository], [BiometricAuthenticator], [Telemetry],
/// [SessionBloc] and [ConnectivityCubit] from the widget tree, which the
/// composition root provides above the router.
List<RouteBase> authRoutes() => [
  GoRoute(
    path: AuthPaths.welcome,
    builder: (context, state) => WelcomeScreen(
      onOpenAccount: () => context.push(AuthPaths.signUp),
      onSignIn: () => context.push(AuthPaths.login),
    ),
  ),
  GoRoute(
    path: AuthPaths.login,
    builder: (context, state) => BlocProvider(
      create: (context) => LoginCubit(repository: context.read()),
      child: LoginScreen(
        onOpenAccount: () => context.pushReplacement(AuthPaths.signUp),
      ),
    ),
  ),
  GoRoute(
    path: AuthPaths.signUp,
    builder: (context, state) => BlocProvider(
      create: (context) {
        final cubit = SignUpCubit.newAccount(
          repository: context.read(),
          biometrics: context.read(),
          telemetry: context.read(),
        );
        unawaited(cubit.start());
        return cubit;
      },
      child: SignUpScreen(
        onLeave: () =>
            context.canPop() ? context.pop() : context.go(AuthPaths.welcome),
      ),
    ),
  ),
  GoRoute(
    path: AuthPaths.completeProfile,
    builder: (context, state) {
      final session = context.read<SessionBloc>().state;
      final pending = session is SessionProfilePending ? session : null;
      return BlocProvider(
        create: (context) => SignUpCubit.completeProfile(
          repository: context.read(),
          email: pending?.email ?? '',
          unsavedDraft: pending?.unsavedDraft,
          telemetry: context.read(),
        ),
        child: SignUpScreen(
          onSignOut: () => context.read<SessionBloc>().add(
            const SessionSignOutRequested(),
          ),
        ),
      );
    },
  ),
  GoRoute(
    path: AuthPaths.unlock,
    builder: (context, state) => const UnlockScreen(),
  ),
  GoRoute(
    path: AuthPaths.unavailable,
    builder: (context, state) => const SessionUnavailableScreen(),
  ),
];
