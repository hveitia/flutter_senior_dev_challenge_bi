/// Format checks for the contact details asked at sign-up. They catch typing
/// mistakes; none of them proves the detail belongs to the customer.
abstract final class EmailAddress {
  /// Longest address the mail standard allows (RFC 5321).
  static const int maxLength = 254;

  /// Something before the @, and after it at least two labels separated by
  /// single dots.
  static final RegExp _shape = RegExp(r'^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)+$');

  static String normalize(String value) => value.trim().toLowerCase();

  static bool isValid(String value) {
    final email = normalize(value);
    return email.length <= maxLength && _shape.hasMatch(email);
  }
}

/// Ecuadorian mobile numbers: ten digits starting with 09, or the same
/// number with the country code in place of the leading zero.
abstract final class EcuadorMobile {
  static const String countryCode = '593';

  static final RegExp _separators = RegExp(r'[\s-]');
  static final RegExp _local = RegExp(r'^09\d{8}$');
  static final RegExp _international = RegExp(r'^\+?5939\d{8}$');

  /// The number as ten digits starting with 09, or null when [value] is not
  /// an Ecuadorian mobile number.
  static String? normalize(String value) {
    final compact = value.replaceAll(_separators, '');
    if (_local.hasMatch(compact)) return compact;
    if (_international.hasMatch(compact)) {
      final afterCode = compact.indexOf(countryCode) + countryCode.length;
      return '0${compact.substring(afterCode)}';
    }
    return null;
  }

  static bool isValid(String value) => normalize(value) != null;
}

abstract final class FullName {
  /// Same limit the security rules enforce on the stored profile.
  static const int maxLength = 120;

  static final RegExp _spaces = RegExp(r'\s+');

  /// At least two words made of letters; hyphens and apostrophes may join
  /// parts of a name.
  static final RegExp _shape = RegExp(
    r"^\p{L}+(?:[-'’]\p{L}+)*(?: \p{L}+(?:[-'’]\p{L}+)*)+$",
    unicode: true,
  );

  /// Combining acute accent, tilde and diaeresis, by code point.
  static const int _acute = 0x0301;
  static const int _tilde = 0x0303;
  static const int _diaeresis = 0x0308;

  /// Some keyboards send an accented letter as the plain letter followed by
  /// its mark. Dart has no Unicode normalization, so the pairs Spanish uses
  /// are joined here: for each mark, the letters it attaches to and the
  /// single character that results.
  static const Map<int, Map<String, String>> _joined = {
    _acute: {
      'a': 'á', 'e': 'é', 'i': 'í', 'o': 'ó', 'u': 'ú', //
      'A': 'Á', 'E': 'É', 'I': 'Í', 'O': 'Ó', 'U': 'Ú',
    },
    _tilde: {'n': 'ñ', 'N': 'Ñ'},
    _diaeresis: {'u': 'ü', 'U': 'Ü'},
  };

  /// The name as it is stored: no outer or repeated spaces, and each
  /// accented letter as one character.
  static String normalize(String value) =>
      _joinMarks(value.trim().replaceAll(_spaces, ' '));

  static bool isValid(String value) {
    final name = normalize(value);
    return name.length <= maxLength && _shape.hasMatch(name);
  }

  /// A mark that follows a letter it does not attach to is left as it is,
  /// which [isValid] then rejects.
  static String _joinMarks(String value) {
    final joined = StringBuffer();
    String? previous;
    for (final rune in value.runes) {
      final single = previous == null ? null : _joined[rune]?[previous];
      if (single != null) {
        joined.write(single);
        previous = null;
        continue;
      }
      if (previous != null) joined.write(previous);
      previous = String.fromCharCode(rune);
    }
    if (previous != null) joined.write(previous);
    return joined.toString();
  }
}
