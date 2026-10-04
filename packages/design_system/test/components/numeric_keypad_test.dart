import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  group('NumericKeypad', () {
    late List<String> pressed;

    setUp(() => pressed = []);

    Widget keypad({bool enabled = true, bool autofocus = false}) =>
        NumericKeypad(
          enabled: enabled,
          autofocus: autofocus,
          onDigit: (digit) => pressed.add('$digit'),
          onDecimalPoint: () => pressed.add('.'),
          onDelete: () => pressed.add('delete'),
          onClear: () => pressed.add('clear'),
        );

    testWidgets('has a key for every digit, the decimal point and delete', (
      tester,
    ) async {
      await pumpApp(tester, keypad());

      for (var digit = 0; digit <= 9; digit++) {
        await tester.tap(find.text('$digit'));
      }
      await tester.tap(find.text('.'));
      await tester.tap(find.byIcon(Icons.backspace_outlined));

      expect(pressed, [
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', 'delete', //
      ]);
    });

    testWidgets('holding delete clears the entry', (tester) async {
      await pumpApp(tester, keypad());

      await tester.longPress(find.byIcon(Icons.backspace_outlined));

      expect(pressed, ['clear']);
    });

    testWidgets('lays the digits out as on a phone, one to nine then zero', (
      tester,
    ) async {
      await pumpApp(tester, keypad());

      Offset at(String label) => tester.getCenter(find.text(label));

      expect(at('1').dy, at('3').dy);
      expect(at('1').dx, lessThan(at('2').dx));
      expect(at('2').dx, lessThan(at('3').dx));
      expect(at('1').dy, lessThan(at('4').dy));
      expect(at('4').dy, lessThan(at('7').dy));
      expect(at('7').dy, lessThan(at('0').dy));
      expect(at('.').dx, lessThan(at('0').dx));
      expect(at('0').dx, at('2').dx);
    });

    testWidgets('names the keys that are not a digit for a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, keypad());

      expect(find.bySemanticsLabel('Punto decimal'), findsOneWidget);
      expect(find.bySemanticsLabel('Borrar'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('7')),
        containsSemantics(isButton: true, label: '7'),
      );
      handle.dispose();
    });

    testWidgets('every key offers a touch target of at least 48', (
      tester,
    ) async {
      await pumpApp(tester, keypad());

      for (final key in find.byType(TextButton).evaluate()) {
        final size = key.size!;
        expect(size.width, greaterThanOrEqualTo(AppSizes.touchTarget));
        expect(size.height, greaterThanOrEqualTo(AppSizes.touchTarget));
      }
    });

    testWidgets('does nothing while disabled', (tester) async {
      await pumpApp(tester, keypad(enabled: false));

      await tester.tap(find.text('5'), warnIfMissed: false);
      await tester.tap(
        find.byIcon(Icons.backspace_outlined),
        warnIfMissed: false,
      );

      expect(pressed, isEmpty);
    });

    testWidgets('a hardware keyboard types into it, with a point or a comma '
        'as the decimal key', (tester) async {
      await pumpApp(tester, keypad(autofocus: true));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
      await tester.sendKeyEvent(LogicalKeyboardKey.period, character: '.');
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad5, character: '5');
      await tester.sendKeyEvent(LogicalKeyboardKey.comma, character: ',');
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadDecimal);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');

      expect(pressed, ['1', '.', '5', '.', '.', 'delete']);
    });

    testWidgets('pressing a key takes the focus from a text field, so the '
        'on-screen keyboard closes', (tester) async {
      final field = FocusNode();
      addTearDown(field.dispose);
      await pumpApp(
        tester,
        Column(
          children: [
            AppTextField(label: 'Concepto', focusNode: field),
            keypad(),
          ],
        ),
      );
      field.requestFocus();
      await tester.pump();
      expect(field.hasFocus, isTrue);

      await tester.tap(find.text('5'));
      await tester.pump();

      expect(field.hasFocus, isFalse);
      expect(pressed, ['5']);
    });
  });
}
