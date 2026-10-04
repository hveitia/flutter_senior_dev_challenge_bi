import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  group('trendLinePoints', () {
    const size = Size(100, 40);

    test('spreads the values over the width, first at the left edge and '
        'last at the right', () {
      final points = trendLinePoints([1, 2, 3, 4, 5], size);

      expect(points.map((point) => point.dx), [0, 25, 50, 75, 100]);
    });

    test('puts the highest value at the top and the lowest at the bottom', () {
      final points = trendLinePoints([10, 30, 20], size);

      expect(points[0].dy, 40);
      expect(points[1].dy, 0);
      expect(points[2].dy, 20);
    });

    test('draws values that are all the same as a line through the middle', () {
      final points = trendLinePoints([7, 7, 7], size);

      expect(points.map((point) => point.dy), [20, 20, 20]);
    });

    test('handles negative values, as an overdrawn balance has', () {
      final points = trendLinePoints([-100, 0, 100], size);

      expect(points.map((point) => point.dy), [40, 20, 0]);
    });

    test('has nothing to draw with fewer than two values', () {
      expect(trendLinePoints([5], size), isEmpty);
      expect(trendLinePoints(const [], size), isEmpty);
    });
  });

  group('TrendLine', () {
    testWidgets('is announced by its label, as one image', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const TrendLine(
          values: [1, 3, 2],
          semanticLabel: 'Tendencia de los últimos 30 días',
        ),
      );

      expect(
        tester.getSemantics(find.byType(TrendLine)),
        matchesSemantics(
          label: 'Tendencia de los últimos 30 días',
          isImage: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('takes the height of the token and all the width', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const TrendLine(values: [1, 3, 2], semanticLabel: 'Tendencia'),
      );

      expect(tester.getSize(find.byType(TrendLine)).height, TrendLine.height);
    });

    testWidgets('takes no space with fewer than two values', (tester) async {
      await pumpApp(
        tester,
        const TrendLine(values: [1], semanticLabel: 'Tendencia'),
      );

      expect(tester.getSize(find.byType(TrendLine)), Size.zero);
    });
  });
}
