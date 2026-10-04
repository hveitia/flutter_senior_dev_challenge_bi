import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('draws nothing while the connection is fine', (tester) async {
    await pumpApp(
      tester,
      const ConnectionBanner(kind: null, hasSavedData: true),
    );

    expect(find.byType(StatusBanner), findsNothing);
    expect(tester.getSize(find.byType(ConnectionBanner)), Size.zero);
  });

  testWidgets('offline, says that what is on screen was saved', (tester) async {
    await pumpApp(
      tester,
      const ConnectionBanner(
        kind: StatusBannerKind.offline,
        hasSavedData: true,
      ),
    );

    expect(
      find.text('Sin conexión. Mostrando datos guardados'),
      findsOneWidget,
    );
  });

  testWidgets('offline with nothing on screen, does not claim saved data', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const ConnectionBanner(
        kind: StatusBannerKind.offline,
        hasSavedData: false,
      ),
    );

    expect(find.text(ConnectionBanner.offlineWithoutData), findsOneWidget);
    expect(find.textContaining('datos guardados'), findsNothing);
  });

  testWidgets('keeps the usual wording of a slow or restored connection '
      'whether or not something is on screen', (tester) async {
    for (final kind in [StatusBannerKind.slow, StatusBannerKind.restored]) {
      for (final hasSavedData in [true, false]) {
        await pumpApp(
          tester,
          ConnectionBanner(kind: kind, hasSavedData: hasSavedData),
        );

        expect(find.text(kind.defaultMessage), findsOneWidget);
      }
    }
  });
}
