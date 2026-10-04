import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('shows what it opens, one line about it and its badge', (
    tester,
  ) async {
    await pumpApp(
      tester,
      LinkCard(
        icon: Icons.shield_outlined,
        title: 'Seguro de viaje',
        description: 'Protección para tus planes',
        badge: 'Aliado',
        onTap: () {},
      ),
    );

    expect(find.text('Seguro de viaje'), findsOneWidget);
    expect(find.text('Protección para tus planes'), findsOneWidget);
    expect(find.text('Aliado'), findsOneWidget);
  });

  testWidgets('draws no badge when it has none', (tester) async {
    await pumpApp(
      tester,
      LinkCard(
        icon: Icons.swap_horiz,
        title: 'Transferencias',
        description: 'Mueve dinero entre tus cuentas',
        onTap: () {},
      ),
    );

    expect(find.byType(StatusChip), findsNothing);
  });

  testWidgets('opens when any part of it is tapped', (tester) async {
    var taps = 0;
    await pumpApp(
      tester,
      LinkCard(
        icon: Icons.shield_outlined,
        title: 'Seguro de viaje',
        description: 'Protección para tus planes',
        badge: 'Aliado',
        onTap: () => taps++,
      ),
    );

    await tester.tap(find.text('Protección para tus planes'));

    expect(taps, 1);
  });

  testWidgets('is read as one button that names the badge', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpApp(
      tester,
      LinkCard(
        icon: Icons.shield_outlined,
        title: 'Seguro de viaje',
        description: 'Protección para tus planes',
        badge: 'Aliado',
        onTap: () => taps++,
      ),
    );

    const label = 'Seguro de viaje, Protección para tus planes, Aliado';
    expect(
      tester.getSemantics(find.bySemanticsLabel(label)),
      matchesSemantics(label: label, isButton: true, hasTapAction: true),
    );

    tester.semantics.tap(find.semantics.byLabel(label));
    expect(taps, 1);
    handle.dispose();
  });
}
