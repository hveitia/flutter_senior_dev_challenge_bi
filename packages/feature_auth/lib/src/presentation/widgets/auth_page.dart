import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Scrollable body shared by the access screens: page margins, safe areas
/// and room for the keyboard.
class AuthPage extends StatelessWidget {
  const AuthPage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final margin = context.metrics.screenMargin;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(margin, AppSpacing.x6, margin, margin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Title and supporting line that open a screen or a step.
class AuthHeading extends StatelessWidget {
  const AuthHeading({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.x6),
      ],
    );
  }
}
