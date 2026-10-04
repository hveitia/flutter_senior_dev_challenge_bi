import 'dart:convert';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:banca_digital/published_faults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> document({
    int latencyMs = 0,
    bool movementsUnavailable = false,
  }) {
    return {
      'schemaVersion': HomeConfigParser.supportedSchemaVersion,
      'configVersion': 1,
      'destinations': <String>[],
      'resilience': {
        'latencyMs': latencyMs,
        'movementsUnavailable': movementsUnavailable,
        'partnerInsuranceUnavailable': false,
      },
      'segments': {
        'starting': {
          'label': 'Estoy empezando',
          'modules': <Object?>[],
          'features': {'transfers': false, 'partnerServices': false},
        },
      },
    };
  }

  late FakeConfigSource source;
  late RemoteConfigCubit config;
  late PublishedFaults faults;

  setUp(() {
    source = FakeConfigSource();
    config = RemoteConfigCubit(
      ConfigRepository(
        source: source,
        store: InMemoryConfigStore(),
        loadBundled: () async => jsonEncode(document()),
      ),
    )..start();
    faults = PublishedFaults();
  });

  tearDown(() => config.close());

  test('publishes no fault until told to follow a configuration', () {
    expect(faults.current, same(ResilienceSettings.none));
  });

  test('follows the faults of the configuration in use', () async {
    faults.follow(config);
    await pumpEventQueue();

    source.publish(document(latencyMs: 5000, movementsUnavailable: true));
    await pumpEventQueue();

    expect(faults.current.latency, const Duration(seconds: 5));
    expect(faults.current.isUnavailable(ServiceIds.movements), isTrue);
  });

  test('takes the faults of a configuration already in use', () async {
    await pumpEventQueue();
    source.publish(document(movementsUnavailable: true));
    await pumpEventQueue();

    faults.follow(config);

    expect(faults.current.isUnavailable(ServiceIds.movements), isTrue);
  });

  test('lifts every fault when it stops following', () async {
    final stop = faults.follow(config);
    await pumpEventQueue();
    source.publish(document(movementsUnavailable: true));
    await pumpEventQueue();
    expect(faults.current.isUnavailable(ServiceIds.movements), isTrue);

    await stop();
    source.publish(document(latencyMs: 9000));
    await pumpEventQueue();

    expect(faults.current, same(ResilienceSettings.none));
  });

  test(
    'a follower that was replaced cannot stop the one that replaced it',
    () async {
      final nextSource = FakeConfigSource();
      final nextConfig = RemoteConfigCubit(
        ConfigRepository(
          source: nextSource,
          store: InMemoryConfigStore(),
          loadBundled: () async => jsonEncode(document()),
        ),
      )..start();
      addTearDown(nextConfig.close);

      // The next customer's follower starts before the previous one stops,
      // which is the order a direct change of customer produces.
      final stopPrevious = faults.follow(config);
      faults.follow(nextConfig);
      await pumpEventQueue();
      await stopPrevious();

      nextSource.publish(document(movementsUnavailable: true));
      await pumpEventQueue();

      expect(faults.current.isUnavailable(ServiceIds.movements), isTrue);
    },
  );

  test('says so when the faults in force change, and only then', () async {
    var changes = 0;
    faults.onChanged = () => changes++;
    final stop = faults.follow(config);
    await pumpEventQueue();
    expect(changes, 0);

    source.publish(document(movementsUnavailable: true));
    await pumpEventQueue();
    expect(changes, 1);

    // The same faults published again, with a new version of the rest.
    source.publish(document(movementsUnavailable: true));
    await pumpEventQueue();
    expect(changes, 1);

    await stop();
    expect(changes, 2);
  });
}
