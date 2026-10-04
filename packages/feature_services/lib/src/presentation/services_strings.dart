/// What the services screens say to the customer.
abstract final class ServicesStrings {
  static const String title = 'Servicios';
  static const String subtitle = 'Productos del banco y de nuestros aliados';
  static const String bankSection = 'Del banco';
  static const String partnersSection = 'De aliados';
  static const String partnerBadge = 'Aliado';

  static const String emptyTitle = 'Aún no hay servicios disponibles';
  static const String emptyMessage =
      'Cuando haya productos para ti, los encontrarás aquí.';

  static const String recommendationsTitle = 'Para ti';

  static const String close = 'Cerrar';
  static const String moreOptions = 'Más opciones';
  static const String loadAgain = 'Volver a cargar';

  static String serviceOf(String partner) => 'Servicio de $partner';
  static String contentOf(String partner) => 'Contenido de $partner';
  static String loading(String service) => 'Cargando $service';

  static const String unavailableTitle = 'Servicio no disponible';
  static const String unavailableMessage =
      'Este servicio no está disponible por ahora. Tu cuenta y tus saldos '
      'no se ven afectados.';
  static const String offlineMessage =
      'No tienes conexión. Revisa tu red e intenta de nuevo. Tu cuenta y '
      'tus saldos no se ven afectados.';
  static const String retry = 'Reintentar';
  static const String backToServices = 'Volver a Servicios';

  static const String completed = 'Operación completada.';
  static String completedWithReference(String reference) =>
      'Operación completada. Referencia: $reference';

  static const String outsideTitle = 'Vas a salir de la app';
  static String outsideMessage({
    required String site,
    required String partner,
  }) =>
      'Este enlace lleva a $site, fuera de $partner. Se abrirá en el '
      'navegador de tu teléfono.';
  static const String outsideOpen = 'Abrir en el navegador';
  static const String outsideStay = 'Quedarme aquí';
  static const String outsideFailed = 'No pudimos abrir el enlace.';
}
