import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/component_catalog.dart';
import '../support/pump_app.dart';

/// Narrow phone, the worst case for layouts at large text sizes.
const Size _smallPhone = Size(320, 640);

/// Text size the design must survive without truncating or overflowing.
const double _largeText = 1.3;

void main() {
  final catalog = componentCatalog();

  for (final MapEntry(key: name, value: component) in catalog.entries) {
    group(name, () {
      testWidgets('meets tap target, label and contrast guidelines', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpApp(tester, component);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      testWidgets('does not overflow on a small phone at 130% text', (
        tester,
      ) async {
        tester.view
          ..physicalSize = _smallPhone
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pumpApp(tester, component, textScale: _largeText);

        expect(tester.takeException(), isNull);
      });

      testWidgets('never paints text in the brand orange', (tester) async {
        await pumpApp(tester, component);

        final colors = <Color>{};
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.byType(RichText),
        )) {
          paragraph.text.visitChildren((span) {
            final color = span.style?.color;
            if (color != null) colors.add(color);
            return true;
          });
        }

        expect(colors, isNot(contains(AppColors.brand500)));
        expect(colors, isNot(contains(AppColors.brand600)));
      });
    });
  }
}
