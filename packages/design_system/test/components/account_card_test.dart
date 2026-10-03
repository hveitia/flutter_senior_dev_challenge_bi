import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, {void Function()? onTap}) {
    return pumpApp(
      tester,
      AccountCard(
        name: 'Cuenta de ahorros',
        maskedNumber: '****4821',
        balanceCents: 357035,
        onTap: onTap ?? () {},
      ),
    );
  }

  testWidgets('shows the account name, masked number and balance', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(find.text('Cuenta de ahorros'), findsOneWidget);
    expect(find.text('****4821'), findsOneWidget);
    expect(find.text(r'$3,570.35', findRichText: true), findsOneWidget);
  });

  testWidgets('opens the account when tapped', (tester) async {
    var taps = 0;
    await pumpCard(tester, onTap: () => taps++);

    await tester.tap(find.byType(AccountCard));

    expect(taps, 1);
  });

  testWidgets('is one button that reads name, number and balance', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpCard(tester);

    expect(
      tester.getSemantics(find.byType(AccountCard)),
      containsSemantics(
        isButton: true,
        label:
            'Cuenta de ahorros, terminada en 4821, '
            '3570 dólares con 35 centavos',
      ),
    );
    handle.dispose();
  });
}
