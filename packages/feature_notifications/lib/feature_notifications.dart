/// Push notifications and the inbox of the signed-in customer.
///
/// The app mounts a `NotificationsScope` for the customer, adds the routes
/// and places the bell in the home. Firebase Messaging, Firestore and device
/// storage are reached only through
/// `package:feature_notifications/adapters.dart`, which the composition root
/// wires.
library;

export 'src/data/device_registrar.dart';
export 'src/data/ports.dart';
export 'src/domain/inbox_item.dart';
export 'src/domain/notifications_repository.dart';
export 'src/domain/push_message.dart';
export 'src/notifications_telemetry.dart';
export 'src/presentation/inbox_cubit.dart';
export 'src/presentation/notifications_bell.dart';
export 'src/presentation/notifications_routes.dart';
export 'src/presentation/notifications_scope.dart';
export 'src/presentation/permission_cubit.dart';
