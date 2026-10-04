import 'package:design_system/design_system.dart';
import 'package:feature_home/src/home_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHeader(WidgetTester tester, {Widget? action}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeHeader(
            productName: 'Banca Digital',
            greeting: 'Hola, Valentina',
            initials: 'VA',
            action: action,
          ),
        ),
      ),
    );
  }

  testWidgets('places what the app gives it after the greeting', (
    tester,
  ) async {
    await pumpHeader(tester, action: const Icon(Icons.notifications_none));

    final greeting = tester.getTopRight(find.text('Hola, Valentina'));
    final action = tester.getTopLeft(find.byIcon(Icons.notifications_none));
    expect(action.dx, greaterThanOrEqualTo(greeting.dx));
  });

  testWidgets('draws nothing there when the app gives it nothing', (
    tester,
  ) async {
    await pumpHeader(tester);

    expect(find.byType(Icon), findsNothing);
    expect(find.text('Hola, Valentina'), findsOneWidget);
  });

  testWidgets('a long greeting leaves room for the action on a narrow '
      'screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: app!,
        ),
        home: const Scaffold(
          body: HomeHeader(
            productName: 'Banca Digital',
            greeting: 'Hola, María Fernanda de los Ángeles',
            initials: 'MF',
            action: SizedBox.square(dimension: 48),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
