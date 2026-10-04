import 'dart:convert';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_services/feature_services.dart';
import 'package:feature_services/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:module_kit/module_kit.dart';

const _servicesPath = '/servicios';

/// A published document for the segment `family`.
Map<String, Object?> _document({required bool partnerServices}) => {
  'schemaVersion': HomeConfigParser.supportedSchemaVersion,
  'configVersion': 14,
  'destinations': ['services', 'partner:travelInsurance', 'partner:recharge'],
  'resilience': {
    'latencyMs': 0,
    'movementsUnavailable': false,
    'partnerInsuranceUnavailable': false,
  },
  'segments': {
    'family': {
      'label': 'Familia',
      'modules': <Object?>[],
      'features': {'transfers': true, 'partnerServices': partnerServices},
    },
  },
};

/// Lets the configuration arrive and a route change finish.
///
/// Not a settle: a mini app that is loading animates its placeholders until
/// its time limit, and settling would wait for that limit.
Future<void> _frames(WidgetTester tester) async {
  const frames = 8;
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the partner mini apps the published flags allow, as the app's
/// resolver does.
final class _FlagResolver implements DestinationResolver {
  _FlagResolver(this._config);

  final RemoteConfigCubit _config;

  @override
  DestinationOpener? resolve(String destination) {
    final enabled = _config.state.segment?.features.partnerServices ?? false;
    if (!enabled || !destination.startsWith(ServiceCatalog.partnerPrefix)) {
      return null;
    }
    final key = destination.substring(ServiceCatalog.partnerPrefix.length);
    return (context) => context.push(ServicesPaths.miniApp(key));
  }
}

/// The two routes of the feature mounted as the app mounts them, with the
/// published configuration driven by the test.
final class _App {
  _App({bool configured = true}) {
    dependencies = ServicesDependencies(
      origin: configured
          ? PartnerOrigin.parse(
              'https://partners.example.com',
              isDevelopment: false,
            )
          : null,
      policy: ResiliencePolicy(delay: (_) async {}),
      telemetry: InMemoryTelemetry(),
      surfaceFactory: (events) {
        final surface = FakeMiniAppSurface(events);
        surfaces.add(surface);
        return surface;
      },
      externalLinks: FakeExternalLinks(),
    );
  }

  final FakeConfigSource source = FakeConfigSource();
  final List<FakeMiniAppSurface> surfaces = [];
  late final ServicesDependencies dependencies;
  late final RemoteConfigCubit config;
  late final GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    String location = _servicesPath,
    bool partnerServices = true,
  }) async {
    config = RemoteConfigCubit(
      ConfigRepository(
        source: source,
        store: InMemoryConfigStore(),
        loadBundled: () async =>
            jsonEncode(_document(partnerServices: partnerServices)),
      ),
      segmentId: 'family',
    )..start();
    addTearDown(config.close);

    router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              BlocProvider<RemoteConfigCubit>.value(
                value: config,
                child: child,
              ),
          routes: [
            servicesTabRoute(
              path: _servicesPath,
              destinations: (context) => _FlagResolver(config),
            ),
            miniAppRoute(dependencies, servicesPath: _servicesPath),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await _frames(tester);
  }

  /// Publishes a document as the backoffice would.
  Future<void> publish(WidgetTester tester, {required bool partnerServices}) {
    source.publish(_document(partnerServices: partnerServices));
    return _frames(tester);
  }

  /// Lets the page of the mini app that is open finish loading.
  Future<void> finishLoading(WidgetTester tester) {
    surfaces.last.events.onPageFinished();
    return tester.pumpAndSettle();
  }

  String get location => router.state.matchedLocation;
}

void main() {
  group('Servicios', () {
    testWidgets('lists the partner services the published flags allow', (
      tester,
    ) async {
      final app = _App();
      await app.pump(tester);

      expect(find.text('De aliados'), findsOneWidget);
      expect(find.text('Seguro de viaje'), findsOneWidget);
    });

    testWidgets('drops them while the customer looks when they are switched '
        'off', (tester) async {
      final app = _App();
      await app.pump(tester);

      await app.publish(tester, partnerServices: false);

      expect(find.text('De aliados'), findsNothing);
      expect(find.text('Aún no hay servicios disponibles'), findsOneWidget);
    });

    testWidgets('opens the mini app of the row that is tapped', (tester) async {
      final app = _App();
      await app.pump(tester);

      await tester.tap(find.text('Recargas'));
      await _frames(tester);
      await app.finishLoading(tester);

      expect(app.location, '/aliados/recharge');
      expect(find.text('Servicio de Aliado Recargas'), findsOneWidget);
      expect(app.surfaces.single.loaded.map((uri) => '$uri'), [
        'https://partners.example.com/partners/recharge',
      ]);
    });
  });

  group('a mini app opened by its address', () {
    const insurance = '/aliados/travelInsurance';

    testWidgets('loads the partner page and tells it the segment only', (
      tester,
    ) async {
      final app = _App();
      await app.pump(tester, location: insurance);
      await app.finishLoading(tester);

      final surface = app.surfaces.single;
      expect(surface.loaded.map((uri) => '$uri'), [
        'https://partners.example.com/partners/travel-insurance',
      ]);
      expect(jsonDecode(surface.posted.single.json), {
        'type': 'context',
        'version': 1,
        'locale': 'es-EC',
        'segment': 'family',
      });
    });

    testWidgets('goes to Servicios when closed with nothing to go back to', (
      tester,
    ) async {
      final app = _App();
      await app.pump(tester, location: insurance);
      await app.finishLoading(tester);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      expect(app.location, _servicesPath);
    });

    testWidgets('is not offered, and loads nothing, when partners are '
        'switched off', (tester) async {
      final app = _App();
      await app.pump(tester, location: insurance, partnerServices: false);

      expect(find.text('Servicio no disponible'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      expect(app.surfaces, isEmpty);

      await tester.tap(find.text('Volver a Servicios'));
      await tester.pumpAndSettle();
      expect(app.location, _servicesPath);
    });

    testWidgets('is not offered when this version does not know the service', (
      tester,
    ) async {
      final app = _App();
      await app.pump(tester, location: '/aliados/pets');

      expect(find.text('Servicio no disponible'), findsOneWidget);
      expect(app.surfaces, isEmpty);
    });

    testWidgets('is taken away while open when partners are switched off', (
      tester,
    ) async {
      final app = _App();
      await app.pump(tester, location: insurance);
      await app.finishLoading(tester);
      expect(find.byKey(FakeMiniAppSurface.pageKey), findsOneWidget);

      await app.publish(tester, partnerServices: false);

      expect(find.byKey(FakeMiniAppSurface.pageKey), findsNothing);
      expect(find.text('Servicio no disponible'), findsOneWidget);
    });

    testWidgets('says the service is not available in a build without a '
        'partner origin', (tester) async {
      final app = _App(configured: false);
      await app.pump(tester, location: insurance);

      expect(find.text('Servicio no disponible'), findsOneWidget);
      expect(app.surfaces.single.loaded, isEmpty);
    });
  });

  group('ServicesDependencies', () {
    test('offers every mini app of the catalog when it has an origin', () {
      final app = _App();

      expect(app.dependencies.miniApps.map((entry) => entry.destination), [
        'partner:travelInsurance',
        'partner:recharge',
      ]);
    });

    test('offers no mini app without an origin', () {
      expect(_App(configured: false).dependencies.miniApps, isEmpty);
    });
  });
}
