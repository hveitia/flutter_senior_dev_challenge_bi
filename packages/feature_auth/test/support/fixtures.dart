import 'package:feature_auth/src/domain/auth_repository.dart';
import 'package:feature_auth/src/domain/user_profile.dart';

const String email = 'valentina.andrade@example.com';
const String password = 'Segura#2026';

const ProfileDraft draft = ProfileDraft(
  fullName: 'Valentina Andrade',
  nationalId: '1710034065',
  phone: '0991234567',
  segment: Segment.family,
  interests: {Interest.saving, Interest.travel},
);

const SignUpRequest signUpRequest = SignUpRequest(
  email: email,
  password: password,
  profile: draft,
  biometricUnlock: false,
);

/// Everything in the fixtures that identifies a person. No report may
/// contain any of it.
const List<String> personalData = [
  email,
  'valentina',
  'Andrade',
  '1710034065',
  '0991234567',
  password,
];
