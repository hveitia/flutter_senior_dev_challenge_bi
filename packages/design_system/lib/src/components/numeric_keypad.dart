import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keys to type an amount on the screen: the ten digits, the decimal point
/// and delete, laid out as on a phone.
///
/// It holds no text. Each key reports what was pressed and the caller
/// decides what the entry becomes, so the rules of the amount live in one
/// place and not in a widget.
///
/// A hardware keyboard types into it while the focus is on it: digits, a
/// point or a comma for the decimals, and backspace.
class NumericKeypad extends StatefulWidget {
  const NumericKeypad({
    required this.onDigit,
    required this.onDecimalPoint,
    required this.onDelete,
    this.onClear,
    this.enabled = true,
    this.autofocus = false,
    super.key,
  });

  static const String decimalPointLabel = 'Punto decimal';
  static const String deleteLabel = 'Borrar';

  /// A digit from 0 to 9.
  final ValueChanged<int> onDigit;
  final VoidCallback onDecimalPoint;

  /// Removes the last character.
  final VoidCallback onDelete;

  /// Removes everything, on a long press of delete. Null leaves the long
  /// press without effect.
  final VoidCallback? onClear;

  /// False shows the keys and ignores them.
  final bool enabled;

  /// Takes the focus when first shown, so a hardware keyboard types
  /// without a tap.
  final bool autofocus;

  @override
  State<NumericKeypad> createState() => _NumericKeypadState();
}

class _NumericKeypadState extends State<NumericKeypad> {
  final FocusNode _focus = FocusNode(debugLabel: 'NumericKeypad');

  static final Map<LogicalKeyboardKey, int> _numpadDigits = {
    LogicalKeyboardKey.numpad0: 0,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Runs [action] with the focus on the keypad: a text field that had it
  /// lets go, and the on-screen keyboard closes instead of covering the
  /// keys.
  void _press(VoidCallback action) {
    if (!_focus.hasFocus) _focus.requestFocus();
    action();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is KeyUpEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      widget.onDelete();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.numpadDecimal ||
        key == LogicalKeyboardKey.numpadComma) {
      widget.onDecimalPoint();
      return KeyEventResult.handled;
    }
    final numpadDigit = _numpadDigits[key];
    if (numpadDigit != null) {
      widget.onDigit(numpadDigit);
      return KeyEventResult.handled;
    }

    // What the key writes, not where it sits: the digits are not on the
    // same keys in every keyboard layout.
    final character = event.character;
    if (character == null || character.length != 1) {
      return KeyEventResult.ignored;
    }
    if (character == '.' || character == ',') {
      widget.onDecimalPoint();
      return KeyEventResult.handled;
    }
    final digit = int.tryParse(character);
    if (digit == null) return KeyEventResult.ignored;
    widget.onDigit(digit);
    return KeyEventResult.handled;
  }

  Widget _digit(int digit) => _Key(
    onPressed: widget.enabled
        ? () => _press(() => widget.onDigit(digit))
        : null,
    child: Text('$digit'),
  );

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final onClear = widget.onClear;

    Widget row(List<Widget> keys) => Row(
      children: [
        for (final (index, key) in keys.indexed) ...[
          if (index > 0) const SizedBox(width: AppSpacing.x2),
          Expanded(child: key),
        ],
      ],
    );

    return Focus(
      focusNode: _focus,
      autofocus: widget.autofocus,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row([_digit(1), _digit(2), _digit(3)]),
          const SizedBox(height: AppSpacing.x2),
          row([_digit(4), _digit(5), _digit(6)]),
          const SizedBox(height: AppSpacing.x2),
          row([_digit(7), _digit(8), _digit(9)]),
          const SizedBox(height: AppSpacing.x2),
          row([
            _Key(
              semanticLabel: NumericKeypad.decimalPointLabel,
              onPressed: enabled ? () => _press(widget.onDecimalPoint) : null,
              child: const Text('.'),
            ),
            _digit(0),
            _Key(
              semanticLabel: NumericKeypad.deleteLabel,
              onPressed: enabled ? () => _press(widget.onDelete) : null,
              onLongPress: enabled && onClear != null
                  ? () => _press(onClear)
                  : null,
              child: const Icon(Icons.backspace_outlined, size: AppSizes.icon),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.child,
    required this.onPressed,
    this.onLongPress,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// What a screen reader says for a key whose face is not its name.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel;
    return TextButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
        textStyle: AppTypography.title.copyWith(
          fontFeatures: AppTypography.amountFeatures,
        ),
      ),
      child: label == null
          ? child
          : Semantics(
              label: label,
              child: ExcludeSemantics(child: child),
            ),
    );
  }
}
