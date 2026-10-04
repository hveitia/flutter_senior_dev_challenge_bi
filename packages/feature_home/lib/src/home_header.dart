import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// The top of the home: the avatar with the customer's initials, the name
/// of the product and the greeting.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.productName,
    required this.greeting,
    required this.initials,
    this.action,
    super.key,
  });

  final String productName;
  final String greeting;
  final String initials;

  /// Drawn at the end of the header, after the greeting. Whoever mounts the
  /// home decides what it is.
  final Widget? action;

  static const double _avatar = 40;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.metrics.screenMargin,
            vertical: AppSpacing.x3,
          ),
          child: Row(
            children: [
              if (initials.isNotEmpty) ...[
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceInset,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: _avatar,
                      child: Center(
                        child: Text(
                          initials,
                          style: AppTypography.captionStrong.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      productName,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        greeting,
                        style: AppTypography.subtitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (action case final action?) ...[
                const SizedBox(width: AppSpacing.x2),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
