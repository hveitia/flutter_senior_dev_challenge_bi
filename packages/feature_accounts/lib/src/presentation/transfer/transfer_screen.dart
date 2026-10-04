import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/transfer.dart';
import 'package:feature_accounts/src/presentation/transfer/transfer_cubit.dart';
import 'package:feature_accounts/src/presentation/transfer/transfer_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A transfer between the customer's own accounts: the form, its
/// confirmation and, once sent, the result.
///
/// It reads [TransferCubit] from the tree. Leaving the result is the
/// caller's: [onSeeMovement] opens the account the money left from and
/// [onDone] goes back to the home.
class TransferScreen extends StatelessWidget {
  const TransferScreen({
    required this.onClose,
    required this.onSeeMovement,
    required this.onDone,
    super.key,
  });

  final VoidCallback onClose;
  final ValueChanged<String> onSeeMovement;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransferCubit>().state;
    final outcome = state.outcome;

    if (state.step == TransferStep.done && outcome != null) {
      return _TransferResult(
        outcome: outcome,
        isRetrying: false,
        onSeeMovement: () => onSeeMovement(state.fromAccountId ?? ''),
        onDone: onDone,
      );
    }
    if (state.step == TransferStep.sending && outcome is TransferNotSent) {
      // A retry in flight keeps the result on screen, with progress on it.
      return _TransferResult(
        outcome: outcome,
        isRetrying: true,
        onSeeMovement: () {},
        onDone: onDone,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(TransferStrings.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: TransferStrings.close,
          onPressed: onClose,
        ),
      ),
      body: SafeArea(
        child: state.step == TransferStep.editing
            ? const _TransferForm()
            : const _TransferConfirmation(),
      ),
    );
  }
}

class _TransferForm extends StatefulWidget {
  const _TransferForm();

  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  late final TextEditingController _amount;
  late final TextEditingController _concept;

  /// Digits a customer can type as an amount: up to $99,999.99.
  static const int _maxAmountDigits = 7;

  @override
  void initState() {
    super.initState();
    final state = context.read<TransferCubit>().state;
    // Coming back from the confirmation keeps what was typed.
    _amount = TextEditingController(
      text: state.amountCents == 0 ? '' : '${state.amountCents}',
    );
    _concept = TextEditingController(text: state.concept);
  }

  @override
  void dispose() {
    _amount.dispose();
    _concept.dispose();
    super.dispose();
  }

