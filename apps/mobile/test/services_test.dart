import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app.dart';
import 'package:banca_digital/services_wiring.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/testing.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_services/feature_services.dart';
import 'package:feature_services/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_dependencies.dart';

/// A published document for the segment `starting` whose home recommends
/// both partner services.
Map<String, Object?> _document({
  bool partnerServices = true,
  bool partnerInsuranceUnavailable = false,
  int configVersion = 15,
}) {
  return {
    'schemaVersion': HomeConfigParser.supportedSchemaVersion,
    'configVersion': configVersion,
    'destinations': ['services', 'partner:travelInsurance', 'partner:recharge'],
    'resilience': {
      'latencyMs': 0,
      'movementsUnavailable': false,
      'partnerInsuranceUnavailable': partnerInsuranceUnavailable,
    },
    'segments': {
      'starting': {
        'label': 'Estoy empezando',
        'modules': [
          moduleDocument(
            'services',
            'serviceRecommendations',
            props: {
              'services': ['travelInsurance', 'recharge'],
            },
          ),
        ],
        'features': {'transfers': true, 'partnerServices': partnerServices},
      },
    },
  };
}

/// Lets a publication arrive and a route change finish.
///
/// Not a settle: a mini app that is loading animates its placeholders until
/// its time limit, and settling would wait for that limit.
Future<void> _frames(WidgetTester tester) async {
  const frames = 8;
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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

  late TestDependencies app;

  Future<void> pumpApp(
    WidgetTester tester, {
    String? partnerOrigin = TestDependencies.partnerOriginOfTests,
    Map<String, Object?>? published,
  }) async {
    app = TestDependencies(
      accountsRepositoryFor: (_) => FakeAccountsRepository(),
      partnerOrigin: partnerOrigin,
    );
    app.auth.restored = const ActiveSession(profile, unlockRequired: false);

    await tester.pumpWidget(BancaDigitalApp(dependencies: app.dependencies));
    await tester.pumpAndSettle();
    app.config.publish(published ?? _document());
    await tester.pumpAndSettle();
  }

  Future<void> publish(WidgetTester tester, Map<String, Object?> document) {
    app.config.publish(document);
    return _frames(tester);
  }

  Finder section(String label) => find.descendant(
    of: find.byType(AppBottomNavigation),
    matching: find.text(label),
  );

  Future<void> openServices(WidgetTester tester) async {
    await tester.tap(section('Servicios'));
    await tester.pumpAndSettle();
  }

  /// Opens the mini app behind the card titled [title] and lets its page
  /// load.
  Future<FakeMiniAppSurface> openMiniApp(
    WidgetTester tester,
    String title,
  ) async {
    await tester.tap(find.text(title));
    await _frames(tester);
    final surface = app.miniApps.last;
    surface.events.onPageFinished();
    await tester.pumpAndSettle();
    return surface;
  }

  group('Servicios', () {
    testWidgets('lists the partners while what is published allows them, and '
        'drops them the moment it does not', (tester) async {
      await pumpApp(tester);
      await openServices(tester);

      expect(find.text('De aliados'), findsOneWidget);
      expect(find.text('Seguro de viaje'), findsOneWidget);
      expect(find.text('Recargas'), findsOneWidget);
      // The bank's own service is listed next to the partners'.
      expect(find.text('Del banco'), findsOneWidget);
      expect(find.text('Transferencias'), findsOneWidget);

      await publish(
        tester,
        _document(partnerServices: false, configVersion: 16),
      );

      expect(find.text('De aliados'), findsNothing);
      expect(find.text('Seguro de viaje'), findsNothing);
    });

    testWidgets('opens a mini app over the navigation, on the partner origin', (
      tester,
    ) async {
      await pumpApp(tester);
      await openServices(tester);

      final surface = await openMiniApp(tester, 'Seguro de viaje');

      expect(find.text('Servicio de Aliado Seguros'), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsNothing);
      expect(surface.loaded.map((uri) => '$uri'), [
        'https://partners.example.com/partners/travel-insurance',
      ]);
    });

    testWidgets('comes back from a mini app when it is closed', (tester) async {
      await pumpApp(tester);
      await openServices(tester);
      await openMiniApp(tester, 'Recargas');

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      expect(find.text('De aliados'), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsOneWidget);
    });

    testWidgets('offers no mini app in a build that was not told where '
        'partners live', (tester) async {
      await pumpApp(tester, partnerOrigin: null);

      expect(find.text('Para ti'), findsNothing);

      await openServices(tester);

      expect(find.text('De aliados'), findsNothing);
      // What the bank itself offers does not depend on the partners.
      expect(find.text('Del banco'), findsOneWidget);
      expect(find.text('Transferencias'), findsOneWidget);
    });
  });

  group('the home', () {
    testWidgets('recommends the published partner services and opens one', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Para ti'), findsOneWidget);
      // The header keeps the notifications bell next to it: two domains
      // contribute to the same screen without knowing each other.
      expect(find.byType(NotificationsBell), findsOneWidget);

      await tester.ensureVisible(find.text('Recargas'));
      await openMiniApp(tester, 'Recargas');

      expect(find.text('Servicio de Aliado Recargas'), findsOneWidget);
    });

    testWidgets('recommends nothing when partners are switched off', (
      tester,
    ) async {
      await pumpApp(tester, published: _document(partnerServices: false));

      expect(find.text('Para ti'), findsNothing);
      expect(find.byType(LinkCard), findsNothing);
    });
  });

  group('the resilience lab', () {
    testWidgets('takes the travel insurance mini app down while it is open '
        'and brings it back when the outage is lifted', (tester) async {
      await pumpApp(tester);
      await openServices(tester);
      await openMiniApp(tester, 'Seguro de viaje');

      await publish(
        tester,
        _document(partnerInsuranceUnavailable: true, configVersion: 16),
      );

      expect(find.text('Servicio no disponible'), findsOneWidget);
      expect(find.byKey(FakeMiniAppSurface.pageKey), findsNothing);
      // The bar of the bank's app stays: the customer can always leave.
      expect(find.text('Servicio de Aliado Seguros'), findsOneWidget);

      await publish(tester, _document(configVersion: 17));
      app.miniApps.last.events.onPageFinished();
      await tester.pumpAndSettle();

      expect(find.text('Servicio no disponible'), findsNothing);
      expect(find.byKey(FakeMiniAppSurface.pageKey), findsOneWidget);
    });

    testWidgets('leaves the other partner alone', (tester) async {
      await pumpApp(tester);
      await openServices(tester);
      await openMiniApp(tester, 'Recargas');

      await publish(
        tester,
        _document(partnerInsuranceUnavailable: true, configVersion: 16),
      );

      expect(find.byKey(FakeMiniAppSurface.pageKey), findsOneWidget);
      expect(find.text('Servicio no disponible'), findsNothing);
    });
  });

  group('partnerDestinations', () {
    const partnersOn = FeatureFlags(transfers: false, partnerServices: true);
    const partnersOff = FeatureFlags(transfers: true, partnerServices: false);

    test('has one destination per mini app, behind the partners flag', () {
      final destinations = partnerDestinations(
        TestDependencies().dependencies.services,
      );

      expect(destinations.keys, [
        'partner:travelInsurance',
        'partner:recharge',
      ]);
      for (final destination in destinations.values) {
        expect(destination.isEnabled(partnersOn), isTrue);
        expect(destination.isEnabled(partnersOff), isFalse);
      }
    });

    test('is empty in a build that was not told where partners live', () {
      final services = TestDependencies(
        partnerOrigin: null,
      ).dependencies.services;

      expect(partnerDestinations(services), isEmpty);
    });
  });

  group('the note of an unfinished clean-up', () {
    test('survives in the preferences until the clean-up finishes', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final note = SharedPreferencesPendingCleanUp(preferences);

      expect(await note.isPending(), isFalse);

      await note.setPending(pending: true);
      expect(
        await SharedPreferencesPendingCleanUp(preferences).isPending(),
        isTrue,
      );

      await note.setPending(pending: false);
      expect(await note.isPending(), isFalse);
      expect(preferences.getKeys(), isEmpty);
    });
  });

  test('a release build never takes an http origin from its flags', () {
    final services = composeServices(
      policy: ResiliencePolicy(),
      telemetry: const NoopTelemetry(),
      data: FakeMiniAppData(),
      isReleaseBuild: true,
    );

    // The flags are empty under test, so this pins the wiring: the build
    // mode reaches the rule, which is tested where it lives.
    expect(services.origin, isNull);
    expect(services.miniApps, isEmpty);
  });

  test('a build that sets no partner origin has none', () {
    // The flags are compile-time values, empty under test: this pins the
    // default the app ships with when the build says nothing.
    expect(PartnerBuildFlags.baseUrl, isEmpty);
    expect(PartnerBuildFlags.isDevelopmentOrigin, isFalse);
    expect(
      PartnerOrigin.parse(PartnerBuildFlags.baseUrl, isDevelopment: false),
      isNull,
    );
  });
}
