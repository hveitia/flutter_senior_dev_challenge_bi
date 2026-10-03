import 'package:design_system/design_system.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where a signed-in customer lands until the home is built.
///
/// It proves the session works end to end: it greets the customer by the
/// name stored in their profile and lets them sign out.
class SignedInPlaceholderScreen extends StatelessWidget {
  const SignedInPlaceholderScreen({super.key});

  static const String body = 'Tu sesión está activa.';
  static const String signOut = 'Cerrar sesión';

  static String greeting(String firstName) => 'Hola, $firstName';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<SessionBloc>().state;
    if (session is! SessionSignedIn) return const Scaffold();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.metrics.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                header: true,
                child: Text(
                  greeting(session.profile.firstName),
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                body,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.x6),
              AppButton(
                label: signOut,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.read<SessionBloc>().add(
                  const SessionSignOutRequested(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
