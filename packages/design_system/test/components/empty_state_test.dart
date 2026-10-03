import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('shows a title and a message without actions', (tester) async {
    await pumpApp(
      tester,
      const EmptyState(
        icon: Icons.notifications_none,
        title: 'Aún no tienes notificaciones',
        message: 'Aquí verás tus movimientos y alertas.',
      ),
    );

    expect(find.text('Aún no tienes notificaciones'), findsOneWidget);
    expect(find.text('Aquí verás tus movimientos y alertas.'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('offers a primary and a secondary action', (tester) async {
    final taps = <String>[];
    await pumpApp(
      tester,
      EmptyState(
        icon: Icons.cloud_off,
        title: 'No pudimos conectarnos',
        message: 'Lo intentamos 3 veces sin éxito.',
        primaryActionLabel: 'Reintentar',
        onPrimaryAction: () => taps.add('retry'),
        secondaryActionLabel: 'Ver datos guardados',
        onSecondaryAction: () => taps.add('cached'),
      ),
    );

    await tester.tap(find.text('Reintentar'));
    await tester.tap(find.text('Ver datos guardados'));

    expect(taps, ['retry', 'cached']);
    expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Ver datos guardados'),
      findsOneWidget,
    );
  });

  testWidgets('shows a footnote such as the retry count', (tester) async {
    await pumpApp(
      tester,
      const EmptyState(
        icon: Icons.cloud_off,
        title: 'No pudimos conectarnos',
        footnote: 'Intento 2 de 3',
      ),
    );

    expect(find.text('Intento 2 de 3'), findsOneWidget);
  });

  testWidgets('its title is a heading for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      const EmptyState(icon: Icons.cloud_off, title: 'No pudimos conectarnos'),
    );

    expect(
      tester.getSemantics(find.text('No pudimos conectarnos')),
      containsSemantics(isHeader: true),
    );
    handle.dispose();
  });
}
