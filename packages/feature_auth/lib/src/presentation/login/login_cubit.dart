import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_auth/src/domain/auth_repository.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/validators/contact_validators.dart';

enum LoginField { email, password }

enum PasswordResetStatus { idle, sending, sent }

final class LoginState extends Equatable {
  const LoginState({
    this.email = '',
    this.password = '',
    this.invalidFields = const {},
    this.isSubmitting = false,
    this.failure,
    this.reset = PasswordResetStatus.idle,
  });

  final String email;
  final String password;

  /// Fields to mark as wrong. Filled when the customer tries to continue,
  /// not while they are still typing.
  final Set<LoginField> invalidFields;
  final bool isSubmitting;

  /// Why the last sign-in or reset request did not go through.
  final AuthFailure? failure;
  final PasswordResetStatus reset;

  LoginState copyWith({
    String? email,
    String? password,
    Set<LoginField>? invalidFields,
    bool? isSubmitting,
    AuthFailure? Function()? failure,
    PasswordResetStatus? reset,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      invalidFields: invalidFields ?? this.invalidFields,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: failure == null ? this.failure : failure(),
      reset: reset ?? this.reset,
    );
  }

  @override
  List<Object?> get props => [
    email,
    password,
    invalidFields,
    isSubmitting,
    failure,
    reset,
  ];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required AuthRepository repository})
    : _repository = repository,
      super(const LoginState());

  final AuthRepository _repository;

  void emailChanged(String value) {
    emit(
      state.copyWith(
        email: value,
        invalidFields: _without(LoginField.email),
        failure: _cleared,
        // A confirmation refers to the address it was sent to.
        reset: PasswordResetStatus.idle,
      ),
    );
  }

  void passwordChanged(String value) {
    emit(
      state.copyWith(
        password: value,
        invalidFields: _without(LoginField.password),
        failure: _cleared,
      ),
    );
  }

  /// An alert about the last attempt describes what was typed then, so it
  /// goes away as soon as the customer edits a field.
  static AuthFailure? _cleared() => null;

  Future<void> submit() async {
    if (state.isSubmitting) return;

    final invalid = {
      if (!EmailAddress.isValid(state.email)) LoginField.email,
      if (state.password.isEmpty) LoginField.password,
    };
    if (invalid.isNotEmpty) {
      emit(state.copyWith(invalidFields: invalid));
      return;
    }

    emit(state.copyWith(isSubmitting: true, failure: () => null));
    final result = await _repository.signIn(
      email: EmailAddress.normalize(state.email),
      password: state.password,
    );
    if (isClosed) return;

    // On success the session changes and the router leaves this screen.
    emit(
      state.copyWith(
        isSubmitting: false,
        failure: () => switch (result) {
          AuthOk() => null,
          AuthError(:final failure) => failure,
        },
      ),
    );
  }

  Future<void> requestPasswordReset() async {
    if (state.reset == PasswordResetStatus.sending) return;

    if (!EmailAddress.isValid(state.email)) {
      emit(state.copyWith(invalidFields: {LoginField.email}));
      return;
    }

    emit(
      state.copyWith(reset: PasswordResetStatus.sending, failure: () => null),
    );
    final result = await _repository.sendPasswordReset(
      EmailAddress.normalize(state.email),
    );
    if (isClosed) return;

    emit(switch (result) {
      AuthOk() => state.copyWith(reset: PasswordResetStatus.sent),
      AuthError(:final failure) => state.copyWith(
        reset: PasswordResetStatus.idle,
        failure: () => failure,
      ),
    });
  }

  Set<LoginField> _without(LoginField field) =>
      {...state.invalidFields}..remove(field);
}
