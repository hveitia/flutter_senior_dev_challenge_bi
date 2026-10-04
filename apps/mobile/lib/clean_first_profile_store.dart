import 'package:banca_digital/saved_customer_data.dart';
import 'package:feature_auth/adapters.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [ProfileStore] that first finishes any removal of saved data left
/// pending by a previous session.
///
/// Reading the profile is the first thing a new session asks the database.
/// Finishing the removal before it means a customer never starts over a
/// saved copy that a failed or timed-out removal left on the device.
final class CleanFirstProfileStore implements ProfileStore {
  const CleanFirstProfileStore(this._inner, this._savedData);

  final ProfileStore _inner;
  final SavedCustomerData _savedData;

  @override
  Future<UserProfile?> read(String uid) async {
    await _savedData.finishPending();
    return _inner.read(uid);
  }

  @override
  Future<void> create(UserProfile profile) async {
    await _savedData.finishPending();
    return _inner.create(profile);
  }

  @override
  Future<void> updatePreferences(
    String uid, {
    required Segment segment,
    required Set<Interest> interests,
  }) => _inner.updatePreferences(uid, segment: segment, interests: interests);
}

/// [PendingWipe] kept in the device's preferences: one boolean that says
/// nothing about any customer.
final class SharedPreferencesPendingWipe implements PendingWipe {
  const SharedPreferencesPendingWipe(this._preferences);

  static const String _key = 'saved_customer_data.wipe_pending';

  final SharedPreferences _preferences;

  @override
  Future<bool> isPending() async => _preferences.getBool(_key) ?? false;

  @override
  Future<void> setPending({required bool pending}) async {
    if (pending) {
      await _preferences.setBool(_key, true);
    } else {
      await _preferences.remove(_key);
    }
  }
}
