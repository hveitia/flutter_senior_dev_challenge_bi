import 'package:feature_accounts/src/domain/load_state.dart';
import 'package:feature_accounts/src/domain/movement.dart';
import 'package:feature_accounts/src/domain/movement_filter.dart';

/// Everything the accounts screens say to the customer.
abstract final class AccountsStrings {
  static const String accountsTitle = 'Cuentas';
  static const String totalBalance = 'Saldo total';
  static const String available = 'Disponible';
  static const String ledger = 'Contable';
  static const String accountNumber = 'Cuenta';
  static const String copyAccountNumber = 'Copiar número de cuenta';
  static const String accountNumberCopied = 'Número de cuenta copiado';

  static const String totalWithoutInvestments = 'Sin contar tus inversiones';
  static const String transfer = 'Transferir';
  static const String balanceCaption = 'Todo tu dinero, en un solo lugar';
  static const String balanceFailed = 'No pudimos cargar tu saldo';
  static const String carouselFailed = 'No pudimos cargar tus cuentas';
  static const String investmentsTitle = 'Inversiones';
  static const String investedTotal = 'Total invertido';
  static const String seeInvestments = 'Ver inversiones';
  static const String investmentsFailed = 'No pudimos cargar tus inversiones';
  static const String balanceWithInvestmentsCaption =
      'Tus cuentas y tus inversiones';

  static String trendCaption(int days) => 'Tus cuentas, últimos $days días';
  static const String trendNotEnough =
      'Aún no hay suficientes movimientos para mostrar la tendencia';
  static String trendLabel(int days) =>
      'Tendencia de tus cuentas en los últimos $days días';
  static String trendLabelWithAmounts(
    int days, {
    required String from,
    required String to,
  }) => '${trendLabel(days)}: de $from a $to';
  static const String hideAmounts = 'Ocultar montos';
  static const String showAmounts = 'Mostrar montos';
  static const String recentMovementsTitle = 'Últimos movimientos';
  static const String seeAll = 'Ver todos';

  static const String searchLabel = 'Buscar movimientos';
  static const String searchHint = 'Nombre o descripción';
  static const String more = 'Ver más';
  static const String retry = 'Reintentar';
  static const String refresh = 'Actualizar';
  static const String back = 'Volver';

  static const String preparingTitle = 'Estamos preparando tu cuenta';
  static const String preparingMessage =
      'Tus cuentas aparecerán aquí en cuanto estén listas.';

  static const String noMovementsTitle = 'Aún no tienes movimientos';
  static const String noMovementsMessage =
      'Cuando uses esta cuenta, verás aquí cada movimiento.';
  static const String noMatchesTitle = 'No hay movimientos';
  static const String noMatchesMessage = 'Prueba con otro nombre o filtro.';

  static const String narrowedScope =
      'La búsqueda y los filtros solo ven los movimientos cargados. '
      'Toca «Ver más» para incluir los anteriores.';

  static const String accountMissingTitle = 'No encontramos esta cuenta';
  static const String accountMissingMessage =
      'Vuelve a tus cuentas y elige una de la lista.';

  static const String connectionFailedTitle = 'No pudimos conectarnos';
  static const String checkConnection =
      'Revisa tu conexión e intenta de nuevo.';
  static const String unexpectedFailure =
      'Algo no salió como esperábamos. Intenta de nuevo.';

  static const String movementsFailed = 'No pudimos cargar tus movimientos';
  static const String accountsOutdated =
      'No pudimos actualizar tus cuentas. Mostramos los últimos datos '
      'guardados.';
  static const String movementsOutdated =
      'No pudimos actualizar tus movimientos. Mostramos los últimos datos '
      'guardados.';

  static const String accountsIncomplete =
      'No pudimos mostrar todas tus cuentas, por eso no calculamos el saldo '
      'total.';
  static const String movementsIncomplete =
      'No pudimos mostrar algunos movimientos de esta cuenta.';

  static const String movementDetailTitle = 'Detalle del movimiento';
  static const String close = 'Cerrar';
  static const String dateAndTime = 'Fecha y hora';
  static const String account = 'Cuenta';
  static const String reference = 'Referencia';
  static const String category = 'Categoría';
  static const String channel = 'Canal';
  static const String copyReference = 'Copiar referencia';
  static const String referenceCopied = 'Referencia copiada';

  /// Why the screen has nothing to show. After the allowed attempts it says
  /// how many were made, so the customer knows the app already insisted.
  static String loadFailure(LoadFailure failure, {required int attempts}) {
    return switch (failure) {
      LoadFailure.timeout ||
      LoadFailure.unavailable => 'Lo intentamos $attempts veces sin éxito.',
      LoadFailure.offline => checkConnection,
      LoadFailure.unexpected => unexpectedFailure,
    };
  }

  static String filter(MovementFilter filter) => switch (filter) {
    MovementFilter.all => 'Todos',
    MovementFilter.income => 'Ingresos',
    MovementFilter.expenses => 'Egresos',
    MovementFilter.thisMonth => 'Este mes',
  };

  static String categoryName(MovementCategory category) => switch (category) {
    MovementCategory.salary => 'Nómina',
    MovementCategory.transfer => 'Transferencia',
    MovementCategory.groceries => 'Supermercado',
    MovementCategory.dining => 'Restaurantes y cafés',
    MovementCategory.transport => 'Transporte',
    MovementCategory.services => 'Servicios',
    MovementCategory.entertainment => 'Entretenimiento',
    MovementCategory.health => 'Salud',
    MovementCategory.cash => 'Efectivo',
    MovementCategory.other => 'Otros',
  };

  static String channelName(MovementChannel channel) => switch (channel) {
    MovementChannel.debitCard => 'Tarjeta de débito',
    MovementChannel.transfer => 'Transferencia',
    MovementChannel.payroll => 'Acreditación de nómina',
    MovementChannel.atm => 'Cajero automático',
    MovementChannel.app => 'Aplicación',
    MovementChannel.other => 'Otro',
  };

  static String status(MovementStatus status) => switch (status) {
    MovementStatus.completed => 'Completado',
    MovementStatus.pending => 'Pendiente',
  };
}
