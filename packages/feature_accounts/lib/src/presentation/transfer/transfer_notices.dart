import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/presentation/transfer/account_provisioning_cubit.dart';
import 'package:feature_accounts/src/presentation/transfer/transfer_outbox_cubit.dart';
import 'package:feature_accounts/src/presentation/transfer/transfer_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tells the customer about the orders waiting on this device, and about a
/// queued order the server refused. It takes no space when there is nothing
/// to say.
///
/// It reads [TransferOutboxCubit] from the tree.
class QueuedTransfersNotice extends StatelessWidget {
  const QueuedTransfersNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransferOutboxCubit>().state;
    final rejection = state.lastRejection;
    if (!state.hasUnsent && rejection == null && !state.hasRefused) {
      return const SizedBox.shrink();
    }

    final margin = context.metrics.screenMargin;
    return Padding(
      padding: EdgeInsets.fromLTRB(margin, AppSpacing.x2, margin, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.hasUnsent)
            Semantics(
              liveRegion: true,
              child: InlineAlert(
                message: TransferStrings.queuedNotice(state.queued.length),
                tone: AppTone.warning,
                icon: Icons.schedule,
              ),
            ),
          if (rejection != null) ...[
            if (state.hasUnsent) const SizedBox(height: AppSpacing.x2),
            Semantics(
              liveRegion: true,
              child: InlineAlert(
                message: TransferStrings.queuedRejected(rejection),
              ),
            ),
          ],
          if (state.hasRefused) ...[
            if (state.hasUnsent || rejection != null)
              const SizedBox(height: AppSpacing.x2),
            Semantics(
              liveRegion: true,
              child: const InlineAlert(message: TransferStrings.queuedRefused),
            ),
          ],
          if (rejection != null || state.hasRefused) ...[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: context
                    .read<TransferOutboxCubit>()
                    .rejectionDismissed,
                child: const Text(TransferStrings.dismiss),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown where a customer without accounts is told they are on the way:
/// when opening them failed, it says so and offers to try again.
///
/// It reads [AccountProvisioningCubit] from the tree.
class ProvisioningNotice extends StatelessWidget {
  const ProvisioningNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AccountProvisioningCubit>().state;
    if (status != ProvisioningStatus.failed) return const SizedBox.shrink();

    final margin = context.metrics.screenMargin;
    return Padding(
      padding: EdgeInsets.fromLTRB(margin, AppSpacing.x2, margin, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const InlineAlert(message: TransferStrings.provisioningFailed),
          const SizedBox(height: AppSpacing.x2),
          AppButton(
            label: TransferStrings.retry,
            variant: AppButtonVariant.secondary,
            onPressed: context.read<AccountProvisioningCubit>().retryRequested,
          ),
        ],
      ),
    );
  }
}
