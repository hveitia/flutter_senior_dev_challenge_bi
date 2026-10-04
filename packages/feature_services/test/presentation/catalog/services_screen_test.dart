import 'package:design_system/design_system.dart';
import 'package:feature_services/src/domain/service_catalog.dart';
import 'package:feature_services/src/presentation/catalog/services_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/testing.dart';

import '../../support/pump_services.dart';

const _insurance = 'partner:travelInsurance';
const _recharge = 'partner:recharge';
const _transfer = 'transfer';

void main() {
  Future<FakeDestinationResolver> pump(
    WidgetTester tester, {
    Set<String> available = const {_transfer, _insurance, _recharge},
    double textScale = 1,
  }) async {
    final destinations = FakeDestinationResolver(available: available);
    await pumpScreen(
      tester,
      ServicesScreen(
        catalog: ServiceCatalog.standard,
        destinations: destinations,
      ),
      textScale: textScale,
    );
    return destinations;
  }

  testWidgets('lists the products of the bank and those of its partners', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Servicios'), findsOneWidget);
    expect(
      find.text('Productos del banco y de nuestros aliados'),
      findsOneWidget,
    );
    expect(find.text('Del banco'), findsOneWidget);
    expect(find.text('Transferencias'), findsOneWidget);
    expect(find.text('De aliados'), findsOneWidget);
    expect(find.text('Seguro de viaje'), findsOneWidget);
    expect(find.text('Recargas'), findsOneWidget);
  });

  testWidgets('marks only the partner services as such', (tester) async {
    await pump(tester);

    expect(find.text('Aliado'), findsNWidgets(2));
  });

  testWidgets('leaves no row for a product without a screen', (tester) async {
    await pump(tester, available: {_insurance, _recharge});

    expect(find.text('Del banco'), findsNothing);
    expect(find.text('Transferencias'), findsNothing);
    expect(find.text('De aliados'), findsOneWidget);
  });

  testWidgets('hides the partner section when partners are switched off', (
    tester,
  ) async {
    await pump(tester, available: {_transfer});

    expect(find.text('De aliados'), findsNothing);
    expect(find.text('Seguro de viaje'), findsNothing);
    expect(find.text('Recargas'), findsNothing);
    expect(find.text('Transferencias'), findsOneWidget);
  });

  testWidgets('says so when there is nothing to offer', (tester) async {
    await pump(tester, available: {});

    expect(find.text('Aún no hay servicios disponibles'), findsOneWidget);
    expect(find.byType(LinkCard), findsNothing);
  });

  testWidgets('opens the destination of the row that is tapped', (
    tester,
  ) async {
    final destinations = await pump(tester);

    await tester.tap(find.text('Recargas'));

    expect(destinations.opened, [_recharge]);
  });

  testWidgets('does nothing when the row can no longer be opened', (
    tester,
  ) async {
    final destinations = await pump(tester);
    destinations.available.remove(_recharge);

    await tester.tap(find.text('Recargas'));

    expect(destinations.opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meets tap target, label and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('does not overflow on a small phone at 130% text', (
    tester,
  ) async {
    useSmallPhone(tester);

    await pump(tester, textScale: largeText);

    expect(tester.takeException(), isNull);
  });
}
