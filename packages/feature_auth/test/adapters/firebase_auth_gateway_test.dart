import 'package:app_platform/app_platform.dart';
import 'package:feature_auth/src/adapters/firebase_auth_gateway.dart';
import 'package:feature_auth/src/data/ports.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fixtures.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUser extends Mock implements User {}

void main() {
  late _MockFirebaseAuth auth;
  late FirebaseAuthGateway gateway;
  late _MockUser user;

  FirebaseAuthException failure(String code) =>
      FirebaseAuthException(code: code, message: 'details about $email');

  Matcher rejectedAs(AuthFailure reason) => throwsA(
    isA<AuthRejected>().having((error) => error.reason, 'reason', reason),
  );

  void whenSignIn(Future<UserCredential> Function() answer) {
    when(
      () => auth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => answer());
  }

  void whenCreate(Future<UserCredential> Function() answer) {
    when(
      () => auth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => answer());
  }

  void whenReset(Future<void> Function() answer) {
    when(
      () => auth.sendPasswordResetEmail(email: any(named: 'email')),
    ).thenAnswer((_) => answer());
  }

  Future<UserCredential> credential() async {
    final credential = _MockUserCredential();
    when(() => credential.user).thenReturn(user);
    return credential;
  }

  setUp(() {
    auth = _MockFirebaseAuth();
    gateway = FirebaseAuthGateway(auth);
    user = _MockUser();
    when(() => user.uid).thenReturn('uid-1');
    when(() => user.email).thenReturn(email);
  });

  group('restoredAccount', () {
    test('is the account of the first auth state the SDK reports', () async {
      when(auth.authStateChanges).thenAnswer((_) => Stream.value(user));

      expect(
        await gateway.restoredAccount(),
        const AuthAccount(uid: 'uid-1', email: email),
      );
    });

    test('is null when the SDK reports nobody', () async {
      when(auth.authStateChanges).thenAnswer((_) => Stream.value(null));

      expect(await gateway.restoredAccount(), isNull);
    });
  });

  group('signIn', () {
    test('returns the account', () async {
      whenSignIn(credential);

      expect(
        await gateway.signIn(email: email, password: password),
        const AuthAccount(uid: 'uid-1', email: email),
      );
      verify(
        () => auth.signInWithEmailAndPassword(email: email, password: password),
      ).called(1);
    });

    for (final code in [
      'invalid-credential',
      'wrong-password',
      'user-not-found',
      'user-disabled',
      'invalid-email',
    ]) {
      test('folds "$code" into invalid credentials', () {
        whenSignIn(() async => throw failure(code));

        expect(
          gateway.signIn(email: email, password: password),
          rejectedAs(AuthFailure.invalidCredentials),
        );
      });
    }

    test('reports a missing network as offline', () {
      whenSignIn(() async => throw failure('network-request-failed'));

      expect(
        gateway.signIn(email: email, password: password),
        throwsA(isA<OfflineFailure>()),
      );
    });

    test('reports throttling as a rejection, so it is not retried', () {
      whenSignIn(() async => throw failure('too-many-requests'));

      expect(
        gateway.signIn(email: email, password: password),
        rejectedAs(AuthFailure.unavailable),
      );
    });

    test('lets any other error through untouched', () {
      whenSignIn(() async => throw failure('internal-error'));

      expect(
        gateway.signIn(email: email, password: password),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('createAccount', () {
    test('returns the new account', () async {
      whenCreate(credential);

      expect(
        await gateway.createAccount(email: email, password: password),
        const AuthAccount(uid: 'uid-1', email: email),
      );
    });

    test('says when the email already has an account', () {
      whenCreate(() async => throw failure('email-already-in-use'));

      expect(
        gateway.createAccount(email: email, password: password),
        rejectedAs(AuthFailure.emailAlreadyInUse),
      );
    });

    test('says when the provider finds the password weak', () {
      whenCreate(() async => throw failure('weak-password'));

      expect(
        gateway.createAccount(email: email, password: password),
        rejectedAs(AuthFailure.weakPassword),
      );
    });

    test('reports a missing network as offline', () {
      whenCreate(() async => throw failure('network-request-failed'));

      expect(
        gateway.createAccount(email: email, password: password),
        throwsA(isA<OfflineFailure>()),
      );
    });
  });

  group('sendPasswordReset', () {
    test('asks the provider to send the email', () async {
      whenReset(() async {});

      await gateway.sendPasswordReset(email);

      verify(() => auth.sendPasswordResetEmail(email: email)).called(1);
    });

    test('answers an unknown address exactly like a known one', () async {
      whenReset(() async => throw failure('user-not-found'));

      await expectLater(gateway.sendPasswordReset(email), completes);
    });

    test('reports a missing network as offline', () {
      whenReset(() async => throw failure('network-request-failed'));

      expect(
        gateway.sendPasswordReset(email),
        throwsA(isA<OfflineFailure>()),
      );
    });
  });

  test('signs out of the SDK', () async {
    when(auth.signOut).thenAnswer((_) async {});

    await gateway.signOut();

    verify(auth.signOut).called(1);
  });
}
