import 'package:app_platform/testing.dart';
import 'package:feature_home/feature_home.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/module_kit.dart';

import 'support/home_fixtures.dart';

Widget _nothing(BuildContext context, HomeModuleContext module) =>
    const SizedBox.shrink();

void main() {
  late InMemoryTelemetry telemetry;
  late HomeModuleRegistry registry;

  final published = configDocument(
    segments: {
      'starting': [
        moduleDocument('balance', 'totalBalance'),
        moduleDocument('services', 'serviceRecommendations'),
        moduleDocument('movements', 'recentMovements'),
      ],
      'wealth': [
        moduleDocument('movements', 'recentMovements'),
        moduleDocument('investments', 'investmentSummary'),
        moduleDocument('balance', 'totalBalance'),
      ],
    },
  );

  List<String>? ids(HomeCompositionCubit cubit) =>
      cubit.state.composition?.modules.map((module) => module.id).toList();

  List<Object?> skippedTypes() => [
    for (final event in telemetry.events)
      if (event.name == HomeTelemetry.moduleSkipped)
        event.parameters[HomeTelemetry.typeKey],
  ];

  Future<HomeCompositionCubit> started(ConfigHarness config) async {
    final cubit = HomeCompositionCubit(
      config: config.cubit,
      registry: registry,
      telemetry: telemetry,
    );
    await pumpEventQueue();
    return cubit;
  }

  setUp(() {
    telemetry = InMemoryTelemetry();
    registry = HomeModuleRegistry()
      ..register('totalBalance', _nothing)
      ..register('recentMovements', _nothing);
  });

  test('has no composition until a configuration is in use', () {
    final config = ConfigHarness(bundled: published);

    final cubit = HomeCompositionCubit(
      config: config.cubit,
      registry: registry,
      telemetry: telemetry,
    );

    expect(cubit.state.composition, isNull);
  });

  test('composes the home of the customer segment', () async {
    final cubit = await started(
      ConfigHarness(bundled: published, segmentId: 'wealth'),
    );

    expect(ids(cubit), ['movements', 'balance']);
  });

  test('composes again when a new configuration is published', () async {
    final config = ConfigHarness(bundled: published, segmentId: 'starting');
    final cubit = await started(config);

    config.source.publish(
      configDocument(
        configVersion: 15,
        segments: {
          'starting': [
            moduleDocument('movements', 'recentMovements'),
            moduleDocument('balance', 'totalBalance', visible: false),
          ],
        },
      ),
    );
    await pumpEventQueue();

    expect(ids(cubit), ['movements']);
    expect(cubit.state.configVersion, 15);
  });

  test('composes again when the customer segment changes', () async {
    final config = ConfigHarness(bundled: published, segmentId: 'starting');
    final cubit = await started(config);

    config.cubit.selectSegment('wealth');
    await pumpEventQueue();

    expect(ids(cubit), ['movements', 'balance']);
  });

  test('reports each type it cannot draw once, by its type only', () async {
    final config = ConfigHarness(bundled: published, segmentId: 'starting');
    await started(config);

    config.source.publish(published);
    await pumpEventQueue();
    config.cubit.selectSegment('wealth');
    await pumpEventQueue();

    expect(skippedTypes(), ['serviceRecommendations', 'investmentSummary']);
    expect(
      telemetry.events
          .where((event) => event.name == HomeTelemetry.moduleSkipped)
          .first
          .parameters,
      {HomeTelemetry.typeKey: 'serviceRecommendations'},
    );
  });

  test('stops following the configuration once closed', () async {
    final config = ConfigHarness(bundled: published, segmentId: 'starting');
    final cubit = await started(config);

    await cubit.close();
    config.cubit.selectSegment('wealth');
    await pumpEventQueue();

    expect(ids(cubit), ['balance', 'movements']);
  });
}
