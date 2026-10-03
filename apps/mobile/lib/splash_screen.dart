import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Shown while the app finds out who is signed in.
class SplashScreen extends StatelessWidget {
  const SplashScreen({required this.productName, super.key});

  final String productName;

  static const double _lineWidth = 120;
  static const double _lineHeight = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(productName, style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.componentGap),
            SizedBox(
              width: _lineWidth,
              child: LinearProgressIndicator(
                minHeight: _lineHeight,
                color: context.colors.brandFill,
                backgroundColor: context.colors.surfaceInset,
                semanticsLabel: 'Cargando',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
