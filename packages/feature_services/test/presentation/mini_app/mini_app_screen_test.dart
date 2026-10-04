import 'package:design_system/design_system.dart';
import 'package:feature_services/src/testing/services_fakes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_services.dart';

const _unavailable =
    'Este servicio no está disponible por ahora. Tu cuenta y tus saldos '
    'no se ven afectados.';

void main() {
  group('host bar', () {
    testWidgets('names the service and whose it is', (tester) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);

      expect(find.text('Seguro de viaje'), findsOneWidget);
      expect(find.text('Servicio de Aliado Seguros'), findsOneWidget);
      await harness.end(tester);
    });

    testWidgets('closes the mini app', (tester) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);

      await tester.tap(find.byTooltip('Cerrar'));

      expect(harness.closes, 1);
      await harness.end(tester);
    });

    testWidgets('stays in place when the service is not available', (
      tester,
    ) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events.onLoadFailed();
      await tester.pump();

      expect(find.text('Servicio de Aliado Seguros'), findsOneWidget);
      expect(find.byTooltip('Cerrar'), findsOneWidget);
    });

    testWidgets('loads the page again from its menu', (tester) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events.onPageFinished();
      await tester.pump();

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver a cargar'));
      await tester.pumpAndSettle();

      expect(harness.surface.loaded, hasLength(2));
    });
  });

  group('partner content', () {
    testWidgets('is captioned as the partner’s and drawn in its frame', (
      tester,
    ) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events.onPageFinished();
      await tester.pump();

      expect(find.text('Contenido de Aliado Seguros'), findsOneWidget);
      expect(find.byKey(FakeMiniAppSurface.pageKey), findsOneWidget);
      expect(find.byType(SkeletonBlock), findsNothing);
    });

    testWidgets('is covered by placeholders while it loads', (tester) async {
      final handle = tester.ensureSemantics();
      final harness = MiniAppHarness();
      await harness.pump(tester);

      expect(find.byType(SkeletonBlock), findsWidgets);
      expect(find.bySemanticsLabel('Cargando Seguro de viaje'), findsOneWidget);
      handle.dispose();
      await harness.end(tester);
    });
  });

  group('unavailable', () {
    testWidgets('tells the customer their money is not affected', (
      tester,
    ) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events.onHttpError(503);
      await tester.pump();

      expect(find.text('Servicio no disponible'), findsOneWidget);
      expect(find.text(_unavailable), findsOneWidget);
      expect(find.byKey(FakeMiniAppSurface.pageKey), findsNothing);
    });

    testWidgets('tries again when asked', (tester) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events.onLoadFailed();
      await tester.pump();

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      harness.surface.events.onPageFinished();
      await tester.pump();

      expect(harness.surface.loaded, hasLength(2));
      expect(find.text('Servicio no disponible'), findsNothing);
      expect(find.byKey(FakeMiniAppSurface.pageKey), findsOneWidget);
    });

    testWidgets('leads back to Servicios', (tester) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events.onLoadFailed();
      await tester.pump();

      await tester.tap(find.text('Volver a Servicios'));

      expect(harness.returns, 1);
    });

    testWidgets('is what a build without a partner origin shows', (
      tester,
    ) async {
      final harness = MiniAppHarness(configured: false);
      await harness.pump(tester);

      expect(find.text('Servicio no disponible'), findsOneWidget);
      expect(harness.surface.loaded, isEmpty);
    });
  });

  group('a link to another site', () {
    final terms = Uri.parse('https://www.example.org/terms?user=42');

    Future<MiniAppHarness> pumpWithOffer(WidgetTester tester) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events
        ..onPageFinished()
        ..onNavigation(terms);
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('is offered with the site it leads to and nothing more', (
      tester,
    ) async {
      await pumpWithOffer(tester);

      expect(find.text('Vas a salir de la app'), findsOneWidget);
      expect(find.textContaining('https://www.example.org,'), findsOneWidget);
      expect(find.textContaining('user=42'), findsNothing);
    });

    testWidgets('opens in the browser when the customer accepts', (
      tester,
    ) async {
      final harness = await pumpWithOffer(tester);

      await tester.tap(find.text('Abrir en el navegador'));
      await tester.pumpAndSettle();

      expect(harness.links.opened, [terms]);
      expect(harness.cubit.state.outsideLink, isNull);
    });

    testWidgets('opens nowhere when the customer stays', (tester) async {
      final harness = await pumpWithOffer(tester);

      await tester.tap(find.text('Quedarme aquí'));
      await tester.pumpAndSettle();

      expect(harness.links.opened, isEmpty);
      expect(harness.cubit.state.outsideLink, isNull);
      expect(find.byKey(FakeMiniAppSurface.pageKey), findsOneWidget);
    });

    testWidgets('says so when the browser could not be opened', (tester) async {
      final harness = MiniAppHarness()..links.opens = false;
      await harness.pump(tester);
      harness.surface.events
        ..onPageFinished()
        ..onNavigation(terms);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir en el navegador'));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos abrir el enlace.'), findsOneWidget);
    });
  });

  group('what the page tells the host', () {
    testWidgets('a close request closes the mini app', (tester) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events
        ..onPageFinished()
        ..onMessage('{"type":"close"}');
      await tester.pump();

      expect(harness.closes, 1);
    });

    testWidgets('a completed operation is confirmed with its reference', (
      tester,
    ) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events
        ..onPageFinished()
        ..onMessage('{"type":"completed","reference":"SV-00042"}');
      await tester.pump();

      expect(
        find.text('Operación completada. Referencia: SV-00042'),
        findsOneWidget,
      );
      expect(find.byKey(FakeMiniAppSurface.pageKey), findsOneWidget);
    });

    testWidgets('markup sent as a reference never reaches the screen', (
      tester,
    ) async {
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events
        ..onPageFinished()
        ..onMessage('{"type":"completed","reference":"<b>gratis</b>"}');
      await tester.pump();

      expect(find.textContaining('gratis'), findsNothing);
      expect(find.textContaining('Operación completada'), findsNothing);
    });
  });

  group('accessibility', () {
    testWidgets('meets the guidelines with the page shown', (tester) async {
      final handle = tester.ensureSemantics();
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events.onPageFinished();
      await tester.pump();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('meets the guidelines when the service is not available', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final harness = MiniAppHarness();
      await harness.pump(tester);
      harness.surface.events.onLoadFailed();
      await tester.pump();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    for (final (state, play) in <(String, void Function(MiniAppHarness))>[
      ('loading', (harness) {}),
      ('shown', (harness) => harness.surface.events.onPageFinished()),
      ('unavailable', (harness) => harness.surface.events.onLoadFailed()),
      (
        'completed',
        (harness) => harness.surface.events
          ..onPageFinished()
          ..onMessage('{"type":"completed","reference":"SV-00042"}'),
      ),
    ]) {
      testWidgets('does not overflow on a small phone at 130% text: $state', (
        tester,
      ) async {
        useSmallPhone(tester);
        final harness = MiniAppHarness();
        await harness.pump(tester, textScale: largeText);

        play(harness);
        await tester.pump();

        expect(tester.takeException(), isNull);
        await harness.end(tester);
      });
    }
  });
}