  Future<void> _pick(
    BuildContext context, {
    required String title,
    required List<Account> accounts,
    required ValueChanged<String> onPicked,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          _AccountPickerSheet(title: title, accounts: accounts),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<TransferCubit>();
    final state = cubit.state;
    final margin = context.metrics.screenMargin;
    final candidates = cubit.candidates;
    final from = cubit.from;
    final error = state.showsErrors ? cubit.error : null;

    if (candidates.length < 2) {
      return Padding(
        padding: EdgeInsets.all(margin),
        child: const InlineAlert(
          message: TransferStrings.noAccountsToTransfer,
          tone: AppTone.info,
          icon: Icons.info_outline,
        ),
      );
    }

    // Few fields, all built at once: a screen reader and a keyboard can
    // reach every one without scrolling first.
    return SingleChildScrollView(
      padding: EdgeInsets.all(margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _fields(context, cubit, candidates, from, error),
      ),
    );
  }

  List<Widget> _fields(
    BuildContext context,
    TransferCubit cubit,
    List<Account> candidates,
    Account? from,
    TransferFormError? error,
  ) {
    final state = cubit.state;
    return [
      _AccountField(
        label: TransferStrings.from,
        account: from,
        onTap: () => _pick(
          context,
          title: TransferStrings.from,
          accounts: candidates,
          onPicked: cubit.fromSelected,
        ),
      ),
      SizedBox(height: context.metrics.componentGap),
      _AccountField(
        label: TransferStrings.to,
        account: cubit.to,
        onTap: () => _pick(
          context,
          title: TransferStrings.to,
          // The account the money leaves from cannot also receive it.
          accounts: [
            for (final account in candidates)
              if (account.id != state.fromAccountId) account,
          ],
          onPicked: cubit.toSelected,
        ),
      ),
      SizedBox(height: context.metrics.moduleGap),
      Center(
        child: AmountText(
          cents: state.amountCents,
          size: AmountTextSize.display,
        ),
      ),
      SizedBox(height: context.metrics.componentGap),
      AppTextField(
        label: TransferStrings.amount,
        controller: _amount,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(_maxAmountDigits),
        ],
        helperText: from == null
            ? null
            : TransferStrings.available(from.availableCents),
        errorText: switch (error) {
          TransferFormError.missingAmount ||
          TransferFormError.overLimit ||
          TransferFormError.insufficientFunds => TransferStrings.errorText(
            error,
            availableCents: from?.availableCents,
          ),
          _ => null,
        },
        onChanged: cubit.amountChanged,
      ),
      SizedBox(height: context.metrics.componentGap),
      AppTextField(
        label: TransferStrings.concept,
        controller: _concept,
        inputFormatters: [
          LengthLimitingTextInputFormatter(TransferLimits.maxConceptLength),
        ],
        errorText: error == TransferFormError.conceptTooLong
            ? TransferStrings.errorText(error)
            : null,
        onChanged: cubit.conceptChanged,
      ),
      if (error == TransferFormError.missingAccounts ||
          error == TransferFormError.sameAccount) ...[
        SizedBox(height: context.metrics.componentGap),
        InlineAlert(message: TransferStrings.errorText(error)!),
      ],
      SizedBox(height: context.metrics.moduleGap),
      AppButton(
        label: TransferStrings.next,
        onPressed: cubit.continueRequested,
      ),
    ];
  }
}

/// A field that shows the chosen account and opens the list to change it.
class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.label,
    required this.account,
    required this.onTap,
  });

  final String label;
  final Account? account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final account = this.account;
    final value = account == null
        ? TransferStrings.chooseAccount
        : '${account.name} ${account.maskedNumber}';
    final radius = BorderRadius.circular(context.metrics.inputRadius);

    return Semantics(
      button: true,
      label: '$label: $value',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
            padding: const EdgeInsets.all(AppSpacing.x4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: radius,
              border: Border.all(color: context.colors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.caption.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                      Text(value, style: AppTypography.bodyStrong),
                      if (account != null)
                        Text(
                          TransferStrings.available(account.availableCents),
                          style: AppTypography.caption.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.expand_more),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountPickerSheet extends StatelessWidget {
  const _AccountPickerSheet({required this.title, required this.accounts});

  final String title;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.all(context.metrics.screenMargin),
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppTypography.subtitle),
          ),
          const SizedBox(height: AppSpacing.x2),
          for (final account in accounts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${account.name} ${account.maskedNumber}'),
              subtitle: Text(TransferStrings.available(account.availableCents)),
              onTap: () => Navigator.of(context).pop(account.id),
            ),
        ],
      ),
    );
  }
}

class _TransferConfirmation extends StatelessWidget {
  const _TransferConfirmation();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<TransferCubit>();
    final state = cubit.state;
    final from = cubit.from;
    final to = cubit.to;
    final isSending = state.step == TransferStep.sending;

