import 'package:feature_accounts/adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final at = DateTime(2026, 10, 3, 9, 52);

  Future<SharedPreferences> preferences([
    Map<String, Object> stored = const {},
  ]) {
    SharedPreferences.setMockInitialValues(stored);
    return SharedPreferences.getInstance();
  }

  test('knows nothing before the first synchronization', () async {
    final times = SharedPreferencesSyncTimes(await preferences(), uid: 'u1');

    expect(times.lastSync('accounts'), isNull);
  });

  test('remembers the time of each data set across restarts', () async {
    final stored = await preferences();
    await SharedPreferencesSyncTimes(stored, uid: 'u1').record('accounts', at);

    final afterRestart = SharedPreferencesSyncTimes(stored, uid: 'u1');

    expect(afterRestart.lastSync('accounts'), at);
    expect(afterRestart.lastSync('movements_savings'), isNull);
  });

  test('one customer never sees the times of another', () async {
    final stored = await preferences();
    await SharedPreferencesSyncTimes(stored, uid: 'u1').record('accounts', at);

    expect(
      SharedPreferencesSyncTimes(stored, uid: 'u2').lastSync('accounts'),
      isNull,
    );
  });

  test('forgets every customer and data set when cleared, and nothing else '
      'the device stores', () async {
    final stored = await preferences({'unlock.u1': true});
    await SharedPreferencesSyncTimes(stored, uid: 'u1').record('accounts', at);
    await SharedPreferencesSyncTimes(
      stored,
      uid: 'u1',
    ).record('movements_savings', at);
    await SharedPreferencesSyncTimes(stored, uid: 'u2').record('accounts', at);

    await SharedPreferencesSyncTimes.clearAll(stored);

    expect(stored.getKeys(), {'unlock.u1'});
  });

  test('treats a value it cannot read as unknown', () async {
    final stored = await preferences({
      SharedPreferencesSyncTimes.keyFor('u1', 'accounts'): 'yesterday',
    });

    expect(
      SharedPreferencesSyncTimes(stored, uid: 'u1').lastSync('accounts'),
      isNull,
    );
  });
}
