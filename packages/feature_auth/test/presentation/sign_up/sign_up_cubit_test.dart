import 'dart:async';

import 'package:app_platform/testing.dart';
import 'package:feature_auth/src/auth_telemetry.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/domain/validators/password_policy.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_cubit.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_state.dart';
import 'package:feature_auth/src/testing/auth_fakes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  late FakeAuthRepository repository;
  late FakeBiometricAuthenticator biometrics;
  late InMemoryTelemetry telemetry;

  SignUpCubit newAccount() => SignUpCubit.newAccount(
    repository: repository,
    biometrics: biometrics,
    telemetry: telemetry,
  );

  void fillPersonalData(SignUpCubit cubit) => cubit
    ..nationalIdChanged(draft.nationalId)
    ..fullNameChanged(draft.fullName)
    ..emailChanged(email)
    ..phoneChanged('099 123 4567');

  void fillInterests(SignUpCubit cubit) => cubit
    ..interestToggled(Interest.saving)
    ..interestToggled(Interest.travel)
    ..segmentSelected(Segment.family);

  void fillAccess(SignUpCubit cubit) => cubit
    ..passwordChanged(password)
    ..termsAcceptedChanged(accepted: true);

  /// A cubit on the last step with every answer given.
  Future<SignUpCubit> readyToCreate() async {
    final cubit = newAccount();
    await cubit.start();
    fillPersonalData(cubit);
    await cubit.next();
    fillInterests(cubit);
    await cubit.next();
    fillAccess(cubit);
    return cubit;
  }

  setUp(() {
    repository = FakeAuthRepository();
    biometrics = FakeBiometricAuthenticator();
    telemetry = InMemoryTelemetry();
  });

  group('a new account', () {
    test('starts on the first of three steps', () {
      final state = newAccount().state;

      expect(state.step, SignUpStep.personalData);
      expect(state.stepNumber, 1);
      expect(state.totalSteps, 3);
    });

    test(
      'offers biometric unlock, switched on, when the device has it',
      () async {
        final cubit = newAccount();

        await cubit.start();

        expect(cubit.state.biometricsAvailable, isTrue);
        expect(cubit.state.biometricUnlock, isTrue);
      },
    );

    test('does not offer biometric unlock when the device lacks it', () async {
      biometrics.available = false;
      final cubit = newAccount();

      await cubit.start();

      expect(cubit.state.biometricsAvailable, isFalse);
      expect(cubit.state.biometricUnlock, isFalse);
    });

    group('step 1', () {
      test('marks every field that is wrong and stays on the step', () async {
        final cubit = newAccount()
          ..nationalIdChanged('123456789')
          ..fullNameChanged('Valentina')
          ..emailChanged('valentina@')
          ..phoneChanged('022345678');

        await cubit.next();

        expect(cubit.state.step, SignUpStep.personalData);
        expect(cubit.state.invalidFields, SignUpField.values.toSet());
      });

      test('marks only the cédula when its check digit is wrong', () async {
        final cubit = newAccount();
        fillPersonalData(cubit);
        cubit.nationalIdChanged('1710034064');

        await cubit.next();

        expect(cubit.state.invalidFields, {SignUpField.nationalId});
      });

      test('clears the mark of a field when the customer edits it', () async {
        final cubit = newAccount();
        await cubit.next();

        cubit.phoneChanged('0');

        expect(
          cubit.state.invalidFields,
          isNot(contains(SignUpField.phone)),
        );
        expect(cubit.state.invalidFields, contains(SignUpField.email));
      });

      test('moves to the interests when everything is valid', () async {
        final cubit = newAccount();
        fillPersonalData(cubit);

        await cubit.next();

        expect(cubit.state.step, SignUpStep.interests);
        expect(cubit.state.stepNumber, 2);
        expect(cubit.state.invalidFields, isEmpty);
      });
    });

    group('step 2', () {
      late SignUpCubit cubit;

      setUp(() async {
        cubit = newAccount();
        fillPersonalData(cubit);
        await cubit.next();
      });

      test('starts with the default segment and no interests', () {
        expect(cubit.state.segment, Segment.starting);
        expect(cubit.state.interests, isEmpty);
      });

      test('toggles an interest on and off', () {
        cubit.interestToggled(Interest.saving);
        expect(cubit.state.interests, {Interest.saving});

        cubit.interestToggled(Interest.saving);
        expect(cubit.state.interests, isEmpty);
      });

      test('keeps a single segment', () {
        cubit
          ..segmentSelected(Segment.family)
          ..segmentSelected(Segment.wealth);

        expect(cubit.state.segment, Segment.wealth);
      });

      test('moves to the access step', () async {
        await cubit.next();

        expect(cubit.state.step, SignUpStep.access);
        expect(cubit.state.isLastStep, isTrue);
      });

      test('skipping discards the answers and moves on', () async {
        fillInterests(cubit);

        await cubit.skipInterests();

        expect(cubit.state.step, SignUpStep.access);
        expect(cubit.state.segment, Segment.starting);
        expect(cubit.state.interests, isEmpty);
      });
    });

    group('going back', () {
      test('returns to the previous step with every answer kept', () async {
        final cubit = newAccount();
        fillPersonalData(cubit);
        await cubit.next();
        fillInterests(cubit);
        await cubit.next();
        cubit.passwordChanged(password);

        expect(cubit.back(), isTrue);
        expect(cubit.back(), isTrue);

        final state = cubit.state;
        expect(state.step, SignUpStep.personalData);
        expect(state.nationalId, draft.nationalId);
        expect(state.fullName, draft.fullName);
        expect(state.email, email);
        expect(state.interests, {Interest.saving, Interest.travel});
        expect(state.segment, Segment.family);
        expect(state.password, password);
      });

      test('leaves the flow from the first step', () {
        final cubit = newAccount();

        expect(cubit.back(), isFalse);
        expect(cubit.state.step, SignUpStep.personalData);
      });
    });

    group('step 3', () {
      test(
        'reports which password requirements are met as it is typed',
        () async {
          final cubit = await readyToCreate();

          cubit.passwordChanged('Segura');

          expect(cubit.state.passwordRequirementsMet, {
            PasswordRequirement.uppercase,
          });
        },
      );

      test('cannot create the account until the password complies and the '
          'terms are accepted', () async {
        final cubit = await readyToCreate();
        expect(cubit.state.canCreateAccount, isTrue);

        cubit.termsAcceptedChanged(accepted: false);
        expect(cubit.state.canCreateAccount, isFalse);

        cubit
          ..termsAcceptedChanged(accepted: true)
          ..passwordChanged('segura');
        expect(cubit.state.canCreateAccount, isFalse);
      });

      test(
        'does nothing when asked to create the account before then',
        () async {
          final cubit = await readyToCreate();
          cubit.termsAcceptedChanged(accepted: false);

          await cubit.next();

          expect(repository.signUps, isEmpty);
        },
      );

      test('creates the account with the normalized answers', () async {
        final cubit = newAccount();
        await cubit.start();
        cubit
          ..nationalIdChanged(draft.nationalId)
          ..fullNameChanged('  Valentina   Andrade ')
          ..emailChanged(' Valentina.Andrade@Example.com')
          ..phoneChanged('+593 99 123 4567');
        await cubit.next();
        fillInterests(cubit);
        await cubit.next();
        fillAccess(cubit);

        await cubit.next();

        final request = repository.signUps.single;
        expect(request.email, email);
        expect(request.password, password);
        expect(request.profile, draft);
        expect(request.biometricUnlock, isTrue);
      });

      test('does not ask for biometric unlock when the customer switched it '
          'off', () async {
        final cubit = await readyToCreate();
        cubit.biometricUnlockChanged(enabled: false);

        await cubit.next();

        expect(repository.signUps.single.biometricUnlock, isFalse);
      });

      test('shows progress while the account is being created', () async {
        repository.gate = Completer<void>();
        final cubit = await readyToCreate();

        unawaited(cubit.next());
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.isSubmitting, isTrue);

        repository.gate!.complete();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.isSubmitting, isFalse);
      });

      test('ignores a second request while the first is in flight', () async {
        repository.gate = Completer<void>();
        final cubit = await readyToCreate();

        unawaited(cubit.next());
        await cubit.next();
        repository.gate!.complete();
        await Future<void>.delayed(Duration.zero);

        expect(repository.signUps, hasLength(1));
      });

      test('returns to the first step and marks the email when it already '
          'has an account', () async {
        repository.signUpResult = const AuthError(
          AuthFailure.emailAlreadyInUse,
        );
        final cubit = await readyToCreate();

        await cubit.next();

        expect(cubit.state.step, SignUpStep.personalData);
        expect(cubit.state.emailTaken, isTrue);
        expect(cubit.state.failure, isNull);
        expect(cubit.state.password, password);
      });

      test('forgets that the email was taken once it is edited', () async {
        repository.signUpResult = const AuthError(
          AuthFailure.emailAlreadyInUse,
        );
        final cubit = await readyToCreate();
        await cubit.next();

        cubit.emailChanged('otra@example.com');

        expect(cubit.state.emailTaken, isFalse);
      });

      test(
        'reports any other failure on the same step, answers kept',
        () async {
          repository.signUpResult = const AuthError(AuthFailure.offline);
          final cubit = await readyToCreate();

          await cubit.next();

          expect(cubit.state.step, SignUpStep.access);
          expect(cubit.state.failure, AuthFailure.offline);
          expect(cubit.state.password, password);
        },
      );

      test('clears the failure when trying again', () async {
        repository
          ..signUpResult = const AuthError(AuthFailure.offline)
          ..gate = null;
        final cubit = await readyToCreate();
        await cubit.next();
        repository
          ..signUpResult = const AuthOk(null)
          ..gate = Completer<void>();

        unawaited(cubit.next());
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.failure, isNull);
        repository.gate!.complete();
      });
    });

    test('does not emit after being closed mid-flight', () async {
      repository.gate = Completer<void>();
      final cubit = await readyToCreate();

      unawaited(cubit.next());
      await cubit.close();
      repository.gate!.complete();

      await expectLater(Future<void>.delayed(Duration.zero), completes);
    });
  });

  group('completing a profile', () {
    SignUpCubit completion({ProfileDraft? unsavedDraft}) =>
        SignUpCubit.completeProfile(
          repository: repository,
          email: email,
          unsavedDraft: unsavedDraft,
          telemetry: telemetry,
        );

    test('has two steps and the account email already filled in', () {
      final state = completion().state;

      expect(state.totalSteps, 2);
      expect(state.email, email);
      expect(state.failure, isNull);
    });

    test('starts from what the customer typed when storing it failed, and '
        'says that it failed', () {
      final state = completion(unsavedDraft: draft).state;

      expect(state.nationalId, draft.nationalId);
      expect(state.fullName, draft.fullName);
      expect(state.phone, draft.phone);
      expect(state.segment, draft.segment);
      expect(state.interests, draft.interests);
      expect(state.failure, AuthFailure.unavailable);
    });

    test('stores the profile at the end of the interests step', () async {
      final cubit = completion();
      fillPersonalData(cubit);
      await cubit.next();
      fillInterests(cubit);
      expect(cubit.state.isLastStep, isTrue);

      await cubit.next();

      expect(repository.completedProfiles, [draft]);
      expect(repository.signUps, isEmpty);
    });

    test('stores the profile with the default segment when skipping', () async {
      final cubit = completion();
      fillPersonalData(cubit);
      await cubit.next();
      fillInterests(cubit);

      await cubit.skipInterests();

      expect(repository.completedProfiles.single.segment, Segment.starting);
      expect(repository.completedProfiles.single.interests, isEmpty);
    });

    test('reports the failure and stays on the step', () async {
      repository.completeProfileResult = const AuthError(AuthFailure.offline);
      final cubit = completion();
      fillPersonalData(cubit);
      await cubit.next();

      await cubit.next();

      expect(cubit.state.step, SignUpStep.interests);
      expect(cubit.state.failure, AuthFailure.offline);
    });
  });

  group('telemetry', () {
    test('reports each completed step by its number only', () async {
      final cubit = newAccount();
      fillPersonalData(cubit);
      await cubit.next();
      fillInterests(cubit);
      await cubit.next();

      expect(
        [for (final event in telemetry.events) event.name],
        [AuthTelemetry.signUpStepCompleted, AuthTelemetry.signUpStepCompleted],
      );
      expect(
        [for (final event in telemetry.events) event.parameters],
        [
          {AuthTelemetry.stepKey: 1},
          {AuthTelemetry.stepKey: 2},
        ],
      );
    });

    test('reports that the interests were skipped', () async {
      final cubit = newAccount();
      fillPersonalData(cubit);
      await cubit.next();

      await cubit.skipInterests();

      expect(telemetry.events.last.name, AuthTelemetry.signUpInterestsSkipped);
      expect(telemetry.events.last.parameters, isEmpty);
    });

    test('does not report a step the customer could not complete', () async {
      final cubit = newAccount();

      await cubit.next();

      expect(telemetry.events, isEmpty);
    });

    test('never contains what the customer typed', () async {
      final cubit = await readyToCreate();
      await cubit.next();

      final everything = [
        for (final event in telemetry.events)
          '${event.name} ${event.parameters}',
        for (final entry in telemetry.logs) '${entry.message} ${entry.context}',
      ].join('\n');

      for (final datum in personalData) {
        expect(everything, isNot(contains(datum)));
      }
    });
  });
}
