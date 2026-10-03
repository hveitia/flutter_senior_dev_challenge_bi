import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Narrow phone, the worst case for layouts at large text sizes.
const Size smallPhone = Size(320, 640);

/// Text size the screens must survive without overflowing.
const double largeText = 1.3;

/// Pumps [screen] under the app theme with the connectivity status the
/// access screens read. [providers] adds the Blocs the screen expects.
Future<FakeConnectivityMonitor> pumpAuth(
  WidgetTester tester,
  Widget screen, {
  List<BlocProvider<dynamic>> providers = const [],
  bool online = true,
  double textScale = 1,
}) async {
  final monitor = FakeConnectivityMonitor(online: online);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ConnectivityCubit>(
          create: (_) => ConnectivityCubit(monitor: monitor)..start(),
        ),
        ...providers,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: screen,
      ),
    ),
  );
  // Lets the connectivity cubit read the initial state of the network.
  await tester.pump();
  return monitor;
}

/// Runs the screen on screen through the accessibility guidelines.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void useSmallPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = smallPhone
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
