import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_notifications/src/data/device_registrar.dart';
import 'package:feature_notifications/src/data/opened_notifications.dart';
import 'package:feature_notifications/src/data/ports.dart';
import 'package:feature_notifications/src/domain/notifications_repository.dart';
import 'package:feature_notifications/src/domain/push_message.dart';
import 'package:feature_notifications/src/notifications_telemetry.dart';
import 'package:feature_notifications/src/presentation/inbox_cubit.dart';
import 'package:feature_notifications/src/presentation/notifications_strings.dart';
import 'package:feature_notifications/src/presentation/permission_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:module_kit/module_kit.dart';

/// Everything about notifications that lives as long as the customer is
/// signed in: their inbox, what the system allows, this device's
/// registration and what happens when a push arrives or is tapped.
///
/// The app mounts it inside the signed-in part of the tree, once per
/// customer, and gives it that customer's repository and registrar.
class NotificationsScope extends StatelessWidget {
  const NotificationsScope({
    required this.repository,
    required this.registrar,
    required this.messaging,
    required this.opened,
    required this.memory,
    required this.settings,
    required this.segmentId,
    required this.destinations,
    required this.onOpenInbox,
    required this.onInvite,
    required this.child,
    this.destinationsReady = true,
    super.key,
  });

  /// How long the notice of a push stays on screen before leaving by
  /// itself.
  static const Duration noticeDuration = Duration(seconds: 6);

  final NotificationsRepository repository;
  final DeviceRegistrar registrar;
  final PushMessaging messaging;

  /// The notifications the customer tapped, kept until they can be opened.
  final OpenedNotifications opened;
  final PrimerMemory memory;
  final SystemSettings settings;

  /// The customer's segment, whose topic this device follows.
  final String segmentId;

  /// Where a tapped notification leads in this build.
  final DestinationResolver destinations;

  /// Whether [destinations] already knows what it can open. Right after the
  /// app starts it may not: which features are on comes with the published
  /// configuration. A tapped notification waits for it rather than being
  /// sent to the inbox for a destination that is about to exist.
  final bool destinationsReady;

  /// Opens the inbox.
  final void Function(BuildContext context) onOpenInbox;

  /// Opens the invitation to turn notifications on.
  final void Function(BuildContext context) onInvite;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<DeviceRegistrar>.value(
      value: registrar,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<InboxCubit>(
            // Followed from sign-in, so the bell knows what is unread
            // before the inbox is opened.
            create: (context) => InboxCubit(repository)..start(),
            lazy: false,
          ),
          BlocProvider<PermissionCubit>(
            create: (context) => PermissionCubit(
              messaging: messaging,
              memory: memory,
              settings: settings,
              telemetry: context.read<Telemetry>(),
            ),
            lazy: false,
          ),
        ],
        child: _Follower(
          registrar: registrar,
          messaging: messaging,
          opened: opened,
          segmentId: segmentId,
          destinations: destinations,
          destinationsReady: destinationsReady,
          onOpenInbox: onOpenInbox,
          onInvite: onInvite,
          child: child,
        ),
      ),
    );
  }
}

class _Follower extends StatefulWidget {
  const _Follower({
    required this.registrar,
    required this.messaging,
    required this.opened,
    required this.segmentId,
    required this.destinations,
    required this.destinationsReady,
    required this.onOpenInbox,
    required this.onInvite,
    required this.child,
  });

  final DeviceRegistrar registrar;
  final PushMessaging messaging;
  final OpenedNotifications opened;
  final String segmentId;
  final DestinationResolver destinations;
  final bool destinationsReady;
  final void Function(BuildContext context) onOpenInbox;
  final void Function(BuildContext context) onInvite;
  final Widget child;

  @override
  State<_Follower> createState() => _FollowerState();
}

class _FollowerState extends State<_Follower> with WidgetsBindingObserver {
  StreamSubscription<void>? _opened;
  StreamSubscription<PushMessage>? _foreground;
  bool _invited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(context.read<PermissionCubit>().check());

    _opened = widget.opened.arrivals.listen((_) => _openPending());
    _foreground = widget.messaging.foreground.listen(_notice);
    // One may have been waiting since before these screens existed: tapped
    // with nobody signed in, behind the lock, or the one that started the
    // app. After the frame, when there is a navigator to open it with.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
  }

  /// Opens the tapped notification that is waiting, if any. This widget
  /// exists only in front of a signed-in, unlocked customer, so taking it
  /// here is what keeps a tap from going around the lock.
  void _openPending() {
    // Left where it is until the destinations are known: it is taken when
    // they are.
    if (!mounted || !widget.destinationsReady) return;
    final message = widget.opened.take();
    if (message != null) _open(message);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings, perhaps with a different answer.
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<PermissionCubit>().check());
    }
  }

  @override
  void didUpdateWidget(_Follower oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.segmentId != oldWidget.segmentId) {
      unawaited(widget.registrar.register(widget.segmentId));
    }
    if (widget.destinationsReady && !oldWidget.destinationsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
    }
  }

  void _onPermission(BuildContext context, PermissionState state) {
    // Asked whatever the answer was: with permission the device is
    // registered, and without it a registration made earlier is withdrawn,
    // as when the customer switched notifications off in the system.
    if (state.permission != null) {
      unawaited(widget.registrar.register(widget.segmentId));
    }
    if (state.isPrimerDue && !_invited) {
      _invited = true;
      // After the frame: the screens under this scope are still being
      // built when the first answer arrives.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onInvite(this.context);
      });
    }
  }

  /// The customer tapped a system notification. It leads where the sender
  /// said, through the app's one resolver; a destination this build cannot
  /// open leads to the inbox, where the notification itself is.
  void _open(PushMessage message) {
    if (!mounted) return;
    context.read<Telemetry>().event(
      NotificationsTelemetry.opened,
      parameters: {
        NotificationsTelemetry.kindKey: message.kind.name,
        NotificationsTelemetry.sourceKey: NotificationsTelemetry.fromSystem,
      },
    );
    final open = widget.destinations.resolve(message.destination);
    (open ?? widget.onOpenInbox)(context);
  }

  /// A push arrived with the app open. The system shows nothing in that
  /// case, so the app says it, and the inbox updates through its listener.
  void _notice(PushMessage message) {
    if (!mounted || message.title.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message.title),
        // A notice with an action stays until dismissed unless told
        // otherwise, and would still be there over an unrelated screen.
        duration: NotificationsScope.noticeDuration,
        persist: false,
        action: SnackBarAction(
          label: NotificationsStrings.view,
          onPressed: () {
            if (mounted) widget.onOpenInbox(context);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_opened?.cancel());
    unawaited(_foreground?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PermissionCubit, PermissionState>(
      listener: _onPermission,
      child: widget.child,
    );
  }
}
