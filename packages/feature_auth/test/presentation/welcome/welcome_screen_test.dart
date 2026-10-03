import 'package:feature_auth/src/presentation/welcome/welcome_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_auth.dart';

void main() {
  testWidgets('presents the product and its three benefits', (tester) async {
    await pumpAuth(
      tester,
      WelcomeScreen(onOpenAccount: () {}, onSignIn: () {}),
    );

    expect(find.text('Banca Digital'), findsOneWidget);
    expect(find.text('Tu banco, sin filas ni sucursales'), findsOneWidget);
    expect(find.text('Abre tu cuenta en minutos'), findsOneWidget);
    expect(find.text('Una experiencia que se adapta a ti'), findsOneWidget);
    expect(
      find.text('Servicios y beneficios en un solo lugar'),
      findsOneWidget,
    );
  });

  testWidgets('offers to open an account and to sign in', (tester) async {
    final taps = <String>[];
    await pumpAuth(
      tester,
      WelcomeScreen(
        onOpenAccount: () => taps.add('open'),
        onSignIn: () => taps.add('signIn'),
      ),
    );

    await tester.tap(find.text('Abrir mi cuenta'));
    await tester.tap(find.text('Ya soy cliente'));

    expect(taps, ['open', 'signIn']);
  });

  testWidgets('meets the accessibility guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAuth(
      tester,
      WelcomeScreen(onOpenAccount: () {}, onSignIn: () {}),
    );

    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('fits a small phone at 130% text', (tester) async {
    useSmallPhone(tester);
    await pumpAuth(
      tester,
      WelcomeScreen(onOpenAccount: () {}, onSignIn: () {}),
      textScale: largeText,
    );

    expect(tester.takeException(), isNull);
  });
}
