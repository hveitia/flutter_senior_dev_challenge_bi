import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/load_state.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:flutter/material.dart';

/// Completes when a refresh that was just requested is over: at the first
/// state that is no longer loading, or when the Bloc is closed. It is what
/// keeps the pull-to-refresh indicator on screen for as long as the refresh
/// lasts.
Future<void> untilLoaded<S>(
  Stream<S> states,
  bool Function(S state) isLoading,
) {
  return states
      .firstWhere((state) => !isLoading(state))
      .then<void>((_) {}, onError: (Object _) {});
}

/// Takes the whole content area when a screen has nothing to show because
/// loading failed. The retry shows its progress in place, so the customer
/// does not lose sight of what went wrong while the app tries again.
class LoadFailureView extends StatelessWidget {
  const LoadFailureView({
    required this.failure,
    required this.isRetrying,
    required this.onRetry,
    super.key,
  });

  final LoadFailure failure;
  final bool isRetrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmptyState(
          icon: Icons.cloud_off,
          title: AccountsStrings.connectionFailedTitle,
          message: AccountsStrings.loadFailure(
            failure,
            attempts: ResiliencePolicy.maxAttempts,
          ),
        ),
        const SizedBox(height: AppSpacing.x6),
        AppButton(
          label: AccountsStrings.retry,
          isLoading: isRetrying,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

/// Sits above saved data that could not be brought up to date: it says so
/// and offers to try again, without taking the data away.
class OutdatedNotice extends StatelessWidget {
  const OutdatedNotice({
    required this.message,
    required this.isRetrying,
    required this.onRetry,
    super.key,
  });

  final String message;
  final bool isRetrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InlineAlert(message: message, tone: AppTone.warning),
        AppButton(
          label: AccountsStrings.retry,
          variant: AppButtonVariant.text,
          expand: false,
          isLoading: isRetrying,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
