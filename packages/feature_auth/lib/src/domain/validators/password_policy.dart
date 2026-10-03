/// What a password must contain. The order is the one shown to the customer.
enum PasswordRequirement { minLength, uppercase, number, symbol }

abstract final class PasswordPolicy {
  static const int minLength = 8;

  static final RegExp _uppercase = RegExp(r'\p{Lu}', unicode: true);
  static final RegExp _number = RegExp(r'\d');

  /// Anything that is not a letter, a digit or white space.
  static final RegExp _symbol = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

  /// Requirements [password] already satisfies.
  static Set<PasswordRequirement> met(String password) => {
    if (password.length >= minLength) PasswordRequirement.minLength,
    if (_uppercase.hasMatch(password)) PasswordRequirement.uppercase,
    if (_number.hasMatch(password)) PasswordRequirement.number,
    if (_symbol.hasMatch(password)) PasswordRequirement.symbol,
  };

  static bool isSatisfiedBy(String password) =>
      met(password).length == PasswordRequirement.values.length;
}
