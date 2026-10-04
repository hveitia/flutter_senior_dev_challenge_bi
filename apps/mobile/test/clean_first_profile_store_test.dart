import 'package:banca_digital/clean_first_profile_store.dart';
import 'package:banca_digital/saved_customer_data.dart';
import 'package:feature_auth/adapters.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const profile = UserProfile(
    uid: 'uid-1',
    email: 'valentina@example.com',
    fullName: 'Valentina Andrade',
    nationalId: '1710034065',
    phone: '0991234567',
    segment: Segment.starting,
    interests: {},
  );

  late List<String> steps;
  late _RecordingSavedData savedData;
  late CleanFirstProfileStore store;

  setUp(() {
    steps = [];
    savedData = _RecordingSavedData(steps);
    store = CleanFirstProfileStore(_RecordingProfileStore(steps), savedData);
  });

  test('a pending removal is finished before the profile is read', () async {
    await store.read('uid-1');

    expect(steps, ['finish-pending', 'read']);
  });

  test('and before a new profile is created', () async {
    await store.create(profile);

    expect(steps, ['finish-pending', 'create']);
  });

  test('changing preferences, which happens inside a session, does not '
      'touch the saved data', () async {
    await store.updatePreferences(
      'uid-1',
      segment: Segment.family,
      interests: const {},
    );

    expect(steps, ['update']);
  });

  group('SharedPreferencesPendingWipe', () {
    test('remembers a removal that did not finish, and forgets it', () async {
      SharedPreferences.setMockInitialValues({});
      final pending = SharedPreferencesPendingWipe(
        await SharedPreferences.getInstance(),
      );

      expect(await pending.isPending(), isFalse);
      await pending.setPending(pending: true);
      expect(await pending.isPending(), isTrue);
      await pending.setPending(pending: false);
      expect(await pending.isPending(), isFalse);
    });
  });
}

final class _RecordingSavedData implements SavedCustomerData {
  _RecordingSavedData(this._steps);

  final List<String> _steps;

  @override
  Future<void> clear() async => _steps.add('clear');

  @override
  Future<void> finishPending() async {
    _steps.add('finish-pending');
  }
}

final class _RecordingProfileStore implements ProfileStore {
  _RecordingProfileStore(this._steps);

  final List<String> _steps;

  @override
  Future<UserProfile?> read(String uid) async {
    _steps.add('read');
    return null;
  }

  @override
  Future<void> create(UserProfile profile) async => _steps.add('create');

  @override
  Future<void> updatePreferences(
    String uid, {
    required Segment segment,
    required Set<Interest> interests,
  }) async => _steps.add('update');
}
