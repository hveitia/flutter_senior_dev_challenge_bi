import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/presentation/detail/account_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/pump_accounts.dart';

void main() {
  late AccountsHarness harness;
  late int backs;

  Widget screen({String accountId = 'savings'}) => AccountDetailScreen(
    accountId: accountId,
    onBack: () => backs++,
    now: () => now,
  );

  /// Opens the savings account with its balances loaded. Movements are
  /// whatever the test delivers afterwards.
  Future<void> open(
    WidgetTester tester, {
    Result<MovementsSnapshot>? movementsAnswer,
    double textScale = 1,
    int pageSize = MovementsBloc.defaultPageSize,
  }) async {
    harness.repository.onRefreshAccounts = () async =>
        Success(accountsSnapshot(const [savings, checking]));
    if (movementsAnswer != null) {
      harness.repository.onRefreshMovements = () async => movementsAnswer;
    } else {
      harness.repository.onRefreshMovements = () =>
          Completer<Result<MovementsSnapshot>>().future;
    }
    await harness.pump(
      tester,
      screen(),
      accountId: 'savings',
      textScale: textScale,
      pageSize: pageSize,
    );
    await tester.pump();
  }

  Finder rows() => find.byType(MovementRow);

  /// The available balance, as drawn by the large amount at the top. The
  /// booked balance below it may read the same.
  Finder availableBalance() => find.descendant(
    of: find.byType(AmountText),
    matching: find.text(r'$3,570.35', findRichText: true),
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Visible is not enough to tap it: bring it fully into view.
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  setUp(() {
    harness = AccountsHarness();
    backs = 0;
  });

  testWidgets('shows the name, both balances and the number of the account', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Cuenta de ahorros'), findsOneWidget);
    expect(find.text('DISPONIBLE'), findsOneWidget);
    expect(availableBalance(), findsOneWidget);
    expect(find.bySemanticsLabel(r'Contable: $3,570.35'), findsOneWidget);
    expect(find.bySemanticsLabel('Cuenta: 22004821'), findsOneWidget);
  });

  testWidgets('offers nothing that cannot be done yet', (tester) async {
    await open(tester, movementsAnswer: Success(movementsSnapshot(movements)));
    await tester.pump();

    expect(find.text('Transferir'), findsNothing);
    expect(find.text('Compartir datos de cuenta'), findsNothing);
  });

  testWidgets('copies the account number and confirms it', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Copiar número de cuenta'));
    await tester.pump();

    expect(harness.copied, ['22004821']);
    expect(find.text('Número de cuenta copiado'), findsOneWidget);
  });

  testWidgets('keeps the balance on screen while movements are loading', (
    tester,
  ) async {
    await open(tester);

    expect(availableBalance(), findsOneWidget);
    expect(find.byType(SkeletonBlock), findsWidgets);
    expect(rows(), findsNothing);
  });

  testWidgets('groups movements by day under Hoy, Ayer and the date', (
    tester,
  ) async {
    await open(tester, movementsAnswer: Success(movementsSnapshot(movements)));
    await tester.pump();

    expect(find.text('HOY'), findsOneWidget);
    expect(find.text('Nómina de septiembre'), findsOneWidget);
    expect(find.text('Hoy · 09:12'), findsOneWidget);

    await scrollTo(tester, find.text('28 SEP'));
    expect(find.text('AYER', skipOffstage: false), findsOneWidget);
    expect(find.text('28 sep · 16:04'), findsOneWidget);
  });

  testWidgets('a filter narrows the list and is shown as chosen', (
    tester,
  ) async {
    await open(tester, movementsAnswer: Success(movementsSnapshot(movements)));
    await tester.pump();

    await scrollTo(tester, find.text('Ingresos'));
    await tester.tap(find.text('Ingresos'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<AppChip>(find.widgetWithText(AppChip, 'Ingresos')).selected,
      isTrue,
    );
    expect(find.text('Supermercado', skipOffstage: false), findsNothing);
    expect(
      find.text('Nómina de septiembre', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('the search narrows the list as the customer types', (
    tester,
  ) async {
    await open(tester, movementsAnswer: Success(movementsSnapshot(movements)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'super');
    await tester.pump();

    expect(find.text('Supermercado', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Nómina de septiembre', skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('says so when nothing matches the search', (tester) async {
    await open(tester, movementsAnswer: Success(movementsSnapshot(movements)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zapatos');
    await tester.pump();

    expect(
      find.text('No hay movimientos', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Prueba con otro nombre o filtro.', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('when some movements could not be read, says so above the '
      'ones it shows', (tester) async {
    await open(
      tester,
      movementsAnswer: Success(
        MovementsSnapshot(
          value: [salary, groceries],
          origin: DataOrigin.server,
          syncedAt: now,
          skipped: 1,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'No pudimos mostrar algunos movimientos de esta cuenta.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    await scrollTo(tester, find.text('Nómina de septiembre'));
    expect(rows(), findsWidgets);
  });

  testWidgets('an account without movements says so, not that the search '
      'found nothing', (tester) async {
    await open(tester, movementsAnswer: Success(movementsSnapshot(const [])));
    await tester.pump();

    expect(
      find.text('Aún no tienes movimientos', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('No hay movimientos', skipOffstage: false), findsNothing);
  });

  testWidgets('when movements fail, only that part shows the error and the '
      'balance stays', (tester) async {
    await open(
      tester,
      movementsAnswer: const Failed(ServiceUnavailableFailure('movements')),
    );
    await tester.pump();

    expect(availableBalance(), findsOneWidget);
    expect(
      find.text('No pudimos cargar tus movimientos', skipOffstage: false),
      findsOneWidget,
    );

    await scrollTo(tester, find.text('Reintentar'));
    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    expect(harness.repository.movementRefreshes, 2);
    expect(harness.repository.accountRefreshes, 1);
  });

  testWidgets('saved movements say how old they are, and that they could '
      'not be refreshed', (tester) async {
    await open(tester, movementsAnswer: const Failed(TimeoutFailure()));
    await harness.deliverMovements(
      tester,
      movementsSnapshot(movements, origin: DataOrigin.cache),
    );

    expect(
      find.text('Actualizado hace 8 min', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'No pudimos actualizar tus movimientos',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    await scrollTo(tester, find.text('Nómina de septiembre'));
    expect(rows(), findsWidgets);
  });

  testWidgets('a saved balance says how old it is, apart from the '
      'movements', (tester) async {
    harness.repository
      ..onRefreshAccounts = (() async => const Failed(TimeoutFailure()))
      ..onRefreshMovements = () async => Success(movementsSnapshot(movements));
    await harness.pump(tester, screen(), accountId: 'savings');
    await harness.deliverAccounts(
      tester,
      accountsSnapshot(const [savings, checking], origin: DataOrigin.cache),
    );

    // The movements were just confirmed, so the only age on screen is the
    // one of the balance.
    expect(find.text('Actualizado hace 8 min'), findsOneWidget);
    final caption = tester.getTopLeft(find.text('Actualizado hace 8 min'));
    final search = tester.getTopLeft(find.text('Buscar movimientos'));
    expect(caption.dy, lessThan(search.dy));
  });

  testWidgets('a balance the backend just confirmed shows no age', (
    tester,
  ) async {
    await open(tester, movementsAnswer: Success(movementsSnapshot(movements)));
    await tester.pump();

    expect(
      find.textContaining('Actualizado', skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('offline, saved movements show their age without a second '
      'notice: the banner already explains it', (tester) async {
    await open(tester, movementsAnswer: const Failed(OfflineFailure()));
    await harness.deliverMovements(
      tester,
      movementsSnapshot(movements, origin: DataOrigin.cache),
    );

    expect(
      find.text('Actualizado hace 8 min', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('No pudimos actualizar', skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('pulling down refreshes the balance and the movements', (
    tester,
  ) async {
    await open(tester, movementsAnswer: Success(movementsSnapshot(movements)));
    await tester.pump();

    await tester.fling(find.text('DISPONIBLE'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(harness.repository.accountRefreshes, 2);
    expect(harness.repository.movementRefreshes, 2);
  });

  testWidgets('brings older movements when asked', (tester) async {
    await open(
      tester,
      pageSize: 2,
      movementsAnswer: Success(movementsSnapshot([salary, groceries])),
    );
    await tester.pump();

    await scrollTo(tester, find.text('Ver más'));
    await tester.tap(find.text('Ver más'));
    await tester.pump();

    expect(
      tester.widget<AppButton>(find.byType(AppButton)).isLoading,
      isTrue,
      reason: 'the button stays, showing progress, while the page arrives',
    );

    expect(harness.repository.movementListeners.last, ('savings', 4));

    await harness.deliverMovements(tester, movementsSnapshot(movements));
    await scrollTo(tester, find.text('Transferencia recibida'));
    expect(find.text('Transferencia recibida'), findsOneWidget);
  });

  group('a search over a list that may have older movements', () {
    const scope =
        'La búsqueda y los filtros solo ven los movimientos cargados. '
        'Toca «Ver más» para incluir los anteriores.';

    testWidgets('says it only covers what is loaded and keeps "Ver más" at '
        'hand, also when nothing matches', (tester) async {
      await open(
        tester,
        pageSize: 2,
        movementsAnswer: Success(movementsSnapshot([salary, groceries])),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'zapatos');
      await tester.pump();

      expect(find.text(scope, skipOffstage: false), findsOneWidget);
      expect(find.text('Ver más', skipOffstage: false), findsOneWidget);
      expect(
        find.text('No hay movimientos', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('a filter gets the same note', (tester) async {
      await open(
        tester,
        pageSize: 2,
        movementsAnswer: Success(movementsSnapshot([salary, groceries])),
      );
      await tester.pump();

      await scrollTo(tester, find.text('Ingresos'));
      await tester.tap(find.text('Ingresos'));
      await tester.pump();

      expect(find.text(scope, skipOffstage: false), findsOneWidget);
    });

    testWidgets('needs no note when everything is loaded', (tester) async {
      await open(
        tester,
        movementsAnswer: Success(movementsSnapshot(movements)),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'zapatos');
      await tester.pump();

      expect(find.text(scope, skipOffstage: false), findsNothing);
    });

    testWidgets('needs no note while the list is not narrowed', (
      tester,
    ) async {
      await open(
        tester,
        pageSize: 2,
        movementsAnswer: Success(movementsSnapshot([salary, groceries])),
      );
      await tester.pump();

      expect(find.text(scope, skipOffstage: false), findsNothing);
    });
  });

  testWidgets('does not offer more when everything is loaded', (tester) async {
    await open(tester, movementsAnswer: Success(movementsSnapshot(movements)));
    await tester.pump();

    expect(find.text('Ver más', skipOffstage: false), findsNothing);
  });

  group('movement detail', () {
    Future<void> openGroceries(WidgetTester tester) async {
      await open(
        tester,
        movementsAnswer: Success(movementsSnapshot(movements)),
      );
      await tester.pump();
      await scrollTo(tester, find.text('Supermercado'));
      await tester.tap(find.text('Supermercado'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens with everything about the movement', (tester) async {
      await openGroceries(tester);

      expect(find.text('Detalle del movimiento'), findsOneWidget);
      expect(find.text('Completado'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Fecha y hora: 3 oct 2026 · 08:45'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Cuenta: Cuenta de ahorros ****4821'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Referencia: MOV-groceries'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Categoría: Supermercado'), findsOneWidget);
      expect(find.bySemanticsLabel('Canal: Tarjeta de débito'), findsOneWidget);
    });

    testWidgets('offers only actions that work', (tester) async {
      await openGroceries(tester);

      expect(find.text('Compartir comprobante'), findsNothing);
      expect(find.text('Reportar un problema'), findsNothing);

      await tester.tap(find.text('Copiar referencia'));
      await tester.pump();

      expect(harness.copied, ['MOV-groceries']);
      expect(find.text('Referencia copiada'), findsOneWidget);
    });

    testWidgets('closes from its own button', (tester) async {
      await openGroceries(tester);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle del movimiento'), findsNothing);
    });

    testWidgets('a pending movement is not shown as completed', (tester) async {
      final pending = movement(
        id: 'pending',
        description: 'Pago en línea',
        amountCents: -2599,
        postedAt: DateTime(2026, 10, 3, 9, 50),
        status: MovementStatus.pending,
      );
      await open(
        tester,
        movementsAnswer: Success(movementsSnapshot([pending])),
      );
      await tester.pump();
      await scrollTo(tester, find.text('Pago en línea'));
      await tester.tap(find.text('Pago en línea'));
      await tester.pumpAndSettle();

      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Completado'), findsNothing);
    });
  });

  testWidgets('an account the customer does not own is explained, with a '
      'way back', (tester) async {
    harness.repository.onRefreshAccounts = () async =>
        Success(accountsSnapshot(const [checking]));
    await harness.pump(tester, screen(), accountId: 'savings');
    await tester.pump();

    expect(find.text('No encontramos esta cuenta'), findsOneWidget);

    await tester.tap(find.text('Volver'));
    expect(backs, 1);
  });

  testWidgets('fits a small phone at 130% text', (tester) async {
    useSmallPhone(tester);

    await open(
      tester,
      textScale: largeText,
      movementsAnswer: Success(movementsSnapshot(movements)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await scrollTo(tester, find.text('Transferencia recibida'));
    expect(tester.takeException(), isNull);
  });
}
