import 'package:equatable/equatable.dart';

/// Customer segment. Its [id] is the key of the segment in the published
/// home configuration, so the two must stay in step.
enum Segment {
  starting,
  family,
  wealth
  ;

  /// Segment of a customer who did not choose one.
  static const Segment fallback = Segment.starting;

  String get id => name;

  static Segment fromId(Object? id) =>
      values.firstWhere((segment) => segment.id == id, orElse: () => fallback);
}

/// What the customer said they care about, used to personalize the home.
enum Interest {
  saving,
  investing,
  travel,
  billPayments,
  credit,
  insurance,
  business
  ;

  String get id => name;

  static Interest? fromId(Object? id) {
    for (final interest in values) {
      if (interest.id == id) return interest;
    }
    return null;
  }
}

/// The account in the identity provider: who is signed in, nothing else.
final class AuthAccount extends Equatable {
  const AuthAccount({required this.uid, required this.email});

  final String uid;
  final String email;

  @override
  List<Object?> get props => [uid, email];
}

/// What the customer tells us at sign-up, before it is stored.
final class ProfileDraft extends Equatable {
  const ProfileDraft({
    required this.fullName,
    required this.nationalId,
    required this.phone,
    this.segment = Segment.fallback,
    this.interests = const {},
  });

  final String fullName;

  /// Cédula. Personal data: never logged, reported or cached on the device.
  final String nationalId;
  final String phone;
  final Segment segment;
  final Set<Interest> interests;

  @override
  List<Object?> get props => [fullName, nationalId, phone, segment, interests];
}

/// The stored profile of a signed-in customer.
final class UserProfile extends Equatable {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.nationalId,
    required this.phone,
    required this.segment,
    required this.interests,
  });

  UserProfile.fromDraft(AuthAccount account, ProfileDraft draft)
    : this(
        uid: account.uid,
        email: account.email,
        fullName: draft.fullName,
        nationalId: draft.nationalId,
        phone: draft.phone,
        segment: draft.segment,
        interests: draft.interests,
      );

  final String uid;
  final String email;
  final String fullName;
  final String nationalId;
  final String phone;
  final Segment segment;
  final Set<Interest> interests;

  /// The name the app greets the customer with.
  String get firstName => fullName.split(' ').first;

  /// This profile with what personalizes the home changed. Who the customer
  /// is stays as it was.
  UserProfile withPreferences({
    required Segment segment,
    required Set<Interest> interests,
  }) => UserProfile(
    uid: uid,
    email: email,
    fullName: fullName,
    nationalId: nationalId,
    phone: phone,
    segment: segment,
    interests: interests,
  );

  @override
  List<Object?> get props => [
    uid,
    email,
    fullName,
    nationalId,
    phone,
    segment,
    interests,
  ];
}
