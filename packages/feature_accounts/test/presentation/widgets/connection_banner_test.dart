import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/presentation/widgets/connection_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeConnectivityMonitor monitor;
  late StreamController<bool> slow;

  Future<void> pumpBanner(
    WidgetTester tester, {
    bool hasSavedData = true,
  }) async {
    await tester.pumpWidget(
      BlocProvider<ConnectivityCubit>(
        create: (_) => ConnectivityCubit(
          monitor: monitor,
          slowChanges: slow.stream,
        )..start(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: ConnectionBanner(hasSavedData: hasSavedData)),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() {
    monitor = FakeConnectivityMonitor();
    slow = StreamController<bool>.broadcast();
  });

  tearDown(() => slow.close());

  testWidgets('shows nothing while the connection is fine', (tester) async {
    await pumpBanner(tester);

    expect(find.byType(StatusBanner), findsNothing);
  });

  testWidgets('offline, says that what is on screen was saved', (tester) async {
    monitor = FakeConnectivityMonitor(online: false);

    await pumpBanner(tester);

    expect(
      find.text('Sin conexión. Mostrando datos guardados'),
      findsOneWidget,
    );
  });

  testWidgets('offline with nothing on screen, does not claim saved data', (
    tester,
  ) async {
    monitor = FakeConnectivityMonitor(online: false);

    await pumpBanner(tester, hasSavedData: false);

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.textContaining('datos guardados'), findsNothing);
  });

  testWidgets('says so when requests are taking long', (tester) async {
    await pumpBanner(tester);

    slow.add(true);
    await tester.pump();
    await tester.pump();

    expect(find.text('Conexión lenta. Seguimos intentando'), findsOneWidget);

    slow.add(false);
    await tester.pump();
    await tester.pump();

    expect(find.byType(StatusBanner), findsNothing);
  });
}
