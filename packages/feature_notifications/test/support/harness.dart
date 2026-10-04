import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fakes a notifications screen needs and the tree that provides them.
final class NotificationsHarness {
  NotificationsHarness({
    NotificationPermission permission = NotificationPermission.granted,
    bool primerAnswered = false,
  }) : messaging = FakePushMessaging(current: permission),
       memory = FakePrimerMemory(wasAnswered: primerAnswered);

  final FakeNotificationsRepository repository = FakeNotificationsRepository();
  final FakePushMessaging messaging;
  final FakePrimerMemory memory;
  final FakeSystemSettings settings = FakeSystemSettings();
  final InMemoryTelemetry telemetry = InMemoryTelemetry();
  final FakeConnectivityMonitor monitor = FakeConnectivityMonitor();

  late final InboxCubit inbox = InboxCubit(repository);
  late final PermissionCubit permission = PermissionCubit(
    messaging: messaging,
    memory: memory,
    settings: settings,
    telemetry: telemetry,
  );
  late final ConnectivityCubit connectivity = ConnectivityCubit(
    monitor: monitor,
  );

  /// Pumps [child] with everything a notifications screen reads.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1,
    Size? size,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    addTearDown(inbox.close);
    addTearDown(permission.close);
    addTearDown(connectivity.close);

    await tester.pumpWidget(
      RepositoryProvider<Telemetry>.value(
        value: telemetry,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<InboxCubit>.value(value: inbox),
            BlocProvider<PermissionCubit>.value(value: permission),
            BlocProvider<ConnectivityCubit>.value(value: connectivity),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: app!,
            ),
            home: child,
          ),
        ),
      ),
    );
  }
}
