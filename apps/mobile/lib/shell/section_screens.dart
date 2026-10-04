import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app_dependencies.dart';
import 'package:banca_digital/shell/diagnostics_card.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
  static const String unsentTransfersTitle = 'Tienes transferencias sin enviar';
  static const String unsentTransfersMessage =
      'Están en cola hasta que recuperes la conexión. Si cierras sesión '
      'ahora, se descartan y no se enviarán.';
  static const String staySignedIn = 'Seguir aquí';
  static const String signOutAndDiscard = 'Cerrar sesión y descartar';
  static const String personalization = 'Personalización';
  static const String interests = 'Mis intereses';
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
      // A handful of sections: all of them are built, so whatever is below
      // the fold can be scrolled to and reached by a screen reader.
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.metrics.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: AppSpacing.x2),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusChip(
                label: segmentLabel(session.profile.segment),
                icon: Icons.person_outline,
                tone: AppTone.info,
              ),
            ),
            SizedBox(height: context.metrics.moduleGap),
            ModuleContainer(
              title: ShellStrings.personalization,
              child: _ProfileLink(
                label: ShellStrings.interests,
                onTap: () => unawaited(context.push(ProfilePaths.preferences)),
              ),
            ),
            SizedBox(height: context.metrics.moduleGap),
            DiagnosticsCard(appInfo: appInfo, now: now),
            SizedBox(height: context.metrics.moduleGap),
            AppButton(
              label: ShellStrings.signOut,
              variant: AppButtonVariant.secondary,
              onPressed: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Stops reading the published configuration, then closes the session.
  ///
  /// The order matters: the document can only be read with a session, so a
  /// listener still running when the session closes would see the read
  /// refused and report a failure that is only a sign-out.
  ///
  /// Asking the listener to stop is enough, without waiting for it to
  /// finish: from that call on it delivers nothing, errors included.
  ///
  /// Closing the session wipes what the device saved, and that includes
  /// transfers queued without a connection: they would never be sent. So
  /// while there are any, the session stays open unless the customer says
  /// in so many words that they are to be discarded.
  static Future<void> _signOut(BuildContext context) async {
    if (context.read<TransferOutboxCubit>().state.hasUnsent) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(ShellStrings.unsentTransfersTitle),
          content: const Text(ShellStrings.unsentTransfersMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(ShellStrings.signOutAndDiscard),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(ShellStrings.staySignedIn),
            ),
          ],
        ),
      );
      if (discard != true || !context.mounted) return;
    }
    unawaited(context.read<RemoteConfigCubit>().stop());
    context.read<SessionBloc>().add(const SessionSignOutRequested());
  }
}

/// A row of the profile that opens another screen.
class _ProfileLink extends StatelessWidget {
  const _ProfileLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.metrics.inputRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right,
                  size: AppSizes.icon,
                  color: context.colors.icon,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
