import 'package:flutter/foundation.dart';

/// When an amount carries an explicit sign.
enum AmountSignDisplay {
  /// Only negative amounts are signed. Used for balances.
  negativeOnly,

  /// Positive amounts get a plus as well. Used for movements, where the
  /// direction of the money is the information.
  always,
}

/// An amount split into the parts the UI renders differently.
@immutable
class FormattedAmount {
  const FormattedAmount({
    required this.sign,
    required this.integer,
    required this.cents,
  });

  /// Empty, or the sign followed by a no-break space.
  final String sign;

  /// Currency symbol and grouped integer part, for example `$4,820`.
  final String integer;

  /// Decimal separator and two digits, for example `.35`.
  final String cents;

  String get text => '$sign$integer$cents';
}

const String _minus = '\u2212';
const String _noBreakSpace = '\u00A0';

/// Formats [cents] as US dollars: `$4,820.35`.
///
/// The format is a product decision, not a locale preference: every customer
/// sees comma grouping and a dot before the cents whatever the device
/// language is. That is why this does not take a locale.
///
/// Amounts are integers in minor units so they never go through floating
/// point arithmetic.
FormattedAmount formatAmount(
  int cents, {
  AmountSignDisplay signDisplay = AmountSignDisplay.negativeOnly,
}) {
  final absolute = cents.abs();
  final units = (absolute ~/ 100).toString();
  final fraction = (absolute % 100).toString().padLeft(2, '0');

  final grouped = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    if (i > 0 && (units.length - i) % 3 == 0) grouped.write(',');
    grouped.write(units[i]);
  }

  final sign = switch (cents) {
    < 0 => '$_minus$_noBreakSpace',
    > 0 when signDisplay == AmountSignDisplay.always => '+$_noBreakSpace',
    _ => '',
  };

  return FormattedAmount(
    sign: sign,
    integer: '\$$grouped',
    cents: '.$fraction',
  );
}

/// Spoken form of [cents] in Spanish, for example
/// `4820 dólares con 35 centavos`.
///
/// Screen readers handle a plain number correctly but read `$4,820.35`
/// symbol by symbol, so the visual string is never used as the label.
String amountSemanticLabel(
  int cents, {
  AmountSignDisplay signDisplay = AmountSignDisplay.negativeOnly,
}) {
  final absolute = cents.abs();
  final units = absolute ~/ 100;
  final fraction = absolute % 100;

  final prefix = switch (cents) {
    < 0 => 'menos ',
    > 0 when signDisplay == AmountSignDisplay.always => 'más ',
    _ => '',
  };
  final dollars = units == 1 ? '1 dólar' : '$units dólares';
  final rest = switch (fraction) {
    0 => '',
    1 => ' con 1 centavo',
    _ => ' con $fraction centavos',
  };

  return '$prefix$dollars$rest';
}
