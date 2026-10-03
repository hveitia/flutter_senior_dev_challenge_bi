import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('primary is a filled button that reports taps', (tester) async {
    var taps = 0;
    await pumpApp(
      tester,
      AppButton(label: 'Continuar', onPressed: () => taps++),
    );

    await tester.tap(find.text('Continuar'));

    expect(find.byType(FilledButton), findsOneWidget);
    expect(taps, 1);
  });

  testWidgets('each variant maps to its Material button', (tester) async {
    await pumpApp(
      tester,
      Column(
        children: [
          AppButton(
            label: 'Ya soy cliente',
            variant: AppButtonVariant.secondary,
            onPressed: () {},
          ),
          AppButton(
            label: 'Ahora no',
            variant: AppButtonVariant.text,
            onPressed: () {},
          ),
        ],
      ),
    );

    expect(
      find.widgetWithText(OutlinedButton, 'Ya soy cliente'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Ahora no'), findsOneWidget);
  });

  testWidgets('fills the available width and meets the minimum height', (
    tester,
  ) async {
    await pumpApp(tester, AppButton(label: 'Continuar', onPressed: () {}));

    final size = tester.getSize(find.byType(FilledButton));
    final available =
        tester.getSize(find.byType(Scaffold)).width -
        AppSpacing.screenMargin * 2;

    expect(size.width, available);
    expect(size.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
  });

  testWidgets('is disabled without a callback', (tester) async {
    await pumpApp(tester, const AppButton(label: 'Continuar', onPressed: null));

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isFalse,
    );
  });

  testWidgets('shows a leading icon when given one', (tester) async {
    await pumpApp(
      tester,
      AppButton(
        label: 'Reintentar',
        icon: Icons.refresh,
        onPressed: () {},
      ),
    );

    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  group('loading', () {
    testWidgets('shows progress and ignores taps', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        AppButton(label: 'Continuar', isLoading: true, onPressed: () => taps++),
      );

      await tester.tap(find.byType(AppButton), warnIfMissed: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(taps, 0);
    });

    testWidgets('keeps the size it has when idle', (tester) async {
      Future<Size> sizeWhen({required bool isLoading}) async {
        await pumpApp(
          tester,
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Confirmar transferencia',
              expand: false,
              isLoading: isLoading,
              onPressed: () {},
            ),
          ),
        );
        return tester.getSize(find.byType(FilledButton));
      }

      final idle = await sizeWhen(isLoading: false);
      final loading = await sizeWhen(isLoading: true);

      expect(loading, idle);
    });

    testWidgets('is announced as a busy, unavailable button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        AppButton(label: 'Continuar', isLoading: true, onPressed: () {}),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Continuar, cargando')),
        containsSemantics(
          label: 'Continuar, cargando',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });
  });
}
