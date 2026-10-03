import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('shows the label in capitals', (tester) async {
    await pumpApp(tester, const GroupHeader(label: 'Saldo total'));

    expect(find.text('SALDO TOTAL'), findsOneWidget);
  });

  testWidgets('is announced as a heading with the label as written', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, const GroupHeader(label: 'Hoy'));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Hoy')),
      containsSemantics(isHeader: true, label: 'Hoy'),
    );
    handle.dispose();
  });
}
