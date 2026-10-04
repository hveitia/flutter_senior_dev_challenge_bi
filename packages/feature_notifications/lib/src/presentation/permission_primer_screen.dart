import 'package:design_system/design_system.dart';
import 'package:feature_notifications/src/presentation/notifications_strings.dart';
import 'package:feature_notifications/src/presentation/permission_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The app's own invitation to turn notifications on, shown before the
/// system prompt: it says what they are for and lets the customer decline
/// without spending the one prompt the system allows.
class PermissionPrimerScreen extends StatefulWidget {
  const PermissionPrimerScreen({required this.onDone, super.key});

  /// Closes the invitation once the customer has answered.
  final VoidCallback onDone;

  @override
  State<PermissionPrimerScreen> createState() => _PermissionPrimerScreenState();
}

class _PermissionPrimerScreenState extends State<PermissionPrimerScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PermissionCubit>().primerShown();
  }

  Future<void> _accept() async {
    await context.read<PermissionCubit>().accept();
    if (mounted) widget.onDone();
  }

  Future<void> _decline() async {
    await context.read<PermissionCubit>().decline();
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final isAsking = context.watch<PermissionCubit>().state.isAsking;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.metrics.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.x8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.notifications_none,
                    size: AppSizes.icon,
                    color: colors.icon,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x6),
              Semantics(
                header: true,
                child: Text(
                  NotificationsStrings.primerTitle,
                  style: AppTypography.title.copyWith(color: scheme.onSurface),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              Text(
                NotificationsStrings.primerMessage,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x6),
              const _Reason(
                icon: Icons.swap_horiz,
                label: NotificationsStrings.primerMovements,
              ),
              const _Reason(
                icon: Icons.verified_user_outlined,
                label: NotificationsStrings.primerSecurity,
              ),
              const _Reason(
                icon: Icons.card_giftcard,
                label: NotificationsStrings.primerBenefits,
              ),
              const SizedBox(height: AppSpacing.x4),
              Text(
                NotificationsStrings.primerFootnote,
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              AppButton(
                label: NotificationsStrings.primerAccept,
                isLoading: isAsking,
                onPressed: _accept,
              ),
              const SizedBox(height: AppSpacing.x2),
              AppButton(
                label: NotificationsStrings.primerDecline,
                variant: AppButtonVariant.text,
                onPressed: isAsking ? null : _decline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One thing the notifications are for.
class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: AppSizes.icon, color: context.colors.link),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
