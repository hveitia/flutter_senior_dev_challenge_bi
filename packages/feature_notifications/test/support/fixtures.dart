import 'package:feature_notifications/feature_notifications.dart';

/// The moment every test runs at: 3 October 2026, 10:00 local time.
final DateTime now = DateTime(2026, 10, 3, 10);

final InboxItem salary = InboxItem(
  id: 'n-salary',
  title: r'Recibiste $1,850.00',
  body: 'Tu nómina ya está disponible en tu cuenta de ahorros.',
  kind: NotificationKind.movement,
  destination: 'accounts',
  createdAt: DateTime(2026, 10, 3, 9, 12),
  isRead: false,
);

final InboxItem signIn = InboxItem(
  id: 'n-sign-in',
  title: 'Nuevo inicio de sesión',
  body: 'Ingresaste desde tu dispositivo habitual.',
  kind: NotificationKind.security,
  destination: 'profile',
  createdAt: DateTime(2026, 10, 3, 8, 30),
  isRead: false,
);

final InboxItem travel = InboxItem(
  id: 'n-travel',
  title: 'Un beneficio para tu próximo viaje',
  body: 'Conoce los seguros de viaje de nuestros aliados.',
  kind: NotificationKind.benefit,
  destination: 'partner:travelInsurance',
  createdAt: DateTime(2026, 10, 2, 15, 20),
  isRead: true,
);

final InboxItem transfer = InboxItem(
  id: 'n-transfer',
  title: 'Transferencia completada',
  body: r'Enviaste $200.00 a tu cuenta corriente.',
  kind: NotificationKind.movement,
  destination: 'accounts',
  createdAt: DateTime(2026, 9, 28, 16, 4),
  isRead: true,
);

InboxSnapshot fresh(List<InboxItem> items) =>
    InboxSnapshot(items: items, fromCache: false);

InboxSnapshot saved(List<InboxItem> items) =>
    InboxSnapshot(items: items, fromCache: true);
