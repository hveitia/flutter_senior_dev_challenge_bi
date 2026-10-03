import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('shows a label and its value', (tester) async {
    await pumpApp(
      tester,
      const DetailRow(label: 'Canal', value: 'Tarjeta de débito'),
    );

    expect(find.text('Canal'), findsOneWidget);
    expect(find.text('Tarjeta de débito'), findsOneWidget);
  });

  testWidgets('is read as one phrase', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      const DetailRow(label: 'Canal', value: 'Tarjeta de débito'),
    );

    expect(find.bySemanticsLabel('Canal: Tarjeta de débito'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('keeps a trailing action as its own control', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpApp(
      tester,
      DetailRow(
        label: 'Referencia',
        value: 'MOV-202610-0002',
        trailing: IconButton(
          tooltip: 'Copiar referencia',
          icon: const Icon(Icons.copy_outlined),
          onPressed: () => taps++,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Copiar referencia'));

    expect(taps, 1);
    expect(
      find.bySemanticsLabel('Referencia: MOV-202610-0002'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
