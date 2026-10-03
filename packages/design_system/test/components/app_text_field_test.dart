import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  group('semantics', () {
    const message = 'Ingresa una cédula válida de 10 dígitos';

    testWidgets('the label is announced as part of the field', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const AppTextField(label: 'Cédula'));

      final field = tester.getSemantics(find.byType(TextField));

      expect(
        field,
        containsSemantics(
          isTextField: true,
          validationResult: SemanticsValidationResult.none,
        ),
      );
      expect(field.label, contains('Cédula'));
      handle.dispose();
    });

    testWidgets('an error is announced once, when it appears', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const AppTextField(label: 'Cédula'));

      expect(find.text(message), findsNothing);

      await pumpApp(
        tester,
        const AppTextField(label: 'Cédula', errorText: message),
      );

      expect(
        tester.getSemantics(find.text(message)),
        containsSemantics(label: message, isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('the field is flagged invalid but is not a live region, so '
        'typing does not repeat the error', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const AppTextField(label: 'Cédula', errorText: message),
      );

      await tester.enterText(find.byType(TextField), '17123');
      await tester.pump();

      final field = tester.getSemantics(find.byType(TextField));

      expect(
        field,
        containsSemantics(
          isTextField: true,
          isLiveRegion: false,
          validationResult: SemanticsValidationResult.invalid,
        ),
      );
      expect(field.label, isNot(contains(message)));
      handle.dispose();
    });
    testWidgets('a trailing action stays a button of its own instead of '
        'turning the field into one', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        AppTextField(
          label: 'Contraseña',
          helperText: 'Solo tú la conoces',
          suffixIcon: IconButton(
            tooltip: 'Mostrar contraseña',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () {},
          ),
        ),
      );

      final field = tester.getSemantics(find.byType(TextField));
      final action = tester.getSemantics(find.byType(IconButton));

      expect(field, containsSemantics(isTextField: true, isButton: false));
      expect(field.label, contains('Contraseña'));
      expect(field.label, isNot(contains('Mostrar contraseña')));
      expect(
        action,
        containsSemantics(
          tooltip: 'Mostrar contraseña',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(action.id, isNot(field.id));
      handle.dispose();
    });

    testWidgets('the helper is announced as the hint of the field', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const AppTextField(
          label: 'Correo electrónico',
          helperText: 'Lo usamos para enviarte tus comprobantes',
        ),
      );

      expect(
        tester.getSemantics(find.byType(TextField)),
        containsSemantics(
          isTextField: true,
          hint: 'Lo usamos para enviarte tus comprobantes',
        ),
      );
      handle.dispose();
    });
  });
}
