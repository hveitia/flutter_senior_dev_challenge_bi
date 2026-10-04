import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/movement.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:feature_accounts/src/presentation/formatting/time_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the details of [movement] over the current screen.
Future<void> showMovementDetail(
  BuildContext context, {
  required Movement movement,
  required Account account,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        MovementDetailSheet(movement: movement, account: account),
  );
}

/// Everything the app knows about one movement.
///
/// The only action is copying the reference. Sharing a receipt and
/// reporting a problem need a backend that does not exist yet, and a button
/// that does nothing is worse than no button.
class MovementDetailSheet extends StatefulWidget {
  const MovementDetailSheet({
    required this.movement,
    required this.account,
    super.key,
  });

  final Movement movement;
  final Account account;

  @override
  State<MovementDetailSheet> createState() => _MovementDetailSheetState();
}

class _MovementDetailSheetState extends State<MovementDetailSheet> {
  bool _referenceCopied = false;

  Future<void> _copyReference() async {
    await Clipboard.setData(ClipboardData(text: widget.movement.reference));
    // The confirmation lives in the sheet: a snackbar would be drawn on the
    // screen underneath, behind it.
    if (mounted) setState(() => _referenceCopied = true);
  }

  @override
  Widget build(BuildContext context) {
    final movement = widget.movement;
    final account = widget.account;
    final scheme = Theme.of(context).colorScheme;
    final margin = context.metrics.screenMargin;
    final isCompleted = movement.status == MovementStatus.completed;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(margin, 0, margin, margin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      AccountsStrings.movementDetailTitle,
                      style: AppTypography.title.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AccountsStrings.close,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(
              movement.description,
              style: AppTypography.body.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            AmountText(
              cents: movement.amountCents,
              size: AmountTextSize.display,
              signDisplay: AmountSignDisplay.always,
            ),
            const SizedBox(height: AppSpacing.x3),
            StatusChip(
              label: AccountsStrings.status(movement.status),
              tone: isCompleted ? AppTone.success : AppTone.warning,
            ),
            const SizedBox(height: AppSpacing.x4),
            for (final (label, value) in [
              (
                AccountsStrings.dateAndTime,
                TimeLabels.fullMoment(movement.postedAt),
              ),
              (
                AccountsStrings.account,
                '${account.name} ${account.maskedNumber}',
              ),
              (AccountsStrings.reference, movement.reference),
              (
                AccountsStrings.category,
                AccountsStrings.categoryName(movement.category),
              ),
              (
                AccountsStrings.channel,
                AccountsStrings.channelName(movement.channel),
              ),
            ]) ...[
              DetailRow(label: label, value: value),
              const Divider(),
            ],
            const SizedBox(height: AppSpacing.x4),
            if (_referenceCopied) ...[
              const InlineAlert(
                message: AccountsStrings.referenceCopied,
                tone: AppTone.success,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: AppSpacing.x3),
            ],
            AppButton(
              label: AccountsStrings.copyReference,
              icon: Icons.copy_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: _copyReference,
            ),
          ],
        ),
      ),
    );
  }
}
