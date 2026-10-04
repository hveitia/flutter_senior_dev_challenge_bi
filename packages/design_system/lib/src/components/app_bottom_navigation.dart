import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// One destination of an [AppBottomNavigation].
@immutable
class AppBottomNavigationItem {
  const AppBottomNavigationItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The main sections of the app, always within reach at the bottom.
///
/// The current destination is marked with a bar above it and a heavier
/// label, not only with color.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  /// Identifies the bar over the current destination.
  static const Key indicatorKey = ValueKey('bottom-navigation-indicator');

  static const double _indicatorWidth = 28;
  static const double _indicatorHeight = 3;

  final List<AppBottomNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.bottomNavigation,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, item) in items.indexed)
                Expanded(
                  child: _Destination(
                    item: item,
                    selected: index == currentIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? colors.link : scheme.onSurface;
    final labelStyle = selected
        ? AppTypography.captionStrong
        : AppTypography.caption;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      // The item below is excluded so icon and label are read as one; the
      // action has to be offered here or a screen reader could not use it.
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.bottomNavigation,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: AppBottomNavigation._indicatorHeight,
                  width: AppBottomNavigation._indicatorWidth,
                  child: selected
                      ? ColoredBox(
                          key: AppBottomNavigation.indicatorKey,
                          color: colors.brandFill,
                        )
                      : null,
                ),
                const SizedBox(height: AppSpacing.x4),
                Icon(item.icon, size: AppSizes.icon, color: foreground),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: labelStyle.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
