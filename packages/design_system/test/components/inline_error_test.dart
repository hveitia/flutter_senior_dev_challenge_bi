import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  const message = 'No pudimos cargar tus movimientos';

  testWidgets('explains the failure with an icon and offers a retry', (
    tester,
  ) async {
    var retries = 0;
    await pumpApp(
      tester,
      InlineError(message: message, onRetry: () => retries++),
    );

    await tester.tap(find.text('Reintentar'));

    expect(find.text(message), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(retries, 1);
  });

  testWidgets('shows progress and blocks a second retry while retrying', (
    tester,
  ) async {
    var retries = 0;
    await pumpApp(
      tester,
      InlineError(
        message: message,
        isRetrying: true,
        onRetry: () => retries++,
      ),
    );

    await tester.tap(find.byType(AppButton), warnIfMissed: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(retries, 0);
  });

  testWidgets('is announced when it replaces the content', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, InlineError(message: message, onRetry: () {}));

    expect(
      tester.getSemantics(find.bySemanticsLabel(message)),
      containsSemantics(isLiveRegion: true),
    );
    handle.dispose();
  });
}
