import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';
import 'package:feature_auth/src/presentation/widgets/auth_page.dart';
import 'package:flutter/material.dart';

/// First screen of a customer who is not signed in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onOpenAccount,
    required this.onSignIn,
    super.key,
  });

  final VoidCallback onOpenAccount;
  final VoidCallback onSignIn;

  static const List<(IconData, String)> _benefits = [
    (Icons.schedule, AuthStrings.welcomeFast),
    (Icons.person_outline, AuthStrings.welcomePersonal),
    (Icons.grid_view, AuthStrings.welcomeServices),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Scaffold(
      body: AuthPage(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Wordmark(name: AuthStrings.productName),
          ),
          const SizedBox(height: AppSpacing.x8),
          Semantics(
            header: true,
            child: Text(
              AuthStrings.welcomeTitle,
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            AuthStrings.welcomeBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          for (final (icon, text) in _benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x6),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(icon, size: AppSizes.icon, color: colors.link),
                  ),
                  const SizedBox(width: AppSpacing.componentGap),
                  Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.x2),
          AppButton(label: AuthStrings.openAccount, onPressed: onOpenAccount),
          const SizedBox(height: AppSpacing.x3),
          AppButton(
            label: AuthStrings.alreadyCustomer,
            variant: AppButtonVariant.secondary,
            onPressed: onSignIn,
          ),
        ],
      ),
    );
  }
}
