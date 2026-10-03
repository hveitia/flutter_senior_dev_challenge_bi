import 'package:design_system/src/components/app_button.dart';
import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Frame shared by every module of the home screen: a heading, an optional
/// action, the module's own content and an optional footnote.
///
/// Modules come from different domain packages; this keeps them aligned
/// without any of them knowing about the others.
class ModuleContainer extends StatelessWidget {
  const ModuleContainer({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.footnote,
    super.key,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Small print under the content, for example "Actualizado hace 8 min".
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppTypography.subtitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              AppButton(
                label: actionLabel!,
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: onAction,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        child,
        if (footnote != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            footnote!,
            style: AppTypography.caption.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
