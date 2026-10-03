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

  static String normalize(String value) =>
      value.trim().replaceAll(_spaces, ' ');

  static bool isValid(String value) {
    final name = normalize(value);
    return name.length <= maxLength && _shape.hasMatch(name);
  }
}
