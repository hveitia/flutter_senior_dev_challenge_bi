import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/transfer.dart';

/// Everything the transfer screens say to the customer.
abstract final class TransferStrings {
  static const String title = 'Transferir';
  static const String from = 'Desde';
  static const String to = 'Hacia';
  static const String chooseAccount = 'Elige una cuenta';
  static const String amount = 'Monto';
  static const String concept = 'Concepto (opcional)';
  static const String next = 'Continuar';
  static const String confirmTitle = 'Confirma tu transferencia';
  static const String confirm = 'Confirmar transferencia';
  static const String edit = 'Volver a editar';
  static const String reference = 'Referencia';
  static const String conceptLabel = 'Concepto';
  static const String close = 'Cerrar';

  static const String completedTitle = 'Transferencia realizada';
  static const String queuedTitle = 'Transferencia pendiente';
  static const String queuedMessage =
      'La enviaremos cuando recuperes la conexión.';
  static const String queuedChip = 'En cola';
  static const String rejectedTitle = 'No pudimos realizar la transferencia';
  static const String notSentTitle = 'No pudimos enviar la transferencia';
  static const String notSentMessage =
      'No se ha movido dinero dos veces: puedes reintentar con tranquilidad.';
  static const String retry = 'Reintentar';
  static const String seeMovement = 'Ver movimiento';
  static const String backHome = 'Volver al inicio';
  static const String noAccountsToTransfer =
      'Necesitas al menos dos cuentas para transferir.';

  static const String transferAction = 'Transferir';

  static String available(int cents) =>
      'Disponible: ${formatAmount(cents).text}';

  static String? errorText(TransferFormError? error, {int? availableCents}) =>
      switch (error) {
        null => null,
        TransferFormError.missingAccounts =>
          'Elige la cuenta de origen y la de destino.',
        TransferFormError.sameAccount =>
          'Elige una cuenta de destino distinta a la de origen.',
        TransferFormError.missingAmount => 'Ingresa el monto a transferir.',
        TransferFormError.overLimit =>
          'El máximo por transferencia es '
              '${formatAmount(TransferLimits.maxCents).text}.',
        TransferFormError.insufficientFunds =>
          'Saldo insuficiente. ${available(availableCents ?? 0)}',
        TransferFormError.conceptTooLong =>
          'El concepto admite hasta ${TransferLimits.maxConceptLength} '
              'caracteres.',
      };

  static String rejection(TransferRejection reason) => switch (reason) {
    TransferRejection.insufficientFunds =>
      'El saldo de la cuenta de origen no alcanza.',
    TransferRejection.unknownAccount =>
      'Una de las cuentas ya no está disponible.',
    TransferRejection.accountNotEligible =>
      'Una de las cuentas no admite transferencias.',
    TransferRejection.currencyMismatch =>
      'Las cuentas están en monedas distintas.',
    TransferRejection.sameAccount =>
      'La cuenta de origen y la de destino son la misma.',
    TransferRejection.invalidAmount => 'El monto no es válido.',
    TransferRejection.invalidRequest =>
      'No pudimos procesar la solicitud. Inténtalo de nuevo.',
  };

  static const String startOver = 'Empezar de nuevo';

  /// What to say about an order that cannot go on. Each says whether money
  /// moved, because that is what the customer needs to know first.
  static String stopped(TransferStop reason) => switch (reason) {
    TransferStop.sessionExpired =>
      'Tu sesión venció. Inicia sesión de nuevo para transferir. '
          'No se movió dinero.',
    TransferStop.orderChanged =>
      'Esta transferencia ya no coincide con la que se envió primero. '
          'Revisa tus movimientos y empieza una nueva.',
    TransferStop.notAccepted =>
      'El banco no pudo procesar esta solicitud. No se movió dinero.',
  };

  static const String queuedRefused =
      'Una transferencia en cola no se pudo enviar. Revisa tus '
      'movimientos antes de repetirla.';

  static String queuedNotice(int count) => count == 1
      ? 'Tienes 1 transferencia en cola. La enviaremos cuando recuperes '
            'la conexión.'
      : 'Tienes $count transferencias en cola. Las enviaremos cuando '
            'recuperes la conexión.';

  static String queuedRejected(TransferRejection reason) =>
      'Una transferencia en cola no se realizó. ${rejection(reason)}';
  static const String dismiss = 'Entendido';

  static const String provisioningFailed =
      'No pudimos preparar tu cuenta. Inténtalo de nuevo.';
}
