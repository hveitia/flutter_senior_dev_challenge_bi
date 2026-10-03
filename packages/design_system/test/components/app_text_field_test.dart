import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  InputDecoration decorationOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).decoration!;

  OutlineInputBorder border(InputBorder? border) =>
      border! as OutlineInputBorder;

  testWidgets('shows the label above the field and the helper below', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const AppTextField(
        label: 'Celular',
        hintText: '099 123 4567',
        helperText: 'Lo usamos para confirmar tus operaciones',
      ),
    );

    final label = tester.getTopLeft(find.text('Celular'));
    final field = tester.getTopLeft(find.byType(TextField));
    final helper = tester.getTopLeft(
      find.text('Lo usamos para confirmar tus operaciones'),
    );

    expect(label.dy, lessThan(field.dy));
    expect(field.dy, lessThan(helper.dy));
    expect(find.text('099 123 4567'), findsOneWidget);
  });

  testWidgets('reports what the user types', (tester) async {
    String? value;
    await pumpApp(
      tester,
      AppTextField(label: 'Cédula', onChanged: (text) => value = text),
    );

    await tester.enterText(find.byType(TextField), '1712345678');

    expect(value, '1712345678');
  });

  testWidgets('resting border is a 1px line, focus is a 2px ink ring', (
    tester,
  ) async {
    await pumpApp(tester, const AppTextField(label: 'Cédula'));

    final decoration = decorationOf(tester);

    expect(
      border(decoration.enabledBorder).borderSide,
      const BorderSide(color: AppColors.line),
    );
    expect(
      border(decoration.focusedBorder).borderSide,
      const BorderSide(
        color: AppColors.focusRing,
        width: AppSizes.focusWidth,
      ),
    );
    expect(
      border(decoration.enabledBorder).borderRadius,
      const BorderRadius.all(Radius.circular(AppRadii.input)),
    );
  });

  group('error', () {
    const message = 'Ingresa una cédula válida de 10 dígitos';

    testWidgets('shows an icon next to the message, not color alone', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const AppTextField(
          label: 'Cédula',
          helperText: 'Sin guiones',
          errorText: message,
        ),
      );

      expect(find.text(message), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Sin guiones'), findsNothing);
    });

    testWidgets('outlines the field in the danger color', (tester) async {
      await pumpApp(
        tester,
        const AppTextField(label: 'Cédula', errorText: message),
      );

      final decoration = decorationOf(tester);

      expect(
        border(decoration.enabledBorder).borderSide.color,
        AppColors.danger500,
      );
      expect(
        border(decoration.focusedBorder).borderSide,
        const BorderSide(
          color: AppColors.danger500,
          width: AppSizes.focusWidth,
        ),
      );
    });
  });

  testWidgets('disabled fields are inset and not editable', (tester) async {
    await pumpApp(tester, const AppTextField(label: 'Cédula', enabled: false));

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(decorationOf(tester).fillColor, AppColors.surface2);
  });

  testWidgets('label and error are announced with the field', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      const AppTextField(
        label: 'Cédula',
        errorText: 'Ingresa una cédula válida de 10 dígitos',
      ),
    );

    final node = tester.getSemantics(find.byType(TextField));

    expect(node, containsSemantics(isTextField: true));
    expect(node.label, contains('Cédula'));
    expect(node.label, contains('Ingresa una cédula válida de 10 dígitos'));
    handle.dispose();
  });
}
