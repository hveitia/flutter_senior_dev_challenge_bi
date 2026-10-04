import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/presentation/transfer/transfer_cubit.dart';
import 'package:feature_accounts/src/presentation/transfer/transfer_screen.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/pump_accounts.dart';

void main() {
  late FakeTransfersRepository repository;
  late List<String> seen;
  late int closed;
  late int done;

  setUp(() {
    repository = FakeTransfersRepository();
    seen = [];
    closed = 0;
    done = 0;
  });

  Future<TransferCubit> pump(
    WidgetTester tester, {
    List<Account> accounts = const [savings, checking, fund],
    Size? size,
    double textScale = 1,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final cubit = TransferCubit(
      repository: repository,
      telemetry: InMemoryTelemetry(),
      accounts: () => accounts,
      newId: () => 'order-0000000000000001',
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: BlocProvider.value(
            value: cubit,
            child: TransferScreen(
              onClose: () => closed++,
              onSeeMovement: seen.add,
              onDone: () => done++,
            ),
          ),
        ),
      ),
    );
    return cubit;
  }

  /// The input of the field labelled [label].
  Finder field(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(AppTextField),
    ),
    matching: find.byType(EditableText),
  );

  /// Presses the keys of [amount] on the keypad, `.` being the point.
  Future<void> typeAmount(WidgetTester tester, String amount) async {
    for (final key in amount.split('')) {
      final finder = find.descendant(
        of: find.byType(NumericKeypad),
        matching: find.text(key),
      );
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
    }
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('the form starts between the two spendable accounts and shows '
      'what is available', (tester) async {
    await pump(tester);

    expect(find.text('Transferir'), findsOneWidget);
    expect(find.text('Cuenta de ahorros ****4821'), findsOneWidget);
    expect(find.text('Cuenta corriente ****1093'), findsOneWidget);
    expect(find.text(r'Disponible: $3,570.35'), findsWidgets);
    expect(find.textContaining('Fondo de inversión'), findsNothing);
  });

  testWidgets('typing one is one dollar, and the cents come after the point', (
    tester,
  ) async {
    final cubit = await pump(tester);

    await typeAmount(tester, '1');

    expect(find.text(r'$1.00', findRichText: true), findsOneWidget);
    expect(cubit.state.amountCents, 100);

    await typeAmount(tester, '.5');

    expect(find.text(r'$1.50', findRichText: true), findsOneWidget);
    expect(cubit.state.amountCents, 150);
  });

  testWidgets('the amount is typed on keys of the screen, with no text field '
      'that would open the keyboard of the device', (tester) async {
    await pump(tester);

    expect(find.byType(NumericKeypad), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
    expect(field('Concepto (opcional)'), findsOneWidget);
  });

  testWidgets('delete removes the last key and holding it clears the amount', (
    tester,
  ) async {
    final cubit = await pump(tester);
    await typeAmount(tester, '12.5');
    final delete = find.bySemanticsLabel('Borrar');
    await tester.ensureVisible(delete);

    await tester.tap(delete);
    await tester.pump();

    expect(cubit.state.typedAmount, '12.');

    await tester.longPress(delete);
    await tester.pump();

    expect(cubit.state.typedAmount, isEmpty);
    expect(find.text(r'$0.00', findRichText: true), findsOneWidget);
  });

  testWidgets('back from the confirmation the amount is as it was typed', (
    tester,
  ) async {
    await pump(tester);
    await typeAmount(tester, '150.10');
    await tap(tester, 'Continuar');

    await tap(tester, 'Volver a editar');

    expect(find.text(r'$150.10', findRichText: true), findsOneWidget);
  });

  testWidgets('more than the available balance is said under the amount, '
      'with what is available, and the form stays', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^Desde:')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuenta corriente ****1093').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Hacia:')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuenta de ahorros ****4821').last);
    await tester.pumpAndSettle();
    await typeAmount(tester, '1250.01');

    await tap(tester, 'Continuar');

    expect(
      find.text(r'Saldo insuficiente. Disponible: $1,250.00'),
      findsOneWidget,
    );
    expect(find.text('Confirmar transferencia'), findsNothing);
  });

  testWidgets('the destination list leaves out the source account', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('^Hacia:')));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.textContaining('ahorros')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.textContaining('corriente')),
      findsOneWidget,
    );
  });

  testWidgets('confirming shows the summary, sends once and ends on the '
      'result, with no way back to the form', (tester) async {
    final answer = Completer<TransferOutcome>();
    repository.onSend = (_) => answer.future;
    await pump(tester);
    await typeAmount(tester, '150.10');
    await tester.enterText(field('Concepto (opcional)'), 'Arriendo');
    await tap(tester, 'Continuar');

    expect(find.text('Confirma tu transferencia'), findsOneWidget);
    expect(find.text('Arriendo'), findsOneWidget);

    await tap(tester, 'Confirmar transferencia');
    await tester.tap(find.byType(AppButton).first, warnIfMissed: false);
    await tester.pump();
    expect(repository.sent, hasLength(1));

    answer.complete(const TransferCompleted(reference: 'TRF-202610-AB12'));
    await tester.pump();

    expect(find.text('Transferencia realizada'), findsOneWidget);
    expect(find.text('TRF-202610-AB12'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    await tap(tester, 'Ver movimiento');
    expect(seen, ['savings']);
    await tap(tester, 'Volver al inicio');
    expect(done, 1);
  });

  testWidgets('a queued transfer says it is pending and offers no movement '
      'to see', (tester) async {
    repository.onSend = (_) async => const TransferQueued();
    await pump(tester);
    await typeAmount(tester, '150.10');
    await tap(tester, 'Continuar');
    await tap(tester, 'Confirmar transferencia');
    await tester.pump();

    expect(find.text('Transferencia pendiente'), findsOneWidget);
    expect(find.text('En cola'), findsOneWidget);
    expect(
      find.text('La enviaremos cuando recuperes la conexión.'),
      findsOneWidget,
    );
    expect(find.text('Ver movimiento'), findsNothing);
  });

  testWidgets('a rejected transfer says why', (tester) async {
    repository.onSend = (_) async =>
        const TransferRejected(TransferRejection.insufficientFunds);
    await pump(tester);
    await typeAmount(tester, '150.10');
    await tap(tester, 'Continuar');
    await tap(tester, 'Confirmar transferencia');
    await tester.pump();

    expect(find.text('No pudimos realizar la transferencia'), findsOneWidget);
    expect(
      find.text('El saldo de la cuenta de origen no alcanza.'),
      findsOneWidget,
    );
  });

  testWidgets('while the order is with the server, neither the system back '
      'nor the close button leaves the screen', (tester) async {
    final answer = Completer<TransferOutcome>();
    repository.onSend = (_) => answer.future;
    await pump(tester);

    // Before sending, both ways out are open.
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNotNull,
    );

    await typeAmount(tester, '150.10');
    await tap(tester, 'Continuar');
    await tap(tester, 'Confirmar transferencia');

    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(closed, 0);
    expect(find.text('Confirma tu transferencia'), findsOneWidget);

    answer.complete(const TransferCompleted(reference: 'TRF-1'));
    await tester.pump();
    expect(find.text('Transferencia realizada'), findsOneWidget);
  });

  testWidgets('a transfer the bank does not allow between those accounts '
      'says so', (tester) async {
    repository.onSend = (_) async =>
        const TransferRejected(TransferRejection.accountNotEligible);
    await pump(tester);
    await typeAmount(tester, '150.10');
    await tap(tester, 'Continuar');
    await tap(tester, 'Confirmar transferencia');
    await tester.pump();

    expect(
      find.text('Una de las cuentas no admite transferencias.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('a session the bank no longer accepts asks to sign in again '
      'and offers no retry', (tester) async {
    repository.onSend = (_) async =>
        const TransferStopped(TransferStop.sessionExpired);
    await pump(tester);
    await typeAmount(tester, '150.10');
    await tap(tester, 'Continuar');
    await tap(tester, 'Confirmar transferencia');
    await tester.pump();

    expect(
      find.text(
        'Tu sesión venció. Inicia sesión de nuevo para transferir. '
        'No se movió dinero.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsNothing);
    expect(find.text('Empezar de nuevo'), findsNothing);
    await tap(tester, 'Volver al inicio');
    expect(done, 1);
  });

  testWidgets('an order the bank says changed offers to start a new one, '
      'not to repeat it', (tester) async {
    repository.onSend = (_) async =>
        const TransferStopped(TransferStop.orderChanged);
    await pump(tester);
    await typeAmount(tester, '150.10');
    await tap(tester, 'Continuar');
    await tap(tester, 'Confirmar transferencia');
    await tester.pump();

    expect(
      find.text(
        'Esta transferencia ya no coincide con la que se envió primero. '
        'Revisa tus movimientos y empieza una nueva.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsNothing);

    await tap(tester, 'Empezar de nuevo');

    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Monto'), findsOneWidget);
  });

  testWidgets('a request the bank cannot read says no money moved and '
      'offers no retry', (tester) async {
    repository.onSend = (_) async =>
        const TransferStopped(TransferStop.notAccepted);
    await pump(tester);
    await typeAmount(tester, '150.10');
    await tap(tester, 'Continuar');
    await tap(tester, 'Confirmar transferencia');
    await tester.pump();

    expect(
      find.text(
        'El banco no pudo procesar esta solicitud. No se movió dinero.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsNothing);
    expect(find.text('Empezar de nuevo'), findsNothing);
  });

  testWidgets('opens on the result of an order whose outcome is unknown, '
      'offering only to send that same order', (tester) async {
    repository.unresolved = const TransferOrder(
      id: 'order-left-0000000001',
      fromAccountId: 'savings',
      toAccountId: 'checking',
      amountCents: 2500,
    );
    await pump(tester);

    expect(find.text('No pudimos enviar la transferencia'), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);
    // The customer is told what the order waits for, that repeating it
    // cannot move the money twice, and why no other can be started.
    expect(
      find.textContaining('Aún no sabemos si el banco la recibió'),
      findsOneWidget,
    );
    expect(
      find.textContaining('esta misma transferencia, nunca una segunda'),
      findsOneWidget,
    );
    expect(
      find.textContaining('no podrás iniciar otra'),
      findsOneWidget,
    );

    await tap(tester, 'Reintentar');
    await tester.pump();

    expect(repository.sent.single.id, 'order-left-0000000001');
  });

  testWidgets('a transfer that could not be sent offers to retry the same '
      'order', (tester) async {
    repository.onSend = (_) async => const TransferNotSent(TimeoutFailure());
    await pump(tester);
    await typeAmount(tester, '150.10');
    await tap(tester, 'Continuar');
    await tap(tester, 'Confirmar transferencia');
    await tester.pump();
    expect(find.text('No pudimos enviar la transferencia'), findsOneWidget);

    repository.onSend = (_) async =>
        const TransferCompleted(reference: 'TRF-1');
    await tap(tester, 'Reintentar');
    await tester.pump();

    expect(repository.sent.map((order) => order.id).toSet(), hasLength(1));
    expect(find.text('Transferencia realizada'), findsOneWidget);
  });

  testWidgets('with fewer than two spendable accounts, says so instead of '
      'showing a form that cannot be completed', (tester) async {
    await pump(tester, accounts: const [savings, fund]);

    expect(
      find.text('Necesitas al menos dos cuentas para transferir.'),
      findsOneWidget,
    );
    expect(find.text('Continuar'), findsNothing);
  });

  testWidgets('the form and the result meet the accessibility guidelines '
      'and fit a small phone at 130% text', (tester) async {
    final handle = tester.ensureSemantics();
    repository.onSend = (_) async => const TransferQueued();
    await pump(tester, size: smallPhone, textScale: largeText);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await typeAmount(tester, '150.10');
    await tap(tester, 'Continuar');
    await tap(tester, 'Confirmar transferencia');
    await tester.pump();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  group('QueuedTransfersNotice', () {
    Future<TransferOutboxCubit> pumpNotice(WidgetTester tester) async {
      final outbox = TransferOutboxCubit(
        repository: repository,
        onlineChanges: const Stream.empty(),
        isOnline: () async => false,
      );
      addTearDown(outbox.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BlocProvider.value(
              value: outbox,
              child: const QueuedTransfersNotice(),
            ),
          ),
        ),
      );
      return outbox;
    }

    testWidgets('takes no space with nothing queued', (tester) async {
      await pumpNotice(tester);

      expect(tester.getSize(find.byType(QueuedTransfersNotice)).height, 0);
    });

    testWidgets('says how many transfers wait for a connection', (
      tester,
    ) async {
      await pumpNotice(tester);

      repository.queued.add(const [
        QueuedTransfer(id: 'a', amountCents: 100),
        QueuedTransfer(id: 'b', amountCents: 200),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Tienes 2 transferencias en cola'), findsOne);
    });

    testWidgets('says that a queued transfer could not be sent, until it is '
        'dismissed', (tester) async {
      repository.onSettle = (_) async => null;
      await pumpNotice(tester);

      repository.refused.add('a');
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Una transferencia en cola no se pudo enviar. Revisa tus '
          'movimientos antes de repetirla.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Entendido'));
      await tester.pump();

      expect(tester.getSize(find.byType(QueuedTransfersNotice)).height, 0);
    });
  });
}
