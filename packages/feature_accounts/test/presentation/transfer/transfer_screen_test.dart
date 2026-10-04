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

  Future<void> typeAmount(WidgetTester tester, String digits) async {
    await tester.enterText(field('Monto'), digits);
    await tester.pump();
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

  testWidgets('the amount is shown large as it is typed, cents last', (
    tester,
  ) async {
    await pump(tester);

    await typeAmount(tester, '15010');

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
    await typeAmount(tester, '125001');

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
    await typeAmount(tester, '15010');
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
    await typeAmount(tester, '15010');
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
    await typeAmount(tester, '15010');
    await tap(tester, 'Continuar');
    await tap(tester, 'Confirmar transferencia');
    await tester.pump();

    expect(find.text('No pudimos realizar la transferencia'), findsOneWidget);
    expect(
      find.text('El saldo de la cuenta de origen no alcanza.'),
      findsOneWidget,
    );
  });

  testWidgets('a transfer that could not be sent offers to retry the same '
      'order', (tester) async {
    repository.onSend = (_) async => const TransferNotSent(TimeoutFailure());
    await pump(tester);
    await typeAmount(tester, '15010');
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

    await typeAmount(tester, '15010');
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
  });
}
