/// Everything the home itself says to the customer. What each module says
/// belongs to the package that owns the module.
abstract final class HomeStrings {
  static String greeting(String firstName) =>
      firstName.isEmpty ? 'Hola' : 'Hola, $firstName';

  static const String nothingToShowTitle = 'No pudimos conectarnos';
  static const String nothingToShowMessage =
      'Revisa tu conexión e intenta de nuevo.';
  static const String retry = 'Reintentar';

  static const String emptyTitle = 'Estamos preparando tu inicio';
  static const String emptyMessage =
      'Mientras tanto, tus cuentas están en la sección Cuentas.';
}

/// The initials shown in the avatar: the first letter of the first two
/// words of [fullName], in capitals. Empty when there is no name.
String initialsOf(String fullName) {
  final words = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where(
        (word) => word.isNotEmpty,
      );
  return words
      .take(2)
      .map((word) => String.fromCharCode(word.runes.first).toUpperCase())
      .join();
}
