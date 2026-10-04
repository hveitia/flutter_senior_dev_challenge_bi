import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app_dependencies.dart';
import 'package:banca_digital/notifications_wiring.dart';
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

  static const String signOut = 'Cerrar sesión';
  static const String unsentTransfersTitle = 'Tienes transferencias sin enviar';

  /// What ending the session does to the queued transfers. It tells apart
  /// the ones that exist only on this phone, which are lost with the
  /// session, from the ones the bank already has, which nothing on this
  /// phone can stop.
  static String unsentTransfersMessage({
    required int onDeviceOnly,
    required int delivered,
  }) {
    final discarded = switch (onDeviceOnly) {
      <= 0 => null,
      1 =>
        'Tienes 1 transferencia que solo existe en este teléfono. Si '
            'cierras sesión ahora, se descarta y no se enviará.',
      _ =>
        'Tienes $onDeviceOnly transferencias que solo existen en este '
            'teléfono. Si cierras sesión ahora, se descartan y no se '
            'enviarán.',
    };
    final carriedOut = switch (delivered) {
      <= 0 => null,
      // The server settles an order when the app asks, so it happens the
      // next time this customer signs in: promising "now" would be untrue.
      1 =>
        'El banco ya recibió 1 transferencia. No se descarta: se '
            'completará cuando vuelvas a iniciar sesión.',
      _ =>
        'El banco ya recibió $delivered transferencias. No se descartan: '
            'se completarán cuando vuelvas a iniciar sesión.',
    };
    return [?discarded, ?carriedOut].join('\n\n');
  }

  static const String staySignedIn = 'Seguir aquí';
  static const String signOutAndDiscard = 'Cerrar sesión y descartar';
  static const String personalization = 'Personalización';
  static const String interests = 'Mis intereses';
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
  /// The device is forgotten before the session closes too: removing its
  /// registration needs the session, and a device left registered would keep
  /// receiving the customer's notifications after they signed out.
  ///
  /// Closing the session wipes what the device saved, and that includes
  /// transfers queued without a connection that have not left the phone:
  /// they would never be sent. One the bank already has is a different
  /// matter: no client can take it back, so the dialog says it will be
  /// carried out and does not offer to discard it. While there are any of
  /// either kind, the session stays open unless the customer confirms.
  static Future<void> _signOut(BuildContext context) async {
    final outbox = context.read<TransferOutboxCubit>().state;
    if (outbox.hasUnsent) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(ShellStrings.unsentTransfersTitle),
          content: Text(
            ShellStrings.unsentTransfersMessage(
              onDeviceOnly: outbox.onDeviceOnlyCount,
              delivered: outbox.deliveredCount,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                outbox.onDeviceOnlyCount > 0
                    ? ShellStrings.signOutAndDiscard
                    : ShellStrings.signOut,
              ),
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
    final session = context.read<SessionBloc>();
    unawaited(
      closeSessionAfter(
        () => forgetDevice(context),
        () => session.add(const SessionSignOutRequested()),
      ),
    );
  }
}

/// Runs [cleanUp] and then [closeSession], whatever became of the clean-up.
///
/// A customer who asked to leave must leave: a clean-up that fails, even
/// before it returns a future, cannot keep the session open.
@visibleForTesting
Future<void> closeSessionAfter(
  Future<void> Function() cleanUp,
  void Function() closeSession,
) async {
  try {
    await cleanUp();
  } on Object {
    // Whoever cleans up reports its own failures; here only the order
    // matters.
  }
  closeSession();
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
