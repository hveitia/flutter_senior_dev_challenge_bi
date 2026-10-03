import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  List<Color> barColors(WidgetTester tester) => [
    for (final box in tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(StepIndicator),
        matching: find.byType(DecoratedBox),
      ),
    ))
      (box.decoration as BoxDecoration).color!,
  ];

  testWidgets('says which step of how many', (tester) async {
    await pumpApp(tester, const StepIndicator(current: 2, total: 3));

    expect(find.text('Paso 2 de 3'), findsOneWidget);
  });

  testWidgets('fills one bar per step up to the current one', (tester) async {
    await pumpApp(tester, const StepIndicator(current: 2, total: 3));

    expect(barColors(tester), [
      AppColors.brand500,
      AppColors.brand500,
      AppColors.line,
    ]);
  });

  testWidgets('draws as many bars as steps', (tester) async {
    await pumpApp(tester, const StepIndicator(current: 1, total: 2));

    expect(barColors(tester), [AppColors.brand500, AppColors.line]);
  });

  testWidgets('is announced once, as text, without the bars', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, const StepIndicator(current: 1, total: 3));

    expect(find.bySemanticsLabel('Paso 1 de 3'), findsOneWidget);
    handle.dispose();
  });
}
