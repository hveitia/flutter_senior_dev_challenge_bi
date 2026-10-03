import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    testWidgets('shows progress and gives no response to touch', (
      tester,
    ) async {
      var taps = 0;
      await pumpApp(
        tester,
        AppButton(label: 'Continuar', isLoading: true, onPressed: () => taps++),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Not hit-testable: no ripple or hover that would suggest it reacts.
      expect(find.byType(FilledButton).hitTestable(), findsNothing);

      await tester.tap(find.byType(AppButton), warnIfMissed: false);

      expect(taps, 0);
    });

    testWidgets('does not submit again from the keyboard', (tester) async {
      Future<int> tapsAfterEnter({required bool isLoading}) async {
        var taps = 0;
        await pumpApp(
          tester,
          AppButton(
            label: 'Continuar',
            isLoading: isLoading,
            onPressed: () => taps++,
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        return taps;
      }

      // The idle case proves the key sequence does reach the button.
      expect(await tapsAfterEnter(isLoading: false), 1);
      expect(await tapsAfterEnter(isLoading: true), 0);
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

    testWidgets('announces that it started loading and is unavailable', (
      tester,
    ) async {
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
          isLiveRegion: true,
        ),
      );
      handle.dispose();
    });
  });
}
