import 'package:banca_digital/gallery/design_system_gallery.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sections = [
    'Color',
    'Tipografía',
    'Importes',
    'Botones',
    'Campos de texto',
    'Chips',
    'Formularios',
    'Estados de conexión',
    'Carga',
    'Errores y vacíos',
    'Módulo',
  ];

  testWidgets('shows every section of the design system', (tester) async {
    await tester.pumpWidget(const GalleryApp());

    for (final section in sections) {
      expect(find.text(section), findsOneWidget, reason: section);
    }
    expect(find.byType(AppButton), findsWidgets);
    expect(find.byType(AppTextField), findsWidgets);
    expect(find.byType(StatusBanner), findsNWidgets(3));
    expect(find.byType(AmountText), findsWidgets);
  });

  testWidgets('shows the form components and lets them be operated', (
    tester,
  ) async {
    await tester.pumpWidget(const GalleryApp());

    expect(find.byType(Wordmark), findsOneWidget);
    expect(find.byType(StepIndicator), findsOneWidget);
    expect(find.byType(InlineAlert), findsOneWidget);
    expect(find.byType(RequirementItem), findsNWidgets(2));

    final family = find.widgetWithText(RadioCard, 'Familia');
    await tester.ensureVisible(family);
    await tester.tap(family);
    await tester.pump();
    expect(tester.widget<RadioCard>(family).selected, isTrue);

    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(tester.widget<ToggleRow>(find.byType(ToggleRow)).value, isFalse);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<CheckboxRow>(find.byType(CheckboxRow)).value, isTrue);
  });

  testWidgets('chips in the gallery can be toggled', (tester) async {
    await tester.pumpWidget(const GalleryApp());
    final chip = find.widgetWithText(AppChip, 'Invertir');
    await tester.ensureVisible(chip);

    expect(tester.widget<AppChip>(chip).selected, isFalse);
    await tester.tap(chip);
    await tester.pump();

    expect(tester.widget<AppChip>(chip).selected, isTrue);
  });

  testWidgets('lays out on a small phone at 130% text without overflow', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const GalleryApp());

    expect(tester.takeException(), isNull);
  });
}
