/// Ecuadorian national identity number (cédula) of a natural person.
abstract final class Cedula {
  static const int length = 10;

  /// Provinces are numbered 01 to 24.
  static const int lastProvince = 24;

  /// Code issued to Ecuadorians registered abroad.
  static const int abroadCode = 30;

  /// The third digit of a natural person's number is 0 to 5. Higher values
  /// identify companies and public bodies, which use a different check.
  static const int maxThirdDigit = 5;

  static final RegExp _digits = RegExp(r'^\d{10}$');

  /// Whether [value] is a well-formed cédula: ten digits, a real province
  /// code, a natural-person third digit and a matching check digit.
  ///
  /// It proves the number is plausible, not that it was issued to anyone.
  static bool isValid(String value) {
    if (!_digits.hasMatch(value)) return false;

    final digits = [for (final unit in value.codeUnits) unit - _zero];
    final province = digits[0] * 10 + digits[1];
    final knownProvince =
        (province >= 1 && province <= lastProvince) || province == abroadCode;
    if (!knownProvince) return false;
    if (digits[2] > maxThirdDigit) return false;

    return _checkDigit(digits) == digits.last;
  }

  static const int _zero = 0x30;

  /// Modulo 10 over the first nine digits: those in odd positions are
  /// doubled, and a doubled value above 9 has 9 subtracted.
  static int _checkDigit(List<int> digits) {
    var sum = 0;
    for (var index = 0; index < length - 1; index++) {
      var value = digits[index];
      if (index.isEven) {
        value *= 2;
        if (value > 9) value -= 9;
      }
      sum += value;
    }
    return (10 - sum % 10) % 10;
  }
}
