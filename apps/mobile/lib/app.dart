import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app_dependencies.dart';
import 'package:banca_digital/app_router.dart';
import 'package:banca_digital/saved_customer_data.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Root widget of the mobile app and its composition root for widgets: it
/// provides what the features read from the tree and mounts their routes.
class BancaDigitalApp extends StatefulWidget {
  const BancaDigitalApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  static const String productName = 'Banca Digital';

  @override
  State<BancaDigitalApp> createState() => _BancaDigitalAppState();
}

class _BancaDigitalAppState extends State<BancaDigitalApp> {
  late final SessionBloc _session;
  late final StreamSubscription<SessionState> _sessionSubscription;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final dependencies = widget.dependencies;
    _session = SessionBloc(
      repository: dependencies.authRepository,
      biometrics: dependencies.biometrics,
      telemetry: dependencies.telemetry,
    )..add(const SessionStarted());
    _sessionSubscription = _session.stream.listen(_onSessionChanged);
    _router = createAppRouter(
      session: _session,
      productName: BancaDigitalApp.productName,
      dependencies: dependencies,
    );
  }

  /// A session that ended leaves nothing of the customer on the device.
  /// This also runs when the app starts without a session, which covers a
  /// previous use that was closed before it could clean up.
  void _onSessionChanged(SessionState state) {
    if (state is SessionSignedOut) unawaited(_removeSavedCustomerData());
  }

  Future<void> _removeSavedCustomerData() async {
    // The same state takes the customer's screens off the tree in the next
    // frame, and with them the listeners on the saved copy. The copy cannot
    // be removed while something is still reading it.
    await WidgetsBinding.instance.endOfFrame;

    final dependencies = widget.dependencies;
    try {
      await dependencies.savedCustomerData.clear();
    } on Object catch (error, stackTrace) {
      // Signing out already happened; a clean-up that fails is reported
      // and tried again the next time the app starts without a session.
      dependencies.telemetry.recordError(
        RedactedError(error.runtimeType),
        stackTrace,
        reason: StepwiseSavedCustomerData.clearFailed,
      );
    }
  }

  @override
  void dispose() {
    unawaited(_sessionSubscription.cancel());
    _router.dispose();
    unawaited(_session.close());
    unawaited(widget.dependencies.connectivity.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<Telemetry>.value(value: dependencies.telemetry),
        RepositoryProvider<AuthRepository>.value(
          value: dependencies.authRepository,
        ),
        RepositoryProvider<BiometricAuthenticator>.value(
          value: dependencies.biometrics,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SessionBloc>.value(value: _session),
          BlocProvider<ConnectivityCubit>.value(
            value: dependencies.connectivity,
          ),
        ],
        child: MaterialApp.router(
          title: BancaDigitalApp.productName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: _router,
        ),
      ),
    );
  }
}
