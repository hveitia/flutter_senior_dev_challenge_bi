import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  const semanticLabel = 'Acepto los términos y condiciones';

  Widget build({required bool value, ValueChanged<bool>? onChanged}) {
    return CheckboxRow(
      value: value,
      onChanged: onChanged,
      semanticLabel: semanticLabel,
      label: const Text('Acepto los términos y condiciones.'),
    );
  }

  testWidgets('reports the new value when ticked', (tester) async {
    bool? changedTo;
    await pumpApp(
      tester,
      build(value: false, onChanged: (value) => changedTo = value),
    );

    await tester.tap(find.byType(Checkbox));

    expect(changedTo, isTrue);
  });

  testWidgets('shows the label next to the checkbox', (tester) async {
    await pumpApp(tester, build(value: false, onChanged: (_) {}));

    expect(find.text('Acepto los términos y condiciones.'), findsOneWidget);
  });

  testWidgets('announces the checkbox with its own label and state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, build(value: true, onChanged: (_) {}));

    expect(
      tester.getSemantics(find.byType(Checkbox)),
      containsSemantics(
        label: semanticLabel,
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  group('layout', () {
    /// Where the box the customer sees is drawn. Material centers it in a
    /// larger widget, so its edge is not the edge of the `Checkbox`.
    Rect visibleBox(WidgetTester tester) => Rect.fromCenter(
      center: tester.getCenter(find.byType(Checkbox)),
      width: Checkbox.width,
      height: Checkbox.width,
    );

    testWidgets('draws the box flush with the start edge of the row', (
      tester,
    ) async {
      await pumpApp(tester, build(value: false, onChanged: (_) {}));

      expect(
        visibleBox(tester).left,
        tester.getRect(find.byType(CheckboxRow)).left,
      );
    });

    testWidgets('keeps a full-size touch target that starts at that edge', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpApp(tester, build(value: false, onChanged: (_) => taps++));
      final row = tester.getRect(find.byType(CheckboxRow));

      // The corner of the target farthest from the box.
      await tester.tapAt(
        row.topLeft +
            const Offset(AppSizes.touchTarget - 1, AppSizes.touchTarget - 1),
      );

      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(Checkbox)).rect.size,
        const Size.square(AppSizes.touchTarget),
      );
      handle.dispose();
    });

    testWidgets('centers the first line of the label on the box', (
      tester,
    ) async {
      await pumpApp(tester, build(value: false, onChanged: (_) {}));

      final label = tester.getRect(
        find.text('Acepto los términos y condiciones.'),
      );
      expect(label.center.dy, closeTo(visibleBox(tester).center.dy, 1));
    });
  });

  testWidgets('is disabled without a callback', (tester) async {
    await pumpApp(tester, build(value: false));

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
  });
}
