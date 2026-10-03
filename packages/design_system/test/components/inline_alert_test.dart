import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  const message = 'No pudimos validar tus datos. Revisa e intenta de nuevo.';

  testWidgets('states the problem with an icon and text in the danger tone', (
    tester,
  ) async {
    await pumpApp(tester, const InlineAlert(message: message));

    expect(
      tester.widget<Text>(find.text(message)).style!.color,
      AppColors.danger500,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded)).color,
      AppColors.danger500,
    );
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(InlineAlert),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as BoxDecoration).color, AppColors.dangerTint);
  });

  testWidgets('takes the colors of another tone and another icon', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const InlineAlert(
        message: 'Te enviamos un enlace',
        tone: AppTone.success,
        icon: Icons.mark_email_read_outlined,
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.mark_email_read_outlined)).color,
      AppColors.success500,
    );
  });

  testWidgets('is announced as soon as it appears', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, const InlineAlert(message: message));

    expect(
      tester.getSemantics(find.byType(InlineAlert)),
      containsSemantics(label: message, isLiveRegion: true),
    );
    handle.dispose();
  });
}
