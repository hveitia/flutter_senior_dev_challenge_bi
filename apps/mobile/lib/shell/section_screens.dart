import 'package:banca_digital/app_dependencies.dart';
import 'package:banca_digital/shell/diagnostics_card.dart';
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
  static const String servicesComing =
      'Pronto encontrarás aquí productos del banco y de nuestros aliados.';
  static const String signOut = 'Cerrar sesión';
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

/// Who is signed in, the state of the app and the way out. The rest of the
/// profile comes with its own stage.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.appInfo,
    this.now = DateTime.now,
    super.key,
  });

  final AppInfo appInfo;

  /// The current moment, for the diagnostics.
  final DateTime Function() now;

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
          DiagnosticsCard(appInfo: appInfo, now: now),
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
