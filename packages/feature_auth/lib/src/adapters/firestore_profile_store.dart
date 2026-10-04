import 'package:app_platform/app_platform.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_auth/src/data/ports.dart';
import 'package:feature_auth/src/domain/user_profile.dart';

/// Field names of a profile document. The security rules in
/// `firebase/firestore.rules` list the same names; they change together.
abstract final class ProfileFields {
  static const String fullName = 'fullName';
  static const String nationalId = 'nationalId';
  static const String email = 'email';
  static const String phone = 'phone';
  static const String segment = 'segment';
  static const String interests = 'interests';
  static const String createdAt = 'createdAt';
}

/// [ProfileStore] on the `users/{uid}` documents of Firestore.
final class FirestoreProfileStore implements ProfileStore {
  const FirestoreProfileStore(this._firestore);

  static const String collection = 'users';

  /// Firestore codes for a backend that cannot be reached right now.
  static const String _unavailable = 'unavailable';
  static const String _deadlineExceeded = 'deadline-exceeded';

  final FirebaseFirestore _firestore;

  @override
  Future<UserProfile?> read(String uid) {
    return _translating(() async {
      final snapshot = await _firestore.collection(collection).doc(uid).get();
      final data = snapshot.data();
      return data == null ? null : decode(uid, data);
    });
  }

  @override
  Future<void> create(UserProfile profile) {
    return _translating(
      () => _firestore
          .collection(collection)
          .doc(profile.uid)
          .set(encode(profile)),
    );
  }

  @override
  Future<void> updatePreferences(
    String uid, {
    required Segment segment,
    required Set<Interest> interests,
  }) {
    return _translating(
      () => _firestore
          .collection(collection)
          .doc(uid)
          .update(encodePreferences(segment, interests)),
    );
  }

  /// The two fields a customer may change after sign-up.
  static Map<String, Object> encodePreferences(
    Segment segment,
    Set<Interest> interests,
  ) => {
    ProfileFields.segment: segment.id,
    ProfileFields.interests: [for (final interest in interests) interest.id],
  };

  /// The document stored for [profile]. The creation time is set by the
  /// server, which is the only clock the rules trust.
  static Map<String, Object> encode(UserProfile profile) => {
    ProfileFields.fullName: profile.fullName,
    ProfileFields.nationalId: profile.nationalId,
    ProfileFields.email: profile.email,
    ProfileFields.phone: profile.phone,
    ...encodePreferences(profile.segment, profile.interests),
    ProfileFields.createdAt: FieldValue.serverTimestamp(),
  };

  /// Reads a document leniently: an unknown segment falls back to the
  /// default and unknown interests are dropped, so a profile written by a
  /// newer version of the app still opens.
  static UserProfile decode(String uid, Map<String, Object?> data) {
    String text(String field) => switch (data[field]) {
      final String value => value,
      _ => '',
    };

    return UserProfile(
      uid: uid,
      email: text(ProfileFields.email),
      fullName: text(ProfileFields.fullName),
      nationalId: text(ProfileFields.nationalId),
      phone: text(ProfileFields.phone),
      segment: Segment.fromId(data[ProfileFields.segment]),
      interests: switch (data[ProfileFields.interests]) {
        final List<Object?> ids => ids.map(Interest.fromId).nonNulls.toSet(),
        _ => const {},
      },
    );
  }

  Future<T> _translating<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FirebaseException catch (error) {
      if (error.code == _unavailable) throw const ServiceUnavailableFailure();
      if (error.code == _deadlineExceeded) throw const TimeoutFailure();
      rethrow;
    }
  }
}
