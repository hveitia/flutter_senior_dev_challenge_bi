import 'package:design_system/design_system.dart';
import 'package:feature_services/src/presentation/mini_app/mini_app_cubit.dart';
import 'package:feature_services/src/presentation/services_strings.dart';
import 'package:flutter/material.dart';

/// Shown instead of a partner's page that cannot be shown.
///
/// It says what the customer most needs to hear when something of a third
/// party fails inside a bank's app: their money is not involved.
class MiniAppUnavailableView extends StatelessWidget {
  const MiniAppUnavailableView({
    required this.onBackToServices,
    this.reason,
    this.onRetry,
    super.key,
  });

  /// Why the page is not shown. Only being offline changes what is said.
  final MiniAppUnavailableReason? reason;

  /// Null when trying again cannot help, such as a service this version of
  /// the app does not have.
  final VoidCallback? onRetry;
  final VoidCallback onBackToServices;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.metrics.screenMargin),
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: ServicesStrings.unavailableTitle,
          message: reason == MiniAppUnavailableReason.offline
              ? ServicesStrings.offlineMessage
              : ServicesStrings.unavailableMessage,
          primaryActionLabel: onRetry == null
              ? ServicesStrings.backToServices
              : ServicesStrings.retry,
          onPrimaryAction: onRetry ?? onBackToServices,
          secondaryActionLabel: onRetry == null
              ? null
              : ServicesStrings.backToServices,
          onSecondaryAction: onRetry == null ? null : onBackToServices,
        ),
      ),
    );
  }
}
