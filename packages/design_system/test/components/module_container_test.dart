import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('renders its title above its content', (tester) async {
    await pumpApp(
      tester,
      const ModuleContainer(
        title: 'Últimos movimientos',
        child: Text('contenido'),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Últimos movimientos')).dy,
      lessThan(tester.getTopLeft(find.text('contenido')).dy),
    );
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('offers an optional action next to the title', (tester) async {
    var taps = 0;
    await pumpApp(
      tester,
      ModuleContainer(
        title: 'Últimos movimientos',
        actionLabel: 'Ver todos',
        onAction: () => taps++,
        child: const Text('contenido'),
      ),
    );

    await tester.tap(find.text('Ver todos'));

    expect(taps, 1);
  });

  testWidgets('shows a footnote such as the last sync time', (tester) async {
    await pumpApp(
      tester,
      const ModuleContainer(
        title: 'Últimos movimientos',
        footnote: 'Actualizado hace 8 min',
        child: Text('contenido'),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Actualizado hace 8 min')).dy,
      greaterThan(tester.getTopLeft(find.text('contenido')).dy),
    );
  });

  testWidgets('its title is a heading for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      const ModuleContainer(title: 'Para ti', child: Text('contenido')),
    );

    expect(
      tester.getSemantics(find.text('Para ti')),
      containsSemantics(isHeader: true),
    );
    handle.dispose();
  });
}
