import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

/// Narrow phone, the worst case for layouts at large text sizes.
const Size smallPhone = Size(320, 640);

/// Text size the screens must survive without overflowing.
const double largeText = 1.3;

typedef AccountsSnapshot = DataSnapshot<List<Account>>;
typedef MovementsSnapshot = DataSnapshot<List<Movement>>;

/// When the saved data of these tests was last synchronized.
final DateTime savedAt = now.subtract(const Duration(minutes: 8));

AccountsSnapshot accountsSnapshot(
  List<Account> accounts, {
  DataOrigin origin = DataOrigin.server,
}) {
  return AccountsSnapshot(
    value: accounts,
    origin: origin,
    syncedAt: origin == DataOrigin.server ? now : savedAt,
  );
}

MovementsSnapshot movementsSnapshot(
  List<Movement> movements, {
  DataOrigin origin = DataOrigin.server,
}) {
  return MovementsSnapshot(
    value: movements,
    origin: origin,
    syncedAt: origin == DataOrigin.server ? now : savedAt,
  );
}

/// What a screen of the feature needs around it: the repository, both
/// Blocs and the connectivity status, all driven by the test.
final class AccountsHarness {
  AccountsHarness({bool online = true})
    : monitor = FakeConnectivityMonitor(online: online);

  final FakeAccountsRepository repository = FakeAccountsRepository();
  final InMemoryTelemetry telemetry = InMemoryTelemetry();
  final FakeConnectivityMonitor monitor;

  /// Text handed to the system clipboard, newest last.
  final List<String> copied = [];

  /// Pumps [screen]. [accountId] also provides the movements of that
  /// account, as the detail route does.
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    String? accountId,
    double textScale = 1,
    int pageSize = MovementsBloc.defaultPageSize,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<Object?, Object?>;
          copied.add(arguments['text']! as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ConnectivityCubit>(
            create: (_) => ConnectivityCubit(monitor: monitor)..start(),
          ),
          BlocProvider<AccountsBloc>(
            create: (_) =>
                AccountsBloc(repository: repository, telemetry: telemetry)
                  ..add(const AccountsStarted()),
          ),
          if (accountId != null)
            BlocProvider<MovementsBloc>(
              create: (_) => MovementsBloc(
                repository: repository,
                accountId: accountId,
                telemetry: telemetry,
                now: () => now,
                pageSize: pageSize,
              )..add(const MovementsStarted()),
            ),
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
    // Lets the Blocs start and the connectivity cubit read the network.
    await tester.pump();
  }

  Future<void> deliverAccounts(
    WidgetTester tester,
    AccountsSnapshot snapshot,
  ) async {
    repository.accounts.add(snapshot);
    await tester.pump();
    await tester.pump();
  }

  Future<void> deliverMovements(
    WidgetTester tester,
    MovementsSnapshot snapshot,
  ) async {
    repository.movements.add(snapshot);
    await tester.pump();
    await tester.pump();
  }
}

/// Makes the view as small as the narrowest supported phone for one test.
void useSmallPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = smallPhone
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
