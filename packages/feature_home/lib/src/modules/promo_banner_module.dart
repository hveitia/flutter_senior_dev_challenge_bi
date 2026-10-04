import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:module_kit/module_kit.dart';

/// Home module: a message published for the customer's segment, with an
/// optional action.
///
/// Its text comes entirely from the configuration. Without a title there is
/// nothing to say and it draws nothing; an action the app cannot open is
/// left out and the message stays.
class PromoBannerModule extends StatelessWidget {
  const PromoBannerModule({required this.module, super.key});

  static const String titleProp = 'title';
  static const String bodyProp = 'body';
  static const String actionProp = 'action';
  static const String labelKey = 'label';
  static const String destinationKey = 'destination';

  final HomeModuleContext module;

  @override
  Widget build(BuildContext context) {
    final title = module.text(titleProp);
    if (title == null) return HomeModuleBinding.hidden(module: module);

    final body = module.text(bodyProp);
    final action = _action();
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.brandTint,
        borderRadius: BorderRadius.circular(context.metrics.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: AppTypography.subtitle.copyWith(color: scheme.onSurface),
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.x1),
              Text(
                body,
                style: AppTypography.body.copyWith(color: scheme.onSurface),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.x2),
              AppButton(
                label: action.label,
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: () => action.open(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ({String label, DestinationOpener open})? _action() {
    final published = module.object(actionProp);
    if (published == null) return null;

    final label = HomeModuleContext.textIn(published, labelKey);
    final destination = HomeModuleContext.textIn(published, destinationKey);
    if (label == null || destination == null) return null;

    final open = module.destinations.resolve(destination);
    return open == null ? null : (label: label, open: open);
  }
}
