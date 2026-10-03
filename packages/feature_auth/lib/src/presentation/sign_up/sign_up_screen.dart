import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_cubit.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_state.dart';
import 'package:feature_auth/src/presentation/sign_up/steps/access_step.dart';
import 'package:feature_auth/src/presentation/sign_up/steps/interests_step.dart';
import 'package:feature_auth/src/presentation/sign_up/steps/personal_data_step.dart';
import 'package:feature_auth/src/presentation/widgets/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The sign-up steps under one app bar. Expects a [SignUpCubit] above it.
///
/// Back goes to the previous step, keeping every answer. From the first
/// step it calls [onLeave]; when that is null there is nowhere to go back
/// to, which is the case of an account that must complete its profile.
class SignUpScreen extends StatelessWidget {
  const SignUpScreen({this.onLeave, this.onSignOut, super.key});

  final VoidCallback? onLeave;

  /// Offered instead of leaving when the customer is already signed in.
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignUpCubit>();
    final state = context.watch<SignUpCubit>().state;
    final isFirstStep = state.stepNumber == 1;
    final canGoBack = !isFirstStep || onLeave != null;

    void goBack() {
      if (!cubit.back()) onLeave?.call();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: canGoBack
              ? IconButton(
                  tooltip: AuthStrings.back,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: goBack,
                )
              : null,
          title: Text(
            state.mode == SignUpMode.newAccount
                ? AuthStrings.signUpTitle
                : AuthStrings.completeProfileTitle,
          ),
          actions: [
            if (onSignOut != null)
              AppButton(
                label: AuthStrings.signOut,
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: onSignOut,
              ),
          ],
        ),
        body: AuthPage(
          children: [
            StepIndicator(current: state.stepNumber, total: state.totalSteps),
            const SizedBox(height: AppSpacing.componentGap),
            // Keyed by step so each one keeps its own text controllers and
            // rebuilds them from the cubit when the customer comes back.
            KeyedSubtree(
              key: ValueKey(state.step),
              child: switch (state.step) {
                SignUpStep.personalData => const PersonalDataStep(),
                SignUpStep.interests => const InterestsStep(),
                SignUpStep.access => const AccessStep(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
