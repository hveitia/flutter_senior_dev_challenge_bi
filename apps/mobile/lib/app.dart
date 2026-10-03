import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Root widget of the mobile app.
///
/// For now it only renders the splash. Routing and dependency wiring are
/// added here as each domain package lands.
class BancaDigitalApp extends StatelessWidget {
  const BancaDigitalApp({super.key});

  static const String productName = 'Banca Digital';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: productName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _SplashScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

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
            Text(
              BancaDigitalApp.productName,
              style: theme.textTheme.headlineMedium,
            ),
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
