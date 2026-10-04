import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/presentation/movements/movements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/pump_accounts.dart';

void main() {
  late AccountsHarness harness;

  final checkingFee = movement(
    id: 'fee',
    description: 'Comisión mensual',
    amountCents: -250,
    postedAt: DateTime(2026, 10, 3, 9, 30),
    accountId: 'checking',
  );

  /// Movements of both accounts, newest first.
  final mixed = [checkingFee, salary, groceries, coffee, received];

  /// Opens the screen with both accounts loaded. Without an answer the
  /// backend stays silent and the movements are whatever the test delivers.
  Future<void> open(
    WidgetTester tester, {
    Result<MovementsSnapshot>? answer,
    double textScale = 1,
    int pageSize = MovementsBloc.defaultPageSize,
  }) async {
    harness.repository.onRefreshAccounts = () async =>
        Success(accountsSnapshot(const [savings, checking]));
    harness.repository.onRefreshRecentMovements = answer == null
        ? () => Completer<Result<MovementsSnapshot>>().future
        : () async => answer;
    await harness.pump(
      tester,
      MovementsScreen(now: () => now),
      allMovements: true,
      textScale: textScale,
      pageSize: pageSize,
    );
    await tester.pump();
  }

  Finder rows() => find.byType(MovementRow);

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  setUp(() => harness = AccountsHarness());

  testWidgets('is titled Movimientos and lists the movements of every '
      'account, each naming its account', (tester) async {
    await open(tester, answer: Success(movementsSnapshot(mixed)));

    expect(find.widgetWithText(AppBar, 'Movimientos'), findsOneWidget);
    expect(
      find.text('09:30 · Cuenta corriente ****1093', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('09:12 · Cuenta de ahorros ****4821', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('groups movements by day under Hoy, Ayer and the date', (
    tester,
  ) async {
    await open(tester, answer: Success(movementsSnapshot(mixed)));

    for (final header in ['HOY', 'AYER', '28 SEP']) {
      await scrollTo(tester, find.text(header));
      expect(find.text(header), findsOneWidget);
    }
  });

  testWidgets('a movement whose account is not known yet still shows, with '
      'its time only', (tester) async {
    final orphan = movement(
      id: 'orphan',
      description: 'Cuenta cerrada',
      amountCents: -100,
      postedAt: DateTime(2026, 10, 3, 7),
      accountId: 'closed',
    );
    await open(tester, answer: Success(movementsSnapshot([orphan])));

    expect(find.text('07:00'), findsOneWidget);
  });

  testWidgets('shows placeholders while nothing has arrived', (tester) async {
    await open(tester);

    expect(find.byType(SkeletonBlock), findsWidgets);
    expect(rows(), findsNothing);
  });

  testWidgets('when nothing was saved and the backend fails, says so and '
      'retries on request', (tester) async {
    await open(tester, answer: const Failed(TimeoutFailure()));

    expect(find.text('No pudimos cargar tus movimientos'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    expect(harness.repository.recentRefreshes, 2);
  });

  testWidgets('saved movements say how old they are, and that they could '
      'not be refreshed', (tester) async {
    await open(tester, answer: const Failed(TimeoutFailure()));
    await harness.deliverAllMovements(
      tester,
      movementsSnapshot(mixed, origin: DataOrigin.cache),
    );

    expect(find.text('Actualizado hace 8 min'), findsOneWidget);
    expect(
      find.textContaining('No pudimos actualizar tus movimientos'),
      findsOneWidget,
    );
    expect(rows(), findsWidgets);
  });

  testWidgets('offline, saved movements show their age under the connection '
      'banner, without a second notice', (tester) async {
    harness = AccountsHarness(online: false);
    await open(tester, answer: const Failed(OfflineFailure()));
    await harness.deliverAllMovements(
      tester,
      movementsSnapshot(mixed, origin: DataOrigin.cache),
    );

    expect(find.textContaining('Sin conexión'), findsOneWidget);
    expect(find.text('Actualizado hace 8 min'), findsOneWidget);
    expect(find.textContaining('No pudimos actualizar'), findsNothing);
  });

  testWidgets('a customer without movements is told so', (tester) async {
    await open(tester, answer: Success(movementsSnapshot(const [])));

    expect(find.text('Aún no tienes movimientos'), findsOneWidget);
    expect(find.textContaining('esta cuenta'), findsNothing);
  });

  testWidgets('a filter narrows the list across accounts', (tester) async {
    await open(tester, answer: Success(movementsSnapshot(mixed)));

    await tester.tap(find.text('Ingresos'));
    await tester.pump();

    expect(find.text('Comisión mensual'), findsNothing);
    expect(find.text('Nómina de septiembre'), findsOneWidget);
  });

  testWidgets('the search narrows the list and says so when nothing matches', (
    tester,
  ) async {
    await open(tester, answer: Success(movementsSnapshot(mixed)));

    await tester.enterText(find.byType(TextField), 'comisión');
    await tester.pump();
    expect(rows(), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No hay movimientos'), findsOneWidget);
  });

  testWidgets('brings older movements when asked', (tester) async {
    await open(
      tester,
      pageSize: 2,
      answer: Success(movementsSnapshot([checkingFee, salary])),
    );

    await scrollTo(tester, find.text('Ver más'));
    await tester.tap(find.text('Ver más'));
    await tester.pump();

    expect(harness.repository.recentListeners.last, 4);

    await harness.deliverAllMovements(
      tester,
      movementsSnapshot([checkingFee, salary, groceries, coffee]),
    );
    await scrollTo(tester, find.text('Café de la mañana'));
    expect(find.text('Café de la mañana'), findsOneWidget);
  });

  testWidgets('a search over a list that may have older movements says it '
      'only covers what is loaded', (tester) async {
    await open(
      tester,
      pageSize: 2,
      answer: Success(movementsSnapshot([checkingFee, salary])),
    );

    await tester.enterText(find.byType(TextField), 'nómina');
    await tester.pump();

    expect(
      find.textContaining('solo ven los movimientos cargados'),
      findsOneWidget,
    );
    expect(find.text('Ver más'), findsOneWidget);
  });

  testWidgets('opens the detail of a movement with the account it belongs '
      'to', (tester) async {
    await open(tester, answer: Success(movementsSnapshot(mixed)));

    await tester.tap(find.text('Comisión mensual'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del movimiento'), findsOneWidget);
    expect(find.text('Cuenta corriente ****1093'), findsOneWidget);
  });

  testWidgets('pulling down asks the backend again', (tester) async {
    await open(tester, answer: Success(movementsSnapshot(mixed)));

    await tester.fling(
      find.text('Comisión mensual'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(harness.repository.recentRefreshes, 2);
  });

  testWidgets('meets the tap target, label and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await open(tester, answer: Success(movementsSnapshot(mixed)));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('fits a small phone at 130% text', (tester) async {
    useSmallPhone(tester);

    await open(
      tester,
      textScale: largeText,
      answer: Success(movementsSnapshot(mixed)),
    );
    expect(tester.takeException(), isNull);

    await scrollTo(tester, find.text('Transferencia recibida'));
    expect(tester.takeException(), isNull);
  });
}
