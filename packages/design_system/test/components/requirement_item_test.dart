import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('shows a met requirement with a check in the success color', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const RequirementItem(label: 'Un número', met: true),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.check)).color,
      AppColors.success500,
    );
    expect(
      tester.widget<Text>(find.text('Un número')).style!.color,
      AppColors.success500,
    );
  });

  testWidgets('shows a pending requirement with an empty mark', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const RequirementItem(label: 'Un número', met: false),
    );

    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(
      tester.widget<Text>(find.text('Un número')).style!.color,
      AppTextColors.secondary,
    );
  });

  testWidgets('says in words whether the requirement is met', (tester) async {
    final handle = tester.ensureSemantics();

    await pumpApp(
      tester,
      const RequirementItem(label: 'Un número', met: true),
    );
    expect(find.bySemanticsLabel('Un número, cumplido'), findsOneWidget);

    await pumpApp(
      tester,
      const RequirementItem(label: 'Un número', met: false),
    );
    expect(find.bySemanticsLabel('Un número, pendiente'), findsOneWidget);
    handle.dispose();
  });
}
