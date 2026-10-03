import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  group('AppChip', () {
    testWidgets('reports the new selection when tapped', (tester) async {
      bool? selection;
      await pumpApp(
        tester,
        AppChip(
          label: 'Ahorrar',
          selected: false,
          onSelected: (value) => selection = value,
        ),
      );

      await tester.tap(find.text('Ahorrar'));

      expect(selection, isTrue);
    });

    testWidgets('marks selection with a check, not with color alone', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Column(
          children: [
            AppChip(label: 'Viajar', selected: true, onSelected: (_) {}),
            AppChip(label: 'Invertir', selected: false, onSelected: (_) {}),
          ],
        ),
      );

      expect(
        find.descendant(
          of: find.widgetWithText(AppChip, 'Viajar'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(AppChip, 'Invertir'),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
    });

    testWidgets('offers a touch target of at least 48', (tester) async {
      await pumpApp(
        tester,
        AppChip(label: 'Ahorrar', selected: false, onSelected: (_) {}),
      );

      expect(
        tester.getSize(find.byType(AppChip)).height,
        greaterThanOrEqualTo(AppSizes.touchTarget),
      );
    });

    testWidgets('announces its selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        AppChip(label: 'Viajar', selected: true, onSelected: (_) {}),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Viajar')),
        containsSemantics(
          label: 'Viajar',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      handle.dispose();
    });
  });

  group('StatusChip', () {
    for (final tone in AppTone.values) {
      testWidgets('${tone.name} pairs an icon with its label', (tester) async {
        await pumpApp(tester, StatusChip(label: 'Estado', tone: tone));

        final icon = tester.widget<Icon>(find.byType(Icon));
        final label = tester.widget<Text>(find.text('Estado'));
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(StatusChip),
            matching: find.byType(DecoratedBox),
          ),
        );

        expect(icon.color, AppSemanticColors.light.foreground(tone));
        expect(label.style!.color, AppSemanticColors.light.foreground(tone));
        expect(
          (box.decoration as BoxDecoration).color,
          AppSemanticColors.light.tint(tone),
        );
      });
    }

    testWidgets('accepts an icon that fits the status better', (tester) async {
      await pumpApp(
        tester,
        const StatusChip(
          label: 'En cola',
          tone: AppTone.warning,
          icon: Icons.schedule,
        ),
      );

      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.text('En cola'), findsOneWidget);
    });
  });
}
