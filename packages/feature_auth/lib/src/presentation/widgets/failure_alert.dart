import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The message above a form: why the last attempt failed, or that the device
/// is offline before the customer even tries.
///
/// Renders nothing when there is nothing to say.
class FailureAlert extends StatelessWidget {
  const FailureAlert({required this.failure, super.key});

  final AuthFailure? failure;

  @override
  Widget build(BuildContext context) {
    final isOffline =
        context.watch<ConnectivityCubit>().state == ConnectivityStatus.offline;
    final shown = failure ?? (isOffline ? AuthFailure.offline : null);
    if (shown == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.componentGap),
      child: InlineAlert(
        message: AuthStrings.failureMessage(shown),
        icon: shown == AuthFailure.offline
            ? Icons.wifi_off
            : Icons.warning_amber_rounded,
      ),
    );
  }
}
