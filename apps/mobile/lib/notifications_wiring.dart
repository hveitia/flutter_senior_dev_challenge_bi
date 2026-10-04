import 'package:app_platform/app_platform.dart';
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
    required this.devicesFor,
    required this.identity,
    required this.registrationMemory,
    required this.messaging,
    required this.memory,
    required this.settings,
  });

  /// What this installation remembers about its own registration.
  final RegistrationMemory registrationMemory;

  /// The inbox of the customer with the given uid.
  final NotificationsRepository Function(String uid) repositoryFor;

  /// Where that customer's devices are registered.
  final DeviceStore Function(String uid) devicesFor;
  final DeviceIdentity identity;
  final PushMessaging messaging;
  final PrimerMemory memory;
  final SystemSettings settings;
}

/// The destination resolver for the customer whose configuration is in the
/// tree: the same one the home uses, so a notification leads only where a
/// home action could.
AppDestinationResolver destinationsFor(BuildContext context) {
  final config = context.read<RemoteConfigCubit>();
  return AppDestinationResolver(
    features: () => config.state.segment?.features ?? FeatureFlags.allOff,
  );
}

/// Mounts the notifications of the signed-in customer: their inbox, this
/// device's registration and the handling of pushes.
///
/// It belongs inside the customer's scope. Everything it creates is the
/// customer's own and is replaced when another customer signs in.
class CustomerNotifications extends StatefulWidget {
  const CustomerNotifications({
    required this.dependencies,
    required this.child,
    super.key,
  });

  final NotificationsDependencies dependencies;
  final Widget child;

  @override
  State<CustomerNotifications> createState() => _CustomerNotificationsState();
}

class _CustomerNotificationsState extends State<CustomerNotifications> {
  String? _uid;
  late NotificationsRepository _repository;
  late DeviceRegistrar _registrar;

  /// Each customer gets a repository and a registrar of their own, so what
  /// was read or registered for one never reaches the next.
  void _prepareFor(String uid) {
    if (uid == _uid) return;
    final dependencies = widget.dependencies;
    _uid = uid;
    _repository = dependencies.repositoryFor(uid);
    _registrar = DeviceRegistrar(
      uid: uid,
      memory: dependencies.registrationMemory,
      messaging: dependencies.messaging,
      devices: dependencies.devicesFor(uid),
      identity: dependencies.identity,
      telemetry: context.read<Telemetry>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionBloc>().state;
    if (session is! SessionSignedIn) return widget.child;

    final dependencies = widget.dependencies;
    _prepareFor(session.profile.uid);

    return NotificationsScope(
      key: ValueKey(session.profile.uid),
      repository: _repository,
      registrar: _registrar,
      messaging: dependencies.messaging,
      memory: dependencies.memory,
      settings: dependencies.settings,
      segmentId: session.profile.segment.id,
      destinations: destinationsFor(context),
      onOpenInbox: openInbox,
      onInvite: openPermissionPrimer,
      child: widget.child,
    );
  }
}

/// Makes this device stop being the customer's: no topic, no registration,
/// no address. Called before the session ends, while there still is a
/// session to remove the registration with.
///
/// It never fails and never takes long: see [DeviceRegistrar.forget].
Future<void> forgetDevice(BuildContext context) {
  final DeviceRegistrar registrar;
  try {
    registrar = context.read<DeviceRegistrar>();
  } on ProviderNotFoundException {
    return Future.value();
  }
  return registrar.forget();
}
