import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const items = [
    AppBottomNavigationItem(label: 'Inicio', icon: Icons.home_outlined),
    AppBottomNavigationItem(
      label: 'Cuentas',
      icon: Icons.account_balance_wallet_outlined,
    ),
    AppBottomNavigationItem(label: 'Servicios', icon: Icons.grid_view),
    AppBottomNavigationItem(label: 'Perfil', icon: Icons.person_outline),
  ];

  Future<void> pumpNavigation(
    WidgetTester tester, {
    int currentIndex = 0,
    ValueChanged<int>? onSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            items: items,
            currentIndex: currentIndex,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows every destination', (tester) async {
    await pumpNavigation(tester);

    for (final item in items) {
      expect(find.text(item.label), findsOneWidget);
    }
  });

  testWidgets('reports the destination that was tapped', (tester) async {
    final selected = <int>[];
    await pumpNavigation(tester, onSelected: selected.add);

    await tester.tap(find.text('Servicios'));

    expect(selected, [2]);
  });

  testWidgets('announces which destination is current', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpNavigation(tester, currentIndex: 1);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Cuentas')),
      containsSemantics(isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Inicio')),
      containsSemantics(isSelected: false, isButton: true),
    );
    handle.dispose();
  });

  testWidgets('marks the current destination with more than color', (
    tester,
  ) async {
    await pumpNavigation(tester, currentIndex: 3);

    expect(
      find.descendant(
        of: find.byType(AppBottomNavigation),
        matching: find.byKey(AppBottomNavigation.indicatorKey),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a destination can be chosen with a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final selected = <int>[];
    await pumpNavigation(tester, onSelected: selected.add);

    tester.semantics.tap(find.semantics.byLabel('Cuentas'));

    expect(selected, [1]);
    handle.dispose();
  });
}
