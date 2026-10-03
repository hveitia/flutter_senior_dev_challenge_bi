import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';
import 'package:feature_auth/src/presentation/session/session_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shown when the customer is signed in but their profile cannot be loaded.
class SessionUnavailableScreen extends StatelessWidget {
  const SessionUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SessionBloc>();
    final state = context.watch<SessionBloc>().state;
    final isRetrying = state is SessionUnavailable && state.isRetrying;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.metrics.screenMargin),
            child: isRetrying
                ? const CircularProgressIndicator(
                    semanticsLabel: AuthStrings.retry,
                  )
                : EmptyState(
                    icon: Icons.cloud_off,
                    title: AuthStrings.unavailableTitle,
                    message: AuthStrings.unavailableBody,
                    primaryActionLabel: AuthStrings.retry,
                    onPrimaryAction: () =>
                        bloc.add(const SessionRetryRequested()),
                    secondaryActionLabel: AuthStrings.signOut,
                    onSecondaryAction: () =>
                        bloc.add(const SessionSignOutRequested()),
                  ),
          ),
        ),
      ),
    );
  }
}
