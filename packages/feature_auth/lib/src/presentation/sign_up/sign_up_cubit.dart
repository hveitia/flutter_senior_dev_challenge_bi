import 'package:app_platform/app_platform.dart';
import 'package:bloc/bloc.dart';
import 'package:feature_auth/src/auth_telemetry.dart';
import 'package:feature_auth/src/domain/auth_repository.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/biometric_authenticator.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/domain/validators/cedula.dart';
import 'package:feature_auth/src/domain/validators/contact_validators.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_state.dart';

/// Collects the answers of the sign-up steps and submits them at the end.
///
/// The same flow completes the profile of an account that was left without
/// one, in which case it stops after the interests.
class SignUpCubit extends Cubit<SignUpState> {
  /// Flow of a new customer.
  SignUpCubit.newAccount({
    required AuthRepository repository,
    required BiometricAuthenticator biometrics,
    Telemetry telemetry = const NoopTelemetry(),
  }) : _repository = repository,
       _biometrics = biometrics,
       _telemetry = telemetry,
       super(const SignUpState(mode: SignUpMode.newAccount));

  /// Flow of an account that exists without a profile.
  ///
  /// [unsavedDraft] is what the customer typed when storing the profile
  /// failed during sign-up; the flow starts from it and says that it failed.
  SignUpCubit.completeProfile({
    required AuthRepository repository,
    required String email,
    ProfileDraft? unsavedDraft,
    Telemetry telemetry = const NoopTelemetry(),
  }) : _repository = repository,
       _biometrics = null,
       _telemetry = telemetry,
       super(
         SignUpState(
           mode: SignUpMode.completeProfile,
           email: email,
           nationalId: unsavedDraft?.nationalId ?? '',
           fullName: unsavedDraft?.fullName ?? '',
           phone: unsavedDraft?.phone ?? '',
           segment: unsavedDraft?.segment ?? Segment.fallback,
           interests: unsavedDraft?.interests ?? const {},
           failure: unsavedDraft == null ? null : AuthFailure.unavailable,
         ),
       );

  final AuthRepository _repository;
  final BiometricAuthenticator? _biometrics;
  final Telemetry _telemetry;

  /// Finds out whether the device can offer biometric unlock.
  Future<void> start() async {
    final available = await _biometrics?.isAvailable() ?? false;
    if (isClosed) return;
    emit(
      state.copyWith(
        biometricsAvailable: available,
        biometricUnlock: available,
      ),
    );
  }

  void nationalIdChanged(String value) => _edited(
    state.copyWith(
      nationalId: value,
      invalidFields: _without(SignUpField.nationalId),
    ),
  );

  void fullNameChanged(String value) => _edited(
    state.copyWith(
      fullName: value,
      invalidFields: _without(SignUpField.fullName),
    ),
  );

  void emailChanged(String value) => _edited(
    state.copyWith(
      email: value,
      invalidFields: _without(SignUpField.email),
      emailTaken: false,
    ),
  );

  void phoneChanged(String value) => _edited(
    state.copyWith(phone: value, invalidFields: _without(SignUpField.phone)),
  );

  void interestToggled(Interest interest) {
    final interests = {...state.interests};
    if (!interests.remove(interest)) interests.add(interest);
    _edited(state.copyWith(interests: interests));
  }

  void segmentSelected(Segment segment) =>
      _edited(state.copyWith(segment: segment));

  void passwordChanged(String value) =>
      _edited(state.copyWith(password: value));

  void biometricUnlockChanged({required bool enabled}) =>
      _edited(state.copyWith(biometricUnlock: enabled));

  void termsAcceptedChanged({required bool accepted}) =>
      _edited(state.copyWith(termsAccepted: accepted));

  /// An alert about the last attempt describes answers that have just
  /// changed, so it goes away with the edit.
  void _edited(SignUpState edited) =>
      emit(edited.copyWith(failure: () => null));

  /// Validates the current step and moves forward, or submits on the last.
  Future<void> next() async {
    if (state.isSubmitting) return;

    switch (state.step) {
      case SignUpStep.personalData:
        final invalid = _invalidPersonalData();
        if (invalid.isNotEmpty) {
          emit(state.copyWith(invalidFields: invalid));
          return;
        }
      case SignUpStep.interests:
        break;
      case SignUpStep.access:
        if (!state.canCreateAccount) return;
    }
    await _advance();
  }

  /// Leaves the interests step without answering it.
  Future<void> skipInterests() async {
    if (state.isSubmitting || state.step != SignUpStep.interests) return;

    _telemetry.event(AuthTelemetry.signUpInterestsSkipped);
    emit(state.copyWith(interests: const {}, segment: Segment.fallback));
    await _advance(reportStep: false);
  }

  /// Returns to the previous step. False when there is none, so the caller
  /// leaves the flow.
  bool back() {
    final index = state.mode.steps.indexOf(state.step);
    if (index == 0 || state.isSubmitting) return false;

    emit(state.copyWith(step: state.mode.steps[index - 1]));
    return true;
  }

  Future<void> _advance({bool reportStep = true}) async {
    if (state.isLastStep) {
      await _submit();
      return;
    }

    if (reportStep) {
      _telemetry.event(
        AuthTelemetry.signUpStepCompleted,
        parameters: {AuthTelemetry.stepKey: state.stepNumber},
      );
    }
    emit(
      state.copyWith(
        step: state.mode.steps[state.stepNumber],
        failure: () => null,
      ),
    );
  }

  Future<void> _submit() async {
    emit(state.copyWith(isSubmitting: true, failure: () => null));

    final profile = ProfileDraft(
      fullName: FullName.normalize(state.fullName),
      nationalId: state.nationalId.trim(),
      // Valid by the time the first step was left.
      phone: EcuadorMobile.normalize(state.phone) ?? state.phone,
      segment: state.segment,
      interests: state.interests,
    );
    final result = switch (state.mode) {
      SignUpMode.newAccount => await _repository.signUp(
        SignUpRequest(
          email: EmailAddress.normalize(state.email),
          password: state.password,
          profile: profile,
          biometricUnlock: state.biometricsAvailable && state.biometricUnlock,
        ),
      ),
      SignUpMode.completeProfile => await _repository.completeProfile(profile),
    };
    if (isClosed) return;

    // On success the session changes and the router leaves this flow.
    emit(switch (result) {
      AuthOk() => state.copyWith(isSubmitting: false),
      AuthError(failure: AuthFailure.emailAlreadyInUse) => state.copyWith(
        isSubmitting: false,
        // The email is asked on the first step; that is where it is fixed.
        step: SignUpStep.personalData,
        emailTaken: true,
      ),
      AuthError(:final failure) => state.copyWith(
        isSubmitting: false,
        failure: () => failure,
      ),
    });
  }

  Set<SignUpField> _invalidPersonalData() => {
    if (!Cedula.isValid(state.nationalId.trim())) SignUpField.nationalId,
    if (!FullName.isValid(state.fullName)) SignUpField.fullName,
    if (!EmailAddress.isValid(state.email)) SignUpField.email,
    if (!EcuadorMobile.isValid(state.phone)) SignUpField.phone,
  };

  Set<SignUpField> _without(SignUpField field) =>
      {...state.invalidFields}..remove(field);
}
