import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('takes exactly the size of the content it stands in for', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Align(
        alignment: Alignment.centerLeft,
        child: SkeletonBlock(width: 270, height: 146),
      ),
    );

    expect(tester.getSize(find.byType(SkeletonBlock)), const Size(270, 146));
  });

  testWidgets('shimmers with the motion tokens', (tester) async {
    await pumpApp(tester, const SkeletonBlock(height: 24));

    expect(tester.hasRunningAnimations, isTrue);

    final band = find.byKey(const ValueKey('skeleton-band'));
    final start = tester.getTopLeft(band).dx;
    await tester.pump(AppMotion.shimmerDuration ~/ 2);
    final middle = tester.getTopLeft(band).dx;
    await tester.pump(AppMotion.shimmerDuration ~/ 2);
    final restarted = tester.getTopLeft(band).dx;

    expect(middle, greaterThan(start));
    expect(restarted, closeTo(start, 0.01));
  });

  testWidgets('is static when the platform asks for reduced motion', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const SkeletonBlock(height: 24),
      disableAnimations: true,
    );

    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byKey(const ValueKey('skeleton-band')), findsNothing);
  });

  testWidgets('is hidden from assistive technology', (tester) async {
    await pumpApp(tester, const SkeletonBlock(height: 24));

    expect(
      find.descendant(
        of: find.byType(SkeletonBlock),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses the card radius unless told otherwise', (tester) async {
    await pumpApp(tester, const SkeletonBlock(height: 24));

    expect(
      tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
      BorderRadius.circular(AppRadii.card),
    );
  });
}
