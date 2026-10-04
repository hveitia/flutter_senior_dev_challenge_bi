import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/presentation/widgets/freshness_caption.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final syncedAt = DateTime(2026, 10, 3, 9, 52);
  late DateTime clock;

  Future<void> pumpCaption(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FreshnessCaption(syncedAt: syncedAt, now: () => clock),
        ),
      ),
    );
  }

  /// Moves the injected clock and the test's own time forward together.
  Future<void> elapse(WidgetTester tester, Duration time) async {
    clock = clock.add(time);
    await tester.pump(time);
  }

  setUp(() => clock = DateTime(2026, 10, 3, 10));

  testWidgets('says how old the data is', (tester) async {
    await pumpCaption(tester);

    expect(find.text('Actualizado hace 8 min'), findsOneWidget);
  });

  testWidgets('gets older by itself, without anything else changing', (
    tester,
  ) async {
    await pumpCaption(tester);

    await elapse(tester, FreshnessCaption.tick);
    expect(find.text('Actualizado hace 9 min'), findsOneWidget);

    await elapse(tester, FreshnessCaption.tick * 51);
    expect(find.text('Actualizado hace 1 h'), findsOneWidget);
  });

  testWidgets('stops counting once it leaves the screen', (tester) async {
    await pumpCaption(tester);

    await tester.pumpWidget(const SizedBox.shrink());

    // A timer left running would make the test fail when it ends.
    await elapse(tester, FreshnessCaption.tick * 3);
    expect(find.byType(FreshnessCaption), findsNothing);
  });

  testWidgets('says the data is saved when it does not know from when', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FreshnessCaption(syncedAt: null, now: () => clock),
        ),
      ),
    );

    expect(find.text('Datos guardados'), findsOneWidget);
  });
}
