import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  // Built from code points so the invisible no-break space stays visible in
  // this file.
  final minus = String.fromCharCode(0x2212);
  final noBreakSpace = String.fromCharCode(0xA0);

  Future<void> pumpRow(
    WidgetTester tester, {
    int amountCents = -6480,
    void Function()? onTap,
  }) {
    return pumpApp(
      tester,
      MovementRow(
        icon: Icons.storefront_outlined,
        description: 'Supermercado',
        detail: 'Hoy · 08:45',
        amountCents: amountCents,
        onTap: onTap,
      ),
    );
  }

  testWidgets('shows what the movement was, when, and its signed amount', (
    tester,
  ) async {
    await pumpRow(tester);

    expect(find.text('Supermercado'), findsOneWidget);
    expect(find.text('Hoy · 08:45'), findsOneWidget);
    expect(
      find.text('$minus$noBreakSpace\$64.80', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('marks income with an arrow as well as the plus sign', (
    tester,
  ) async {
    await pumpRow(tester, amountCents: 185000);

    expect(
      find.text('+$noBreakSpace\$1,850.00', findRichText: true),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.south_east), findsOneWidget);
  });

  testWidgets('opens the movement when tapped', (tester) async {
    var taps = 0;
    await pumpRow(tester, onTap: () => taps++);

    await tester.tap(find.byType(MovementRow));

    expect(taps, 1);
  });

  testWidgets('is a button only when it can be opened', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRow(tester, onTap: () {});
    expect(
      tester.getSemantics(find.byType(MovementRow)),
      containsSemantics(isButton: true),
    );

    await pumpRow(tester);
    expect(
      tester.getSemantics(find.byType(MovementRow)),
      isNot(containsSemantics(isButton: true)),
    );
    handle.dispose();
  });
}
