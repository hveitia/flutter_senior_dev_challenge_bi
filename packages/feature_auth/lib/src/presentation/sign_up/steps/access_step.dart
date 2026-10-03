import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/domain/validators/password_policy.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_cubit.dart';
import 'package:feature_auth/src/presentation/widgets/auth_page.dart';
import 'package:feature_auth/src/presentation/widgets/failure_alert.dart';
import 'package:feature_auth/src/presentation/widgets/password_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Step "Protege tu acceso": the password and how to come back in.
class AccessStep extends StatefulWidget {
  const AccessStep({super.key});

  @override
  State<AccessStep> createState() => _AccessStepState();
}

class _AccessStepState extends State<AccessStep> {
  late final TextEditingController _password;
  late final TapGestureRecognizer _openTerms;
  late final TapGestureRecognizer _openPrivacy;

  @override
  void initState() {
    super.initState();
    _password = TextEditingController(
      text: context.read<SignUpCubit>().state.password,
    );
    _openTerms = TapGestureRecognizer()
      ..onTap = () => _showLegalNotice(AuthStrings.terms);
    _openPrivacy = TapGestureRecognizer()
      ..onTap = () => _showLegalNotice(AuthStrings.privacy);
  }

  @override
  void dispose() {
    _password.dispose();
    _openTerms.dispose();
    _openPrivacy.dispose();
    super.dispose();
  }

  void _showLegalNotice(String title) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => _LegalNotice(title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignUpCubit>();
    final state = context.watch<SignUpCubit>().state;
    final theme = Theme.of(context);
    final link = TextStyle(
      color: context.colors.link,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: context.colors.link,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthHeading(
          title: AuthStrings.accessTitle,
          body: AuthStrings.accessBody,
        ),
        FailureAlert(failure: state.failure),
        PasswordField(
          controller: _password,
          autofillHint: AutofillHints.newPassword,
          textInputAction: TextInputAction.done,
          onChanged: cubit.passwordChanged,
        ),
        const SizedBox(height: AppSpacing.componentGap),
        for (final requirement in PasswordRequirement.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x2),
            child: RequirementItem(
              label: AuthStrings.passwordRequirement(requirement),
              met: state.passwordRequirementsMet.contains(requirement),
            ),
          ),
        if (state.biometricsAvailable) ...[
          const SizedBox(height: AppSpacing.x2),
          ToggleRow(
            label: AuthStrings.biometricUnlock,
            value: state.biometricUnlock,
            onChanged: (enabled) =>
                cubit.biometricUnlockChanged(enabled: enabled),
          ),
        ],
        const SizedBox(height: AppSpacing.x2),
        CheckboxRow(
          value: state.termsAccepted,
          semanticLabel: AuthStrings.acceptTerms,
          onChanged: (accepted) =>
              cubit.termsAcceptedChanged(accepted: accepted),
          label: Text.rich(
            TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                const TextSpan(text: AuthStrings.termsLead),
                TextSpan(
                  text: AuthStrings.terms,
                  style: link,
                  recognizer: _openTerms,
                ),
                const TextSpan(text: AuthStrings.termsJoin),
                TextSpan(
                  text: AuthStrings.privacy,
                  style: link,
                  recognizer: _openPrivacy,
                ),
                const TextSpan(text: AuthStrings.termsEnd),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.componentGap),
        AppButton(
          label: AuthStrings.createAccount,
          isLoading: state.isSubmitting,
          onPressed: state.canCreateAccount ? cubit.next : null,
        ),
      ],
    );
  }
}

class _LegalNotice extends StatelessWidget {
  const _LegalNotice({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final margin = context.metrics.screenMargin;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(margin, 0, margin, margin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                '${title[0].toUpperCase()}${title.substring(1)}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(AuthStrings.legalNotice, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.componentGap),
            AppButton(
              label: AuthStrings.close,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
