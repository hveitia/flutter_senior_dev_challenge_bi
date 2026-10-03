import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/presentation/login/login_cubit.dart';
import 'package:feature_auth/src/testing/auth_fakes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  late FakeAuthRepository repository;

  LoginCubit build() => LoginCubit(repository: repository);

  LoginCubit filled() => build()
    ..emailChanged(email)
    ..passwordChanged(password);

  setUp(() => repository = FakeAuthRepository());

  blocTest<LoginCubit, LoginState>(
    'keeps what the customer types',
    build: build,
    act: (cubit) => cubit
      ..emailChanged(email)
      ..passwordChanged(password),
    expect: () => [
      const LoginState(email: email),
      const LoginState(email: email, password: password),
    ],
  );

  group('submit', () {
    blocTest<LoginCubit, LoginState>(
      'marks both fields and does not call the backend when they are empty',
      build: build,
      act: (cubit) => cubit.submit(),
      expect: () => [
        const LoginState(
          invalidFields: {LoginField.email, LoginField.password},
        ),
      ],
      verify: (_) => expect(repository.signIns, isEmpty),
    );

    blocTest<LoginCubit, LoginState>(
      'marks an email that is not an address',
      build: build,
      act: (cubit) async {
        cubit
          ..emailChanged('valentina')
          ..passwordChanged(password);
        await cubit.submit();
      },
      skip: 2,
      expect: () => [
        const LoginState(
          email: 'valentina',
          password: password,
          invalidFields: {LoginField.email},
        ),
      ],
      verify: (_) => expect(repository.signIns, isEmpty),
    );

    blocTest<LoginCubit, LoginState>(
      'clears the mark of a field as soon as it is edited',
      build: build,
      act: (cubit) async {
        await cubit.submit();
        cubit.emailChanged('v');
      },
      skip: 1,
      expect: () => [
        const LoginState(email: 'v', invalidFields: {LoginField.password}),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'signs in with the normalized email and shows progress meanwhile',
      build: build,
      act: (cubit) async {
        cubit
          ..emailChanged('  Valentina.Andrade@Example.com ')
          ..passwordChanged(password);
        await cubit.submit();
      },
      skip: 2,
      expect: () => [
        const LoginState(
          email: '  Valentina.Andrade@Example.com ',
          password: password,
          isSubmitting: true,
        ),
        const LoginState(
          email: '  Valentina.Andrade@Example.com ',
          password: password,
        ),
      ],
      verify: (_) => expect(repository.signIns, [
        (email: email, password: password),
      ]),
    );

    blocTest<LoginCubit, LoginState>(
      'reports why sign-in failed and keeps what was typed',
      setUp: () => repository.signInResult = const AuthError(
        AuthFailure.invalidCredentials,
      ),
      build: filled,
      act: (cubit) => cubit.submit(),
      skip: 1,
      expect: () => [
        const LoginState(
          email: email,
          password: password,
          failure: AuthFailure.invalidCredentials,
        ),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'clears the previous failure when trying again',
      setUp: () =>
          repository.signInResult = const AuthError(AuthFailure.offline),
      build: filled,
      act: (cubit) async {
        await cubit.submit();
        repository.signInResult = const AuthOk(null);
        await cubit.submit();
      },
      skip: 2,
      expect: () => [
        const LoginState(email: email, password: password, isSubmitting: true),
        const LoginState(email: email, password: password),
      ],
    );

    for (final (field, edit) in <(String, void Function(LoginCubit))>[
      ('email', (cubit) => cubit.emailChanged('otra@example.com')),
      ('password', (cubit) => cubit.passwordChanged('Otra#2026')),
    ]) {
      test('clears the failure as soon as the $field is edited', () async {
        repository.signInResult = const AuthError(
          AuthFailure.invalidCredentials,
        );
        final cubit = filled();
        await cubit.submit();
        expect(cubit.state.failure, AuthFailure.invalidCredentials);

        edit(cubit);

        expect(cubit.state.failure, isNull);
      });
    }

    test('ignores a second submit while the first is in flight', () async {
      repository.gate = Completer<void>();
      final cubit = filled();

      unawaited(cubit.submit());
      await cubit.submit();
      repository.gate!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(repository.signIns, hasLength(1));
      await cubit.close();
    });

    test('does not emit after being closed mid-flight', () async {
      repository.gate = Completer<void>();
      final cubit = filled();

      unawaited(cubit.submit());
      await cubit.close();
      repository.gate!.complete();

      await expectLater(Future<void>.delayed(Duration.zero), completes);
    });
  });

  group('requestPasswordReset', () {
    blocTest<LoginCubit, LoginState>(
      'marks the email and sends nothing when it is not an address',
      build: build,
      act: (cubit) => cubit.requestPasswordReset(),
      expect: () => [
        const LoginState(invalidFields: {LoginField.email}),
      ],
      verify: (_) => expect(repository.passwordResets, isEmpty),
    );

    blocTest<LoginCubit, LoginState>(
      'asks for the reset and confirms it',
      build: () => build()..emailChanged(email),
      act: (cubit) => cubit.requestPasswordReset(),
      expect: () => [
        const LoginState(email: email, reset: PasswordResetStatus.sending),
        const LoginState(email: email, reset: PasswordResetStatus.sent),
      ],
      verify: (_) => expect(repository.passwordResets, [email]),
    );

    blocTest<LoginCubit, LoginState>(
      'reports the failure and does not confirm when the request did not '
      'leave the device',
      setUp: () =>
          repository.passwordResetResult = const AuthError(AuthFailure.offline),
      build: () => build()..emailChanged(email),
      act: (cubit) => cubit.requestPasswordReset(),
      skip: 1,
      expect: () => [
        const LoginState(email: email, failure: AuthFailure.offline),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'drops the confirmation once the customer edits the email',
      build: () => build()..emailChanged(email),
      act: (cubit) async {
        await cubit.requestPasswordReset();
        cubit.emailChanged('otra@example.com');
      },
      skip: 2,
      expect: () => [const LoginState(email: 'otra@example.com')],
    );
  });
}
