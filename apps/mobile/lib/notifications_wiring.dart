import 'package:banca_digital/destinations.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the notifications feature needs from outside the widget tree.
///
/// `main` builds it on Firebase and the device; tests build it from fakes.
final class NotificationsDependencies {
  const NotificationsDependencies({
    required this.repositoryFor,
    required this.registrations,
    required this.opened,
    required this.messaging,
    required this.memory,
    required this.settings,
  });

  /// The inbox of the customer with the given uid.
  final NotificationsRepository Function(String uid) repositoryFor;

  /// This device's registration, one registrar per session. It outlives the
  /// customer's screens, so a session that ends by any path can still be
  /// cleaned up after.
  final DeviceRegistrations registrations;

  /// The notification the customer tapped, kept from the moment the app
  /// starts until a signed-in, unlocked session can open it.
  final OpenedNotifications opened;
  final PushMessaging messaging;
  final PrimerMemory memory;
  final SystemSettings settings;
}

/// Mounts the notifications of the signed-in customer: their inbox, this
/// device's registration and the handling of pushes.
///
/// It belongs inside the customer's scope, which exists only while a
/// session is active: not while it is locked, pending or closed. So a
/// tapped notification is opened, and the invitation shown, only in front
/// of a customer who is in.
class CustomerNotifications extends StatefulWidget {
  const CustomerNotifications({
    required this.dependencies,
    required this.destinations,
    required this.child,
    super.key,
  });

  final NotificationsDependencies dependencies;

  /// The resolver the home uses, so a notification leads only where a home
  /// action could, partners' mini apps included.
  final AppDestinationResolver Function(BuildContext context) destinations;
  final Widget child;

  @override
  State<CustomerNotifications> createState() => _CustomerNotificationsState();
}

class _CustomerNotificationsState extends State<CustomerNotifications> {
  String? _uid;
  NotificationsRepository? _repository;

  /// Each customer gets a repository of their own, so what was read for one
  /// never reaches the next.
  NotificationsRepository _repositoryFor(String uid) {
    if (_repository case final repository? when uid == _uid) return repository;
    _uid = uid;
    return _repository = widget.dependencies.repositoryFor(uid);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionBloc>().state;
    if (session is! SessionSignedIn) {
      _uid = null;
      _repository = null;
      return widget.child;
    }

    final dependencies = widget.dependencies;
    final uid = session.profile.uid;

    return NotificationsScope(
      key: ValueKey(uid),
      repository: _repositoryFor(uid),
      // Asked for on every build: a session that ended forgot its
      // registrar, and the next one, even of the same customer, gets a new
      // one.
      registrar: dependencies.registrations.of(uid),
      messaging: dependencies.messaging,
      opened: dependencies.opened,
      memory: dependencies.memory,
      settings: dependencies.settings,
      segmentId: session.profile.segment.id,
      destinations: widget.destinations(context),
      onOpenInbox: openInbox,
      onInvite: openPermissionPrimer,
      child: widget.child,
    );
  }
}

/// Makes this device stop being the customer's while their session is still
/// open: no topic, no registration, no address. Removing the registration
/// needs the session, which is why this runs before it closes.
///
/// It never fails and never takes long: see [DeviceRegistrar.forget]. A
/// session that ends without passing through here is cleaned up as far as
/// still possible by [DeviceRegistrations.sessionEnded].
Future<void> forgetDevice(BuildContext context) {
  final DeviceRegistrar registrar;
  try {
    registrar = context.read<DeviceRegistrar>();
  } on ProviderNotFoundException {
    return Future.value();
  }
  return registrar.forget();
}
