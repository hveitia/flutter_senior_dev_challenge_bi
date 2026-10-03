import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  const label = 'Ingresar con huella o rostro';

  testWidgets('reports the new value when switched', (tester) async {
    bool? changedTo;
    await pumpApp(
      tester,
      ToggleRow(
        label: label,
        value: false,
        onChanged: (value) => changedTo = value,
      ),
    );

    await tester.tap(find.byType(Switch));

    expect(changedTo, isTrue);
  });

  testWidgets('announces the label and the state as one control', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      ToggleRow(label: label, value: true, onChanged: (_) {}),
    );

    expect(
      tester.getSemantics(find.byType(ToggleRow)),
      containsSemantics(
        label: label,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('is disabled without a callback', (tester) async {
    await pumpApp(
      tester,
      const ToggleRow(label: label, value: true, onChanged: null),
    );

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });
}
