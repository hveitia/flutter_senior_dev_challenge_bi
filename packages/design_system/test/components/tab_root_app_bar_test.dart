import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPushed(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    appBar: TabRootAppBar(title: 'Cuentas'),
                  ),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the name of the section as a heading', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPushed(tester);

    expect(find.text('Cuentas'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Cuentas')),
      containsSemantics(isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('never offers to go back, even when there is a page below', (
    tester,
  ) async {
    await pumpPushed(tester);

    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('aligns the title with the screen margin', (tester) async {
    await pumpPushed(tester);

    expect(
      tester.getTopLeft(find.text('Cuentas')).dx,
      AppSpacing.screenMargin,
    );
  });
}
