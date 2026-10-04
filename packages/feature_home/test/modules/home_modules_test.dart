import 'package:design_system/design_system.dart';
import 'package:feature_home/feature_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/module_kit.dart';
import 'package:module_kit/testing.dart';

void main() {
  late HomeModuleRegistry registry;
  late FakeDestinationResolver destinations;
  late RecordingModuleHost host;

  Future<void> pumpModule(
    WidgetTester tester,
    String type,
    Map<String, Object?> props, {
    double textScale = 1,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: registry.builderFor(type)!(
                context,
                moduleContext(
                  type: type,
                  props: props,
                  destinations: destinations,
                  host: host,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    registry = HomeModuleRegistry();
    registerHomeModules(registry);
    host = RecordingModuleHost();
    destinations = FakeDestinationResolver(
      available: {Destinations.services, Destinations.accounts},
    );
  });

  test('the home registers the modules that carry no data', () {
    expect(registry.types, {
      HomeModuleTypes.quickActions,
      HomeModuleTypes.promoBanner,
    });
  });

  group('quick actions', () {
    const actions = {
      'actions': [
        {'label': 'Transferir', 'icon': 'transfer', 'destination': 'transfer'},
        {'label': 'Pagar', 'icon': 'pay', 'destination': 'services'},
        {
          'label': 'Recargar',
          'icon': 'phone',
          'destination': 'partner:recharge',
        },
        {'label': 'Más', 'icon': 'more', 'destination': 'services'},
      ],
    };

    testWidgets('shows only the actions the app can open', (tester) async {
      await pumpModule(tester, HomeModuleTypes.quickActions, actions);

      expect(find.text('Pagar'), findsOneWidget);
      expect(find.text('Más'), findsOneWidget);
      expect(find.text('Transferir'), findsNothing);
      expect(find.text('Recargar'), findsNothing);
    });

    testWidgets('opens the destination of the action tapped', (tester) async {
      await pumpModule(tester, HomeModuleTypes.quickActions, actions);

      await tester.tap(find.text('Pagar'));

      expect(destinations.opened, [Destinations.services]);
    });

    testWidgets('shows an action as soon as its destination can be opened', (
      tester,
    ) async {
      destinations.available.add(Destinations.transfer);

      await pumpModule(tester, HomeModuleTypes.quickActions, actions);

      expect(find.text('Transferir'), findsOneWidget);
    });

    testWidgets('draws nothing when no action can be opened', (tester) async {
      destinations.available.clear();

      await pumpModule(tester, HomeModuleTypes.quickActions, actions);

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('tells the home when it has nothing to draw, so its space '
        'is taken away, and takes that back when it has', (tester) async {
      destinations.available.clear();
      await pumpModule(tester, HomeModuleTypes.quickActions, actions);
      expect(host.statuses, {'module': HomeModuleStatus.hidden});

      destinations.available.add(Destinations.services);
      await pumpModule(tester, HomeModuleTypes.quickActions, actions);
      expect(host.statuses, isEmpty);
    });

    testWidgets('ignores entries it cannot read and unknown icons', (
      tester,
    ) async {
      await pumpModule(tester, HomeModuleTypes.quickActions, const {
        'actions': [
          'not an action',
          {'label': 'Sin destino'},
          {'destination': 'services'},
          {'label': 'Pagar', 'icon': 'hologram', 'destination': 'services'},
        ],
      });

      expect(find.text('Pagar'), findsOneWidget);
      expect(find.text('Sin destino'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('never draws more than fits the row', (tester) async {
      await pumpModule(tester, HomeModuleTypes.quickActions, {
        'actions': [
          for (var index = 1; index <= 6; index++)
            {'label': 'Acción $index', 'destination': 'services'},
        ],
      });

      expect(find.textContaining('Acción'), findsNWidgets(4));
    });

    testWidgets('each action is announced as a button with its label', (
      tester,
    ) async {
      await pumpModule(tester, HomeModuleTypes.quickActions, actions);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Pagar')),
        containsSemantics(
          label: 'Pagar',
          isButton: true,
          hasTapAction: true,
        ),
      );
    });
  });

  group('promo banner', () {
    const promo = {
      'title': 'Protege tu próximo viaje',
      'body': 'Cotiza tu seguro en menos de un minuto',
      'action': {'label': 'Cotizar', 'destination': 'services'},
    };

    testWidgets('says what was published and opens its action', (tester) async {
      await pumpModule(tester, HomeModuleTypes.promoBanner, promo);

      expect(find.text('Protege tu próximo viaje'), findsOneWidget);
      expect(
        find.text('Cotiza tu seguro en menos de un minuto'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cotizar'));
      expect(destinations.opened, [Destinations.services]);
    });

    testWidgets('keeps the message and drops an action it cannot open', (
      tester,
    ) async {
      await pumpModule(tester, HomeModuleTypes.promoBanner, const {
        'title': 'Mueve tu dinero sin costo',
        'action': {'label': 'Transferir', 'destination': 'transfer'},
      });

      expect(find.text('Mueve tu dinero sin costo'), findsOneWidget);
      expect(find.text('Transferir'), findsNothing);
    });

    testWidgets('draws nothing without a title', (tester) async {
      await pumpModule(tester, HomeModuleTypes.promoBanner, const {
        'body': 'Sin título',
      });

      expect(find.text('Sin título'), findsNothing);
      expect(host.statuses, {'module': HomeModuleStatus.hidden});
    });
  });

  testWidgets('both modules fit a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpModule(tester, HomeModuleTypes.quickActions, const {
      'actions': [
        {'label': 'Pagar servicios', 'destination': 'services'},
        {'label': 'Mis cuentas', 'destination': 'accounts'},
        {'label': 'Invertir', 'destination': 'services'},
        {'label': 'Más', 'destination': 'services'},
      ],
    }, textScale: 1.3);
    expect(tester.takeException(), isNull);

    await pumpModule(tester, HomeModuleTypes.promoBanner, const {
      'title': 'Protege tu próximo viaje',
      'body': 'Cotiza tu seguro en menos de un minuto',
      'action': {'label': 'Cotizar', 'destination': 'services'},
    }, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
