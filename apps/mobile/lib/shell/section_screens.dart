import 'package:design_system/design_system.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the sections owned by the app itself say to the customer.
abstract final class ShellStrings {
  static const String home = 'Inicio';
  static const String accounts = 'Cuentas';
  static const String services = 'Servicios';
  static const String profile = 'Perfil';

  static const String underConstruction = 'Estamos construyendo esta sección';
  static const String homeComing =
      'Pronto verás aquí un resumen hecho a tu medida. Mientras tanto, tus '
      'cuentas están en la sección Cuentas.';
  static const String servicesComing =
      'Pronto encontrarás aquí productos del banco y de nuestros aliados.';
  static const String signOut = 'Cerrar sesión';

  static String greeting(String firstName) => 'Hola, $firstName';
}

/// The root of a section that is not built yet. It says so plainly instead
/// of showing invented content.
class SectionPlaceholderScreen extends StatelessWidget {
  const SectionPlaceholderScreen({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TabRootAppBar(title: title),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.metrics.screenMargin),
          child: EmptyState(
            icon: icon,
            title: ShellStrings.underConstruction,
            message: message,
          ),
        ),
      ),
    );
  }
}

/// Where a signed-in customer lands until the home is built: it greets
/// them by name and points at what already works.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionBloc>().state;
    final firstName = session is SessionSignedIn
        ? session.profile.firstName
        : '';

    return SectionPlaceholderScreen(
      title: ShellStrings.greeting(firstName),
      message: ShellStrings.homeComing,
      icon: Icons.home_outlined,
    );
  }
}

/// Who is signed in, and the way out. The rest of the profile comes with
/// its own stage.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionBloc>().state;
    if (session is! SessionSignedIn) return const Scaffold();

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const TabRootAppBar(title: ShellStrings.profile),
      body: ListView(
        padding: EdgeInsets.all(context.metrics.screenMargin),
        children: [
          Text(
            session.profile.fullName,
            style: AppTypography.subtitle.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            session.profile.email,
            style: AppTypography.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          SizedBox(height: context.metrics.moduleGap),
          AppButton(
            label: ShellStrings.signOut,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.read<SessionBloc>().add(
              const SessionSignOutRequested(),
            ),
          ),
        ],
      ),
    );
  }
}
