import 'package:banca_digital/main.dart' as app;
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The critical flow, end to end, on a device and against real services:
/// sign in, transfer between the customer's two accounts and see the new
/// movement in the account the money left from.
///
/// Nothing here is faked. It needs the customer API running and reachable
/// (see `docs/operacion/api.md`) and a customer with two accounts, given by
/// the environment and never committed:
///
///     flutter test integration_test/transfer_flow_test.dart \
///       -d <device> \
///       --dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=... \
///       --dart-define=API_BASE_URL=http://localhost:3210/
///
/// Each run moves $1.00 from the savings account to the checking account.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('E2E_EMAIL');
  const password = String.fromEnvironment('E2E_PASSWORD');

  /// How long a step may take against a real backend.
  const patience = Duration(seconds: 40);
  const step = Duration(milliseconds: 250);

  /// How long the keyboard takes to slide away.
  const keyboardTime = Duration(seconds: 1);

  /// Pumps until [finder] finds something. `pumpAndSettle` cannot be used:
  /// a loading indicator never settles.
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    final deadline = DateTime.now().add(patience);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for $finder');
      }
      await tester.pump(step);
    }
  }

  Finder field(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(AppTextField),
    ),
    matching: find.byType(EditableText),
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await waitFor(tester, finder);
    await tester.ensureVisible(finder.first);
    await tester.pump(step);
    await tester.tap(finder.first);
    await tester.pump(step);
  }

  testWidgets('a customer signs in, transfers between their accounts and '
      'sees the movement', (tester) async {
    expect(
      email.isNotEmpty && password.isNotEmpty,
      isTrue,
      reason: 'Pass E2E_EMAIL and E2E_PASSWORD with --dart-define',
    );
    const concept = 'Prueba de extremo a extremo';

    await app.main();
    await waitFor(
      tester,
      find.textContaining(RegExp('Ya soy cliente|Hola,')),
    );

    // A session left by an earlier run goes straight to the home.
    if (find.text('Ya soy cliente').evaluate().isNotEmpty) {
      await tap(tester, find.text('Ya soy cliente'));
      await waitFor(tester, field('Correo electrónico'));
      await tester.enterText(field('Correo electrónico'), email);
      await tester.enterText(field('Contraseña'), password);
      await tester.pump(step);
      await tap(tester, find.widgetWithText(AppButton, 'Ingresar'));
    }
    await waitFor(tester, find.textContaining('Hola,'));

    await tap(
      tester,
      find.descendant(
        of: find.byType(AppBottomNavigation),
        matching: find.text('Cuentas'),
      ),
    );
    await tap(tester, find.text('Cuenta de ahorros'));
    await tap(tester, find.widgetWithText(AppButton, 'Transferir'));

    await waitFor(tester, field('Monto'));
    await tester.enterText(field('Monto'), '100');
    await tester.enterText(field('Concepto (opcional)'), concept);
    // On a real device the keyboard covers the button below; it is put
    // away as a customer would, and the layout given time to settle.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(keyboardTime);
    await tap(tester, find.widgetWithText(AppButton, 'Continuar'));
    await tap(
      tester,
      find.widgetWithText(AppButton, 'Confirmar transferencia'),
    );

    await waitFor(tester, find.text('Transferencia realizada'));
    // The reference the server gave this transfer: what proves, below, that
    // the movement found is this one and not an older transfer.
    final reference = tester
        .widget<Text>(find.textContaining(RegExp('^TRF-')).first)
        .data!;

    await tap(tester, find.widgetWithText(AppButton, 'Ver movimiento'));

    // The movement arrives through the same listener every screen follows;
    // the newest is listed first.
    await tap(tester, find.text('Transferencia a Cuenta corriente'));
    await waitFor(tester, find.text(reference));
    expect(find.text(reference), findsOneWidget);
  });
}
