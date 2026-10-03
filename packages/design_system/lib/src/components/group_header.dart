import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Small heading over a group of content: a day in a list of movements, or
/// the name of a figure such as "Saldo total".
///
/// It is drawn in capitals, but assistive technology reads the label as it
/// was written: capitals are spelled out letter by letter by some readers.
class GroupHeader extends StatelessWidget {
  const GroupHeader({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: label,
      child: ExcludeSemantics(
        child: Text(
          label.toUpperCase(),
          style: AppTypography.overline.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
