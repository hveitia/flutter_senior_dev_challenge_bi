import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Header of a screen that is the root of a bottom navigation section.
///
/// Every section opens with the same header: its name as a large title and
/// no way back, because there is nothing above a section.
class TabRootAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabRootAppBar({required this.title, this.actions, super.key});

  final String title;
  final List<Widget>? actions;

  static const double _height = 64;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: _height,
      titleSpacing: context.metrics.screenMargin,
      title: Text(
        title,
        style: AppTypography.title.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      actions: actions,
    );
  }
}
