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

  testWidgets('is disabled without a callback', (tester) async {
    await pumpApp(tester, build(value: false));

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
  });
}
