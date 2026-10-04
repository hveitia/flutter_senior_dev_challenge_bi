import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:module_kit/module_kit.dart';

/// Home module: shortcuts published for the customer's segment.
///
/// Each action names a destination. An action the app cannot open, because
/// it has no screen for it yet or its feature is switched off, is left out,
/// and the module draws nothing when none is left.
class QuickActionsModule extends StatelessWidget {
  const QuickActionsModule({required this.module, super.key});

  static const String actionsProp = 'actions';
  static const String labelKey = 'label';
  static const String iconKey = 'icon';
  static const String destinationKey = 'destination';

  /// The most shortcuts drawn in the row. The design has four; more would
  /// not fit a small phone with large text.
  static const int maxActions = 4;

  final HomeModuleContext module;

  /// Icons by the name the configuration uses. A name this version does not
  /// know gets [_fallbackIcon]: the shortcut still works.
  static const Map<String, IconData> _icons = {
    'transfer': Icons.swap_horiz,
    'pay': Icons.receipt_long_outlined,
    'phone': Icons.smartphone_outlined,
    'chart': Icons.show_chart,
    'more': Icons.more_horiz,
  };
  static const IconData _fallbackIcon = Icons.arrow_forward;

  List<_QuickAction> _actions() {
    final actions = <_QuickAction>[];
    for (final published in module.objects(actionsProp)) {
      final label = HomeModuleContext.textIn(published, labelKey);
      final destination = HomeModuleContext.textIn(published, destinationKey);
      if (label == null || destination == null) continue;

      final open = module.destinations.resolve(destination);
      if (open == null) continue;

      actions.add(
        _QuickAction(
          label: label,
          icon: _icons[published[iconKey]] ?? _fallbackIcon,
          open: open,
        ),
      );
      if (actions.length == maxActions) break;
    }
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions();
    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final action in actions)
          Expanded(child: _QuickActionTile(action: action)),
      ],
    );
  }
}

@immutable
class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.open,
  });

  final String label;
  final IconData icon;
  final DestinationOpener open;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(context.metrics.inputRadius);

    return Semantics(
      button: true,
      label: action.label,
      // The tile below is excluded so icon and label are read as one
      // button; the action has to be offered here or it could not be
      // activated with a screen reader.
      onTap: () => action.open(context),
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: radius,
          onTap: () => action.open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: radius,
                    border: Border.all(color: colors.line),
                  ),
                  child: SizedBox.square(
                    dimension: AppSizes.touchTarget,
                    child: Icon(
                      action.icon,
                      size: AppSizes.icon,
                      color: colors.icon,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
