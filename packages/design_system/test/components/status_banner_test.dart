import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  const expectations = {
    StatusBannerKind.offline: (
      'Sin conexión. Mostrando datos guardados',
      Icons.wifi_off,
      AppTone.warning,
    ),
    StatusBannerKind.slow: (
      'Conexión lenta. Seguimos intentando',
      Icons.schedule,
      AppTone.warning,
    ),
    StatusBannerKind.restored: (
      'Conexión restablecida. Datos actualizados',
      Icons.check_circle_outline,
      AppTone.success,
    ),
  };

  for (final MapEntry(key: kind, value: (message, icon, tone))
      in expectations.entries) {
    testWidgets('${kind.name} states the situation with icon and text', (
      tester,
    ) async {
      await pumpApp(tester, StatusBanner(kind: kind));

      expect(find.text(message), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(icon)).color, tone.foreground);
      expect(
        tester.widget<Text>(find.text(message)).style!.color,
        tone.foreground,
      );
    });
  }

  testWidgets('accepts a message specific to the screen', (tester) async {
    await pumpApp(
      tester,
      const StatusBanner(
        kind: StatusBannerKind.offline,
        message: 'Sin conexión. Revisa tu red e intenta de nuevo',
      ),
    );

    expect(
      find.text('Sin conexión. Revisa tu red e intenta de nuevo'),
      findsOneWidget,
    );
  });

  testWidgets('is announced as soon as it appears', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, const StatusBanner(kind: StatusBannerKind.offline));

    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Sin conexión. Mostrando datos guardados'),
      ),
      containsSemantics(isLiveRegion: true),
    );
    handle.dispose();
  });

  group('slow connection', () {
    testWidgets('adds a progress line while the app keeps trying', (
      tester,
    ) async {
      await pumpApp(tester, const StatusBanner(kind: StatusBannerKind.slow));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('keeps the line still when motion is reduced', (tester) async {
      await pumpApp(
        tester,
        const StatusBanner(kind: StatusBannerKind.slow),
        disableAnimations: true,
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