    return ListView(
      padding: EdgeInsets.all(context.metrics.screenMargin),
      children: [
        Semantics(
          header: true,
          child: const Text(
            TransferStrings.confirmTitle,
            style: AppTypography.title,
          ),
        ),
        SizedBox(height: context.metrics.componentGap),
        Center(
          child: AmountText(
            cents: state.amountCents,
            size: AmountTextSize.display,
          ),
        ),
        SizedBox(height: context.metrics.componentGap),
        if (from != null)
          DetailRow(
            label: TransferStrings.from,
            value: '${from.name} ${from.maskedNumber}',
          ),
        if (to != null)
          DetailRow(
            label: TransferStrings.to,
            value: '${to.name} ${to.maskedNumber}',
          ),
        if (state.concept.trim().isNotEmpty)
          DetailRow(
            label: TransferStrings.conceptLabel,
            value: state.concept.trim(),
          ),
        SizedBox(height: context.metrics.moduleGap),
        AppButton(
          label: TransferStrings.confirm,
          isLoading: isSending,
          onPressed: isSending ? null : cubit.confirmed,
        ),
        SizedBox(height: context.metrics.componentGap),
        AppButton(
          label: TransferStrings.edit,
          variant: AppButtonVariant.secondary,
          onPressed: isSending ? null : cubit.editRequested,
        ),
      ],
    );
  }
}

/// How the transfer ended. There is no way back to the form from here: the
/// order was sent or queued, and only the actions below lead on.
class _TransferResult extends StatelessWidget {
  const _TransferResult({
    required this.outcome,
    required this.isRetrying,
    required this.onSeeMovement,
    required this.onDone,
  });

  final TransferOutcome outcome;
  final bool isRetrying;
  final VoidCallback onSeeMovement;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransferCubit>();
    final amount = AmountText(
      cents: cubit.state.amountCents,
      size: AmountTextSize.display,
    );
    final (icon, tone, title) = switch (outcome) {
      TransferCompleted() => (
        Icons.check_circle_outline,
        AppTone.success,
        TransferStrings.completedTitle,
      ),
      TransferQueued() => (
        Icons.schedule,
        AppTone.warning,
        TransferStrings.queuedTitle,
      ),
      TransferRejected() => (
        Icons.error_outline,
        AppTone.danger,
        TransferStrings.rejectedTitle,
      ),
      TransferNotSent() => (
        Icons.cloud_off_outlined,
        AppTone.warning,
        TransferStrings.notSentTitle,
      ),
    };

    return PopScope(
      // The system back gesture must not return to a form already sent.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDone();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(context.metrics.screenMargin),
            children: [
              SizedBox(height: context.metrics.moduleGap),
              Icon(
                icon,
                size: AppSizes.iconMedium * 2,
                color: context.colors.foreground(tone),
              ),
              SizedBox(height: context.metrics.componentGap),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  title,
                  style: AppTypography.title,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: context.metrics.componentGap),
              Center(child: amount),
              SizedBox(height: context.metrics.componentGap),
              ...switch (outcome) {
                TransferCompleted(:final reference) => [
                  DetailRow(label: TransferStrings.reference, value: reference),
                ],
                TransferQueued() => [
                  const Center(
                    child: StatusChip(
                      label: TransferStrings.queuedChip,
                      tone: AppTone.warning,
                      icon: Icons.schedule,
                    ),
                  ),
                  SizedBox(height: context.metrics.componentGap),
                  const Text(
                    TransferStrings.queuedMessage,
                    textAlign: TextAlign.center,
                  ),
                ],
                TransferRejected(:final reason) => [
                  Text(
                    TransferStrings.rejection(reason),
                    textAlign: TextAlign.center,
                  ),
                ],
                TransferNotSent() => [
                  const Text(
                    TransferStrings.notSentMessage,
                    textAlign: TextAlign.center,
                  ),
                ],
              },
              SizedBox(height: context.metrics.moduleGap),
              if (outcome is TransferCompleted) ...[
                AppButton(
                  label: TransferStrings.seeMovement,
                  onPressed: onSeeMovement,
                ),
                SizedBox(height: context.metrics.componentGap),
              ],
              if (outcome is TransferNotSent) ...[
                AppButton(
                  label: TransferStrings.retry,
                  isLoading: isRetrying,
                  onPressed: isRetrying ? null : cubit.retryRequested,
                ),
                SizedBox(height: context.metrics.componentGap),
              ],
              AppButton(
                label: TransferStrings.backHome,
                variant:
                    outcome is TransferCompleted || outcome is TransferNotSent
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                onPressed: onDone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
