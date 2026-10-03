import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_radii.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// The product name followed by the brand mark.
class Wordmark extends StatelessWidget {
  const Wordmark({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            style: AppTypography.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x2),
        // Decorative: the name already says what it is.
        ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.brandFill,
              borderRadius: BorderRadius.circular(AppRadii.partner),
            ),
            child: const SizedBox(width: AppSpacing.x2, height: AppSizes.icon),
          ),
        ),
      ],
    );
  }
}
