import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('shows the name in the heading face with the brand mark', (
    tester,
  ) async {
    await pumpApp(tester, const Wordmark(name: 'Banca Digital'));

    expect(
      tester.widget<Text>(find.text('Banca Digital')).style!.fontFamily,
      AppTypography.subtitle.fontFamily,
    );
    final mark = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(Wordmark),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((mark.decoration as BoxDecoration).color, AppColors.brand500);
  });

  testWidgets('is announced by its name only', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, const Wordmark(name: 'Banca Digital'));

    expect(find.bySemanticsLabel('Banca Digital'), findsOneWidget);
    handle.dispose();
  });
}
