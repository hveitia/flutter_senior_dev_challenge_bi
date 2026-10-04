/// Onboarding, sign-in and session.
///
/// The app mounts `authRoutes`, drives its router with `authRedirect` and
/// provides a `SessionBloc` built on an `AuthRepository`. Firebase and device
/// plugins are reached only through `package:feature_auth/adapters.dart`,
/// which the composition root wires.
library;

export 'src/auth_telemetry.dart';
export 'src/domain/auth_repository.dart';
export 'src/domain/auth_result.dart';
export 'src/domain/biometric_authenticator.dart';
export 'src/domain/session.dart';
export 'src/domain/user_profile.dart';
export 'src/presentation/auth_routes.dart';
export 'src/presentation/preferences/segment_label.dart';
export 'src/presentation/session/session_bloc.dart';
