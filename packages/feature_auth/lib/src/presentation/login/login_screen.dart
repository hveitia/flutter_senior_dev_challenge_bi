import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';
import 'package:feature_auth/src/presentation/login/login_cubit.dart';
import 'package:feature_auth/src/presentation/widgets/auth_page.dart';
import 'package:feature_auth/src/presentation/widgets/failure_alert.dart';
import 'package:feature_auth/src/presentation/widgets/password_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sign-in with email and password. Expects a [LoginCubit] above it.
class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onOpenAccount, super.key});

  final VoidCallback onOpenAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    final state = context.watch<LoginCubit>().state;
    final theme = Theme.of(context);

    return Scaffold(
      body: AuthPage(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Wordmark(name: AuthStrings.productName),
          ),
          const SizedBox(height: AppSpacing.x8),
          const AuthHeading(
            title: AuthStrings.loginTitle,
            body: AuthStrings.loginBody,
          ),
          FailureAlert(failure: state.failure),
          if (state.reset == PasswordResetStatus.sent) ...[
            const InlineAlert(
              message: AuthStrings.passwordResetSent,
              tone: AppTone.success,
              icon: Icons.mark_email_read_outlined,
            ),
            const SizedBox(height: AppSpacing.componentGap),
          ],
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: AuthStrings.email,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  errorText: state.invalidFields.contains(LoginField.email)
                      ? AuthStrings.emailInvalid
                      : null,
                  onChanged: cubit.emailChanged,
                ),
                const SizedBox(height: AppSpacing.componentGap),
                PasswordField(
                  controller: _password,
                  autofillHint: AutofillHints.password,
                  textInputAction: TextInputAction.done,
                  errorText: state.invalidFields.contains(LoginField.password)
                      ? AuthStrings.passwordRequired
                      : null,
                  onChanged: cubit.passwordChanged,
                  onSubmitted: (_) => cubit.submit(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: AuthStrings.forgotPassword,
              variant: AppButtonVariant.text,
              expand: false,
              isLoading: state.reset == PasswordResetStatus.sending,
              onPressed: cubit.requestPasswordReset,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          AppButton(
            label: AuthStrings.signIn,
            isLoading: state.isSubmitting,
            onPressed: cubit.submit,
          ),
          const SizedBox(height: AppSpacing.x6),
          const Divider(),
          const SizedBox(height: AppSpacing.componentGap),
          Text(
            AuthStrings.noAccountYet,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: AuthStrings.openYourAccount,
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: widget.onOpenAccount,
            ),
          ),
        ],
      ),
    );
  }
}
