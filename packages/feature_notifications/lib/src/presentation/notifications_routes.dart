import 'dart:async';

import 'package:feature_notifications/src/presentation/inbox_screen.dart';
import 'package:feature_notifications/src/presentation/permission_primer_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:module_kit/module_kit.dart';

/// Locations owned by the notifications feature.
abstract final class NotificationsPaths {
  static const String inbox = '/notificaciones';
  static const String primer = '/notificaciones/permiso';
}

/// Opens the inbox over whatever is on screen.
void openInbox(BuildContext context) =>
    unawaited(context.push(NotificationsPaths.inbox));

/// Opens the invitation to turn notifications on.
void openPermissionPrimer(BuildContext context) =>
    unawaited(context.push(NotificationsPaths.primer));

/// The feature's routes. They belong inside the signed-in part of the app,
/// under the `NotificationsScope` that provides what they read.
List<RouteBase> notificationsRoutes({
  required DestinationResolver Function(BuildContext context) destinations,
}) {
  return [
    GoRoute(
      path: NotificationsPaths.inbox,
      builder: (context, state) => InboxScreen(
        destinations: destinations(context),
        onInvite: () => openPermissionPrimer(context),
      ),
    ),
    GoRoute(
      path: NotificationsPaths.primer,
      builder: (context, state) =>
          PermissionPrimerScreen(onDone: () => context.pop()),
    ),
  ];
}
