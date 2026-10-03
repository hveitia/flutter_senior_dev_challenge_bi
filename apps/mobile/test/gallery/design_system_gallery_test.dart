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
