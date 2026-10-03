/// Why an access operation did not go through, in the terms a screen needs
/// to choose its message.
enum AuthFailure {
  /// Email or password rejected. Never says which of the two.
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  offline,

  /// The backend did not answer in time, or asked to try again later.
  unavailable,
  unexpected,
}

sealed class AuthResult<T> {
  const AuthResult();
}

final class AuthOk<T> extends AuthResult<T> {
  const AuthOk(this.value);

  final T value;
}

final class AuthError<T> extends AuthResult<T> {
  const AuthError(this.failure);

  final AuthFailure failure;
}
