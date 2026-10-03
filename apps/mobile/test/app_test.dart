import 'package:banca_digital/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the product wordmark on launch', (tester) async {
    await tester.pumpWidget(const BancaDigitalApp());

    expect(find.text('Banca Digital'), findsOneWidget);
  });
}
