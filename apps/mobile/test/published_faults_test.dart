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
    faults.follow(config);
    await pumpEventQueue();
    source.publish(document(movementsUnavailable: true));
    await pumpEventQueue();
    expect(faults.current.isUnavailable(ServiceIds.movements), isTrue);

    await faults.stop();
    source.publish(document(latencyMs: 9000));
    await pumpEventQueue();

    expect(faults.current, same(ResilienceSettings.none));
  });
}
