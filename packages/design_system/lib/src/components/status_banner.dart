import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_tone.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';

/// Connectivity situations the app tells the customer about.
enum StatusBannerKind {
  /// No connection: the screen shows the last data it saved.
  offline(
    'Sin conexión. Mostrando datos guardados',
    Icons.wifi_off,
    AppTone.warning,
  ),

  /// Requests are taking long: the app is still retrying.
  slow(
    'Conexión lenta. Seguimos intentando',
    Icons.schedule,
    AppTone.warning,
  ),

  /// Connection is back and data was refreshed.
  restored(
    'Conexión restablecida. Datos actualizados',
    Icons.check_circle_outline,
    AppTone.success,
  )
  ;

  const StatusBannerKind(this.defaultMessage, this.icon, this.tone);

  final String defaultMessage;
  final IconData icon;
  final AppTone tone;
}

/// Full-width strip under the header that explains a degraded state.
///
/// It is a live region: screen readers announce it when it appears, since a
/// customer who cannot see it would otherwise not know the data is stale.
class StatusBanner extends StatelessWidget {
  const StatusBanner({required this.kind, this.message, super.key});

  final StatusBannerKind kind;

  /// Overrides the default message of the [kind].
  final String? message;

  static const double _lineHeight = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = colors.foreground(kind.tone);
    final tint = colors.tint(kind.tone);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kind == StatusBannerKind.slow)
            ExcludeSemantics(
              child: reduceMotion
                  ? ColoredBox(
                      color: foreground,
                      child: const SizedBox(height: _lineHeight),
                    )
                  : LinearProgressIndicator(
                      minHeight: _lineHeight,
                      color: foreground,
                      backgroundColor: tint,
                    ),
            ),
          ColoredBox(
            color: tint,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.metrics.screenMargin,
                vertical: AppSpacing.x3,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(kind.icon, size: 20, color: foreground),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      message ?? kind.defaultMessage,
                      style: AppTypography.body.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
