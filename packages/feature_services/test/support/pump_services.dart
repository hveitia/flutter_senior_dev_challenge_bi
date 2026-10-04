import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_services/src/domain/host_contract.dart';
import 'package:feature_services/src/domain/partner_origin.dart';
import 'package:feature_services/src/domain/service_catalog.dart';
import 'package:feature_services/src/presentation/mini_app/mini_app_cubit.dart';
import 'package:feature_services/src/presentation/mini_app/mini_app_screen.dart';
import 'package:feature_services/src/testing/services_fakes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Narrow phone, the worst case for layouts at large text sizes.
const Size smallPhone = Size(320, 640);

/// Text size the screens must survive without overflowing.
const double largeText = 1.3;

/// Pumps [screen] inside the app theme.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  double textScale = 1,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: screen,
    ),
  );
}

/// Makes the test window a small phone until the test ends.
void useSmallPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = smallPhone
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The container of the travel insurance mini app with everything around it
/// driven by the test.
final class MiniAppHarness {
  MiniAppHarness({bool configured = true}) {
    cubit = MiniAppCubit(
      service: service,
      origin: configured
          ? PartnerOrigin.parse(
              'https://partners.example.com',
              isDevelopment: false,
            )
          : null,
      hostContext: () => HostContext(locale: 'es-EC', segment: segment),
      policy: ResiliencePolicy(delay: (_) async {}),
      telemetry: telemetry,
      surfaceFactory: (events) {
        final surface = FakeMiniAppSurface(events, loadError: nextLoadError);
        nextLoadError = null;
        surfaces.add(surface);
        return surface;
      },
    );
  }

  final ServiceEntry service = ServiceCatalog.standard.partner(
    ServiceCatalog.travelInsuranceKey,
  )!;
  final InMemoryTelemetry telemetry = InMemoryTelemetry();
  final FakeExternalLinks links = FakeExternalLinks();

  late final MiniAppCubit cubit;

  /// The surface of every load, in order.
  final List<FakeMiniAppSurface> surfaces = [];

  /// Thrown by the next load, once.
  Object? nextLoadError;

  /// What the page is told the customer's segment is.
  String segment = 'family';

  /// The surface of the current load.
  FakeMiniAppSurface get surface => surfaces.last;

  /// Every address loaded, by any surface, in order.
  List<Uri> get loaded => [for (final surface in surfaces) ...surface.loaded];

  /// How many times the screen asked to be closed.
  int closes = 0;

  /// How many times the customer asked to go back to Servicios.
  int returns = 0;

  /// Pumps the container and starts the mini app, as its route does.
  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    addTearDown(cubit.close);
    await pumpScreen(
      tester,
      BlocProvider<MiniAppCubit>.value(
        value: cubit,
        child: MiniAppScreen(
          service: service,
          externalLinks: links,
          onClose: () => closes++,
          onBackToServices: () => returns++,
        ),
      ),
      textScale: textScale,
    );
    await cubit.start();
    await tester.pump();
  }

  /// Lets the time limit of a load run out. A test that finishes while the
  /// page is still loading calls it once it has checked what it wanted, or
  /// the limit would outlive the test.
  ///
  /// Closing the Cubit here instead would never finish: the screen is still
  /// listening to it.
  Future<void> end(WidgetTester tester) =>
      tester.pump(MiniAppCubit.defaultLoadTimeout);
}
