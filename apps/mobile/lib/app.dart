import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app_dependencies.dart';
import 'package:banca_digital/app_router.dart';
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
    _router = createAppRouter(
      session: _session,
      productName: BancaDigitalApp.productName,
    );
  }

  @override
  void dispose() {
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
