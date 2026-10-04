import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app_router.dart';
import 'package:banca_digital/destinations.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:module_kit/module_kit.dart';

void main() {
  const allOn = FeatureFlags(transfers: true, partnerServices: true);

  late FeatureFlags features;

  AppDestinationResolver resolver({Map<String, AppDestination>? routes}) =>
      AppDestinationResolver(
        features: () => features,
        routes: routes ?? AppDestinationResolver.builtRoutes,
      );

  /// Opens [destination] from the first screen of a router and returns
  /// where the app ended up.
  Future<String> open(WidgetTester tester, String destination) async {
    late BuildContext start;
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) {
            start = context;
            return const SizedBox.shrink();
          },
        ),
        for (final path in [
          AccountsPaths.accounts,
          AppPaths.services,
          AppPaths.profile,
        ])
          GoRoute(
            path: path,
            builder: (context, state) => const SizedBox.shrink(),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    resolver().resolve(destination)!(start);
    await tester.pumpAndSettle();
    return router.state.uri.path;
  }

  setUp(() => features = allOn);

  testWidgets('opens the sections the app already has', (tester) async {
    expect(await open(tester, Destinations.accounts), AccountsPaths.accounts);
    expect(await open(tester, Destinations.services), AppPaths.services);
    expect(await open(tester, Destinations.profile), AppPaths.profile);
  });

  test('opens a transfer only while the published features have transfers '
      'on', () {
    expect(resolver().resolve(Destinations.transfer), isNotNull);

    features = const FeatureFlags(transfers: false, partnerServices: true);

    expect(resolver().resolve(Destinations.transfer), isNull);
  });

  test('cannot open what has no screen yet, even with its feature on', () {
    for (final destination in [
      '${Destinations.partnerPrefix}travelInsurance',
      '${Destinations.partnerPrefix}recharge',
    ]) {
      expect(resolver().resolve(destination), isNull, reason: destination);
    }
  });

  test('the inbox has a screen', () {
    expect(resolver().resolve(Destinations.inbox), isNotNull);
  });

  test('cannot open a destination the contract does not name', () {
    expect(resolver().resolve('settings/developer'), isNull);
    expect(resolver().resolve(''), isNull);
  });

  group('a destination behind a feature', () {
    final routes = {
      Destinations.transfer: AppDestination(
        open: (context) {},
        isEnabled: (features) => features.transfers,
      ),
    };

    test('can be opened while the feature is on', () {
      expect(
        resolver(routes: routes).resolve(Destinations.transfer),
        isNotNull,
      );
    });

    test('cannot be opened once the published flag turns it off', () {
      final flagged = resolver(routes: routes);

      features = const FeatureFlags(transfers: false, partnerServices: true);

      expect(flagged.resolve(Destinations.transfer), isNull);
    });
  });
}
