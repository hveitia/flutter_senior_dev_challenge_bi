import 'package:equatable/equatable.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/domain/validators/password_policy.dart';

/// What the flow is collecting data for.
enum SignUpMode {
  /// A new customer: three steps, ending with the password.
  newAccount([
    SignUpStep.personalData,
    SignUpStep.interests,
    SignUpStep.access,
  ]),

  /// An account that exists without a profile: the password is already set,
  /// so the flow ends after the interests.
  completeProfile([SignUpStep.personalData, SignUpStep.interests])
  ;

  const SignUpMode(this.steps);

  final List<SignUpStep> steps;
}

enum SignUpStep { personalData, interests, access }

enum SignUpField { nationalId, fullName, email, phone }

final class SignUpState extends Equatable {
  const SignUpState({
    required this.mode,
    this.step = SignUpStep.personalData,
    this.nationalId = '',
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.interests = const {},
    this.segment = Segment.fallback,
    this.password = '',
    this.biometricsAvailable = false,
    this.biometricUnlock = false,
    this.termsAccepted = false,
    this.invalidFields = const {},
    this.emailTaken = false,
    this.isSubmitting = false,
    this.failure,
  });

  final SignUpMode mode;
  final SignUpStep step;
  final String nationalId;
  final String fullName;
  final String email;
  final String phone;
  final Set<Interest> interests;
  final Segment segment;
  final String password;

  /// Whether the device can do a biometric check at all. The switch is
  /// offered only then.
  final bool biometricsAvailable;
  final bool biometricUnlock;
  final bool termsAccepted;

  /// Fields to mark as wrong. Filled when the customer tries to continue.
  final Set<SignUpField> invalidFields;

  /// The backend answered that the email already has an account.
  final bool emailTaken;
  final bool isSubmitting;

  /// Why creating the account or storing the profile did not go through.
  final AuthFailure? failure;

  /// Position of [step] counting from one, as shown to the customer.
  int get stepNumber => mode.steps.indexOf(step) + 1;

  int get totalSteps => mode.steps.length;

  bool get isLastStep => step == mode.steps.last;

  Set<PasswordRequirement> get passwordRequirementsMet =>
      PasswordPolicy.met(password);

  bool get canCreateAccount =>
      PasswordPolicy.isSatisfiedBy(password) && termsAccepted;

  SignUpState copyWith({
    SignUpStep? step,
    String? nationalId,
    String? fullName,
    String? email,
    String? phone,
    Set<Interest>? interests,
    Segment? segment,
    String? password,
    bool? biometricsAvailable,
    bool? biometricUnlock,
    bool? termsAccepted,
    Set<SignUpField>? invalidFields,
    bool? emailTaken,
    bool? isSubmitting,
    AuthFailure? Function()? failure,
  }) {
    return SignUpState(
      mode: mode,
      step: step ?? this.step,
      nationalId: nationalId ?? this.nationalId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      interests: interests ?? this.interests,
      segment: segment ?? this.segment,
      password: password ?? this.password,
      biometricsAvailable: biometricsAvailable ?? this.biometricsAvailable,
      biometricUnlock: biometricUnlock ?? this.biometricUnlock,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      invalidFields: invalidFields ?? this.invalidFields,
      emailTaken: emailTaken ?? this.emailTaken,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: failure == null ? this.failure : failure(),
    );
  }

  @override
  List<Object?> get props => [
    mode,
    step,
    nationalId,
    fullName,
    email,
    phone,
    interests,
    segment,
    password,
    biometricsAvailable,
    biometricUnlock,
    termsAccepted,
    invalidFields,
    emailTaken,
    isSubmitting,
    failure,
  ];
}
