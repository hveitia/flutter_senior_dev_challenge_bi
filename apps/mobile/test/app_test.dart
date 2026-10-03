import 'package:banca_digital/app.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the product wordmark on launch', (tester) async {
    await tester.pumpWidget(const BancaDigitalApp());

    expect(find.text('Banca Digital'), findsOneWidget);
  });

  testWidgets('is themed by the design system', (tester) async {
    await tester.pumpWidget(const BancaDigitalApp());

    final context = tester.element(find.text('Banca Digital'));
    final wordmark = tester.widget<Text>(find.text('Banca Digital'));

    expect(Theme.of(context).extension<AppSemanticColors>(), isNotNull);
    expect(wordmark.style!.fontFamily, AppTypography.display.fontFamily);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppColors.surface0,
    );
  });

  testWidgets('shows progress under the wordmark while starting', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const BancaDigitalApp());

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    handle.dispose();
  });
}
