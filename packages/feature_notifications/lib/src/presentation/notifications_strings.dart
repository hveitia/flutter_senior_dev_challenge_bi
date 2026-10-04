import 'package:module_kit/module_kit.dart';

/// What the notifications feature says to the customer.
abstract final class NotificationsStrings {
  static const String inboxTitle = 'Notificaciones';
  static const String today = 'HOY';
  static const String earlier = 'ANTERIORES';
  static const String unread = 'Nueva';
  static const String yesterday = 'Ayer';

  static const String emptyTitle = 'Aún no tienes notificaciones';
  static const String emptyMessage =
      'Aquí verás los avisos sobre tu dinero y la seguridad de tu cuenta.';

  static const String loadFailed = 'No pudimos cargar tus notificaciones';
  static const String outdated =
      'No pudimos actualizar tus notificaciones. Mostramos las guardadas.';
  static const String retry = 'Reintentar';

  static const String disabledTitle = 'Tienes las notificaciones desactivadas';
  static const String openSettings = 'Activar en Ajustes';
  static const String notEnabledTitle = 'Aún no activas las notificaciones';
  static const String enable = 'Activar notificaciones';

  static const String primerTitle = 'Entérate al instante';
  static const String primerMessage =
      'Recibe información útil sobre tu dinero y la seguridad de tu cuenta.';
  static const String primerMovements = 'Movimientos de tu cuenta';
  static const String primerSecurity = 'Alertas de seguridad';
  static const String primerBenefits = 'Beneficios para ti';
  static const String primerFootnote =
      'Puedes cambiar tus preferencias cuando quieras.';
  static const String primerAccept = 'Activar notificaciones';
  static const String primerDecline = 'Ahora no';

  static const String view = 'Ver';

  static const String bell = 'Notificaciones';

  /// What a screen reader says for the bell.
  static String bellWithUnread(int count) => count == 1
      ? 'Notificaciones, 1 sin leer'
      : 'Notificaciones, $count sin leer';

  static const List<String> _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// `28 sep`.
  static String shortDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  /// Where a notification leads, in words, or null when the name is not one
  /// the app has words for.
  static String? destinationLabel(String destination) {
    if (destination.startsWith(Destinations.partnerPrefix)) {
      return 'Servicios de aliados';
    }
    return switch (destination) {
      Destinations.accounts => 'Tus cuentas',
      Destinations.transfer => 'Transferir',
      Destinations.services => 'Servicios',
      Destinations.profile => 'Perfil',
      _ => null,
    };
  }
}
