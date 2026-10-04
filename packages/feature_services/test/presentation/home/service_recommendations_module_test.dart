import 'package:design_system/design_system.dart';
import 'package:feature_services/src/presentation/home/service_recommendations_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/module_kit.dart';
import 'package:module_kit/testing.dart';

import '../../support/pump_services.dart';

const _insurance = 'partner:travelInsurance';
const _recharge = 'partner:recharge';

/// The module as the home would build it from a published document.
final class _Module {
  _Module({
    Object? services = const ['travelInsurance', 'recharge'],
    Set<String> available = const {_insurance, _recharge},
  }) : destinations = FakeDestinationResolver(available: available) {
    registerServicesHomeModules(registry);
    context = moduleContext(
      id: 'services',
      type: ServicesModuleTypes.serviceRecommendations,
      props: {'services': ?services},
      destinations: destinations,
      host: host,
    );
  }

  final HomeModuleRegistry registry = HomeModuleRegistry();
  final RecordingModuleHost host = RecordingModuleHost();
  final FakeDestinationResolver destinations;
  late final HomeModuleContext context;

  Future<void> pump(WidgetTester tester, {double textScale = 1}) {
    final builder = registry.builderFor(
      ServicesModuleTypes.serviceRecommendations,
    )!;

    return pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Builder(builder: (context) => builder(context, this.context)),
        ),
      ),
      textScale: textScale,
    );
  }
}

void main() {
  testWidgets('the services domain registers the type the contract names', (
    tester,
  ) async {
    final module = _Module();

    expect(module.registry.types, {'serviceRecommendations'});
  });

  testWidgets('draws the published services in the published order', (
    tester,
  ) async {
    final module = _Module(services: const ['recharge', 'travelInsurance']);
    await module.pump(tester);

    expect(find.text('Para ti'), findsOneWidget);
    final cards = tester.widgetList<LinkCard>(find.byType(LinkCard));
    expect(cards.map((card) => card.title), ['Recargas', 'Seguro de viaje']);
    expect(module.host.statuses, {'services': HomeModuleStatus.ready});
  });

  testWidgets('says each one belongs to a partner', (tester) async {
    final module = _Module();
    await module.pump(tester);

    expect(find.text('Aliado'), findsNWidgets(2));
  });

  testWidgets('opens the mini app of the card that is tapped', (tester) async {
    final module = _Module();
    await module.pump(tester);

    await tester.tap(find.text('Seguro de viaje'));

    expect(module.destinations.opened, [_insurance]);
  });

  testWidgets('leaves out a service this version does not know', (
    tester,
  ) async {
    final module = _Module(services: const ['pets', 'recharge']);
    await module.pump(tester);

    final cards = tester.widgetList<LinkCard>(find.byType(LinkCard));
    expect(cards.map((card) => card.title), ['Recargas']);
  });

  testWidgets('leaves out a service that cannot be opened', (tester) async {
    final module = _Module(available: const {_recharge});
    await module.pump(tester);

    expect(find.text('Seguro de viaje'), findsNothing);
    expect(find.text('Recargas'), findsOneWidget);
  });

  testWidgets('draws a service once, however many times it is published', (
    tester,
  ) async {
    final module = _Module(
      services: const ['recharge', 'recharge', 'recharge'],
    );
    await module.pump(tester);

    expect(find.byType(LinkCard), findsOneWidget);
  });

  for (final (name, services, available) in <(String, Object?, Set<String>)>[
    ('partners are switched off', ['travelInsurance', 'recharge'], {}),
    ('nothing is published', null, {_insurance, _recharge}),
    ('the list is empty', <String>[], {_insurance, _recharge}),
    ('no published name is known', ['pets', 'cinema'], {_insurance}),
    ('the list is not a list', 'travelInsurance', {_insurance}),
    (
      'the names are not text',
      <Object?>[1, true, null, <String, Object?>{}],
      {_insurance},
    ),
  ]) {
    testWidgets('takes no space and tells the home so when $name', (
      tester,
    ) async {
      final module = _Module(services: services, available: available);
      await module.pump(tester);

      expect(find.text('Para ti'), findsNothing);
      expect(find.byType(LinkCard), findsNothing);
      expect(module.host.statuses, {'services': HomeModuleStatus.hidden});
      expect(
        tester.getSize(find.byType(ServiceRecommendationsModule)).height,
        0,
      );
    });
  }

  testWidgets('meets tap target, label and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _Module().pump(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('does not overflow on a small phone at 130% text', (
    tester,
  ) async {
    useSmallPhone(tester);

    await _Module().pump(tester, textScale: largeText);

    expect(tester.takeException(), isNull);
  });
}
