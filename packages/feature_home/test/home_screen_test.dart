import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_home/feature_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/module_kit.dart';
import 'package:module_kit/testing.dart';

import 'support/home_fixtures.dart';

/// A module with data of its own, driven by the test: it reports the status
/// the test sets for its id and counts how often it was refreshed.
final class _DataModules {
  final Map<String, ValueNotifier<HomeModuleStatus>> _statuses = {};
  final List<String> refreshed = [];

  /// How many times each module's state was created: a module that keeps
  /// its place across a new configuration is not created again.
  final Map<String, int> created = {};

  ValueNotifier<HomeModuleStatus> status(String id) =>
      _statuses.putIfAbsent(id, () => ValueNotifier(HomeModuleStatus.ready));

  Widget build(BuildContext context, HomeModuleContext module) {
    return _DataModule(modules: this, module: module);
  }
}

class _DataModule extends StatefulWidget {
  const _DataModule({required this.modules, required this.module});

  final _DataModules modules;
  final HomeModuleContext module;

  @override
  State<_DataModule> createState() => _DataModuleState();
}

class _DataModuleState extends State<_DataModule> {
  @override
  void initState() {
    super.initState();
    widget.modules.created.update(
      widget.module.id,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.module.id;

    return ValueListenableBuilder(
      valueListenable: widget.modules.status(id),
      builder: (context, status, _) => HomeModuleBinding(
        module: widget.module,
        status: status,
        onRefresh: () async => widget.modules.refreshed.add(id),
        child: Text('data $id: ${status.name}'),
      ),
    );
  }
}

void main() {
  late InMemoryTelemetry telemetry;
  late HomeModuleRegistry registry;
  late _DataModules data;
  late FakeConnectivityMonitor monitor;

  final published = configDocument(
    segments: {
      'starting': [
        moduleDocument('balance', 'data'),
        moduleDocument('promo', 'static'),
        moduleDocument('services', 'serviceRecommendations'),
        moduleDocument('movements', 'data'),
      ],
    },
  );

  Future<ConfigHarness> pumpHome(
    WidgetTester tester, {
    Map<String, Object?>? document,
    double textScale = 1,
  }) async {
    final config = ConfigHarness(
      bundled: document ?? published,
      segmentId: 'starting',
    );
    addTearDown(config.cubit.close);

    await tester.pumpWidget(
      RepositoryProvider<Telemetry>.value(
        value: telemetry,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<RemoteConfigCubit>.value(value: config.cubit),
            BlocProvider<ConnectivityCubit>(
              create: (_) => ConnectivityCubit(monitor: monitor)..start(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: app!,
            ),
            home: HomeScreen(
              registry: registry,
              destinations: FakeDestinationResolver(),
              productName: 'Banca Digital',
              firstName: 'Valentina',
              fullName: 'Valentina Andrade',
            ),
          ),
        ),
      ),
    );
    // The configuration starts from the device, then the modules report.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    return config;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  /// Vertical position of the module with [id] on screen.
  double top(WidgetTester tester, String label) =>
      tester.getTopLeft(find.textContaining(label)).dy;

  List<TelemetryEvent> eventsNamed(String name) =>
      telemetry.events.where((event) => event.name == name).toList();

  setUp(() {
    telemetry = InMemoryTelemetry();
    data = _DataModules();
    monitor = FakeConnectivityMonitor();
    registry = HomeModuleRegistry()
      ..register('data', data.build)
      ..register('static', (context, module) => Text('static ${module.id}'));
  });

  testWidgets('greets the customer by name, with their initials', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Hola, Valentina'), findsOneWidget);
    expect(find.text('VA'), findsOneWidget);
    expect(find.text('Banca Digital'), findsOneWidget);
  });

