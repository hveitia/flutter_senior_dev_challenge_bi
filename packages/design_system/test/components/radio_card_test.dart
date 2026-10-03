import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(find.byType(AnimatedContainer))
              .decoration!
          as BoxDecoration;

  testWidgets('reports a tap', (tester) async {
    var taps = 0;
    await pumpApp(
      tester,
      RadioCard(label: 'Familia', selected: false, onSelected: () => taps++),
    );

    await tester.tap(find.text('Familia'));

    expect(taps, 1);
  });

  testWidgets('shows the choice with the radio mark and the tint', (
    tester,
  ) async {
    await pumpApp(
      tester,
      RadioCard(label: 'Familia', selected: true, onSelected: () {}),
    );

    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(decoration(tester).color, AppColors.brand50);
  });

  testWidgets('shows an empty mark and no tint when not chosen', (
    tester,
  ) async {
    await pumpApp(
      tester,
      RadioCard(label: 'Familia', selected: false, onSelected: () {}),
    );

    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(decoration(tester).color, AppColors.surface0);
  });

  testWidgets('is announced as one option of an exclusive group', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      RadioCard(label: 'Familia', selected: true, onSelected: () {}),
    );

    expect(
      tester.getSemantics(find.byType(RadioCard)),
      containsSemantics(
        label: 'Familia',
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('draws the focus ring when reached with the keyboard', (
    tester,
  ) async {
    await pumpApp(
      tester,
      RadioCard(label: 'Familia', selected: false, onSelected: () {}),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final border = decoration(tester).border! as Border;
    expect(border.top.color, AppColors.focusRing);
    expect(border.top.width, AppSizes.focusWidth);
  });

  testWidgets('does not react when disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      const RadioCard(label: 'Familia', selected: false, onSelected: null),
    );

    expect(
      tester.getSemantics(find.byType(RadioCard)),
      containsSemantics(hasEnabledState: true, isEnabled: false),
    );
    handle.dispose();
  });
}