  testWidgets('draws the published modules, in the published order', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(top(tester, 'data balance'), lessThan(top(tester, 'static promo')));
    expect(
      top(tester, 'static promo'),
      lessThan(top(tester, 'data movements')),
    );
  });

  testWidgets('leaves out a module type this version cannot draw', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.textContaining('services'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(eventsNamed(HomeTelemetry.moduleSkipped).single.parameters, {
      HomeTelemetry.typeKey: 'serviceRecommendations',
    });
  });

  testWidgets('recomposes when a new configuration is published, keeping '
      'the modules that stay', (tester) async {
    final config = await pumpHome(tester);

    config.source.publish(
      configDocument(
        configVersion: 15,
        segments: {
          'starting': [
            moduleDocument('movements', 'data'),
            moduleDocument('balance', 'data'),
            moduleDocument('promo', 'static', visible: false),
          ],
        },
      ),
    );
    await settle(tester);

    expect(
      top(tester, 'data movements'),
      lessThan(top(tester, 'data balance')),
    );
    expect(find.text('static promo'), findsNothing);
    expect(data.created, {'balance': 1, 'movements': 1});
  });

  testWidgets('a module that fails alone leaves the others on screen', (
    tester,
  ) async {
    await pumpHome(tester);

    data.status('movements').value = HomeModuleStatus.failed;
    await settle(tester);

    expect(find.text('data movements: failed'), findsOneWidget);
    expect(find.text('data balance: ready'), findsOneWidget);
    expect(find.text('No pudimos conectarnos'), findsNothing);
  });

  group('when no module has anything to show', () {
    Future<void> failEverything(WidgetTester tester) async {
      await pumpHome(tester);
      data.status('balance').value = HomeModuleStatus.failed;
      data.status('movements').value = HomeModuleStatus.failed;
      await settle(tester);
    }

    testWidgets('says so once, for the whole home', (tester) async {
      await failEverything(tester);

      expect(find.text('No pudimos conectarnos'), findsOneWidget);
      expect(find.text('static promo').hitTestable(), findsNothing);
      expect(eventsNamed(HomeTelemetry.nothingToShow), hasLength(1));
    });

    testWidgets('the retry refreshes every module', (tester) async {
      await failEverything(tester);

      await tester.tap(find.text('Reintentar'));
      await settle(tester);

      expect(data.refreshed, unorderedEquals(['balance', 'movements']));
    });

    testWidgets('the home comes back as soon as one module has data', (
      tester,
    ) async {
      await failEverything(tester);

      data.status('balance').value = HomeModuleStatus.ready;
      await settle(tester);

      expect(find.text('No pudimos conectarnos'), findsNothing);
      expect(find.text('data balance: ready').hitTestable(), findsOneWidget);
      expect(data.created, {'balance': 1, 'movements': 1});
    });
  });

  testWidgets('pulling down refreshes every module and is reported', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.fling(
      find.text('data balance: ready'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(data.refreshed, unorderedEquals(['balance', 'movements']));
    expect(eventsNamed(HomeTelemetry.refreshRequested).single.parameters, {
      HomeTelemetry.modulesKey: 2,
    });
  });

  testWidgets('says it is offline and that what it shows was saved', (
    tester,
  ) async {
    monitor = FakeConnectivityMonitor(online: false);

    await pumpHome(tester);

    expect(
      find.text('Sin conexión. Mostrando datos guardados'),
      findsOneWidget,
    );
  });

  testWidgets('says so when the configuration publishes no module', (
    tester,
  ) async {
    await pumpHome(
      tester,
      document: configDocument(segments: {'starting': []}),
    );

    expect(find.text('Estamos preparando tu inicio'), findsOneWidget);
  });

  testWidgets('fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpHome(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);
  });

  group('initials', () {
    test('are the first letters of the first two words', () {
      expect(initialsOf('Valentina Andrade'), 'VA');
      expect(initialsOf('  demo   etapa cuatro '), 'DE');
      expect(initialsOf('Ñusta'), 'Ñ');
      expect(initialsOf(''), '');
    });
  });
}
