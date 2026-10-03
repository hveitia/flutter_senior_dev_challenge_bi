import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';
import 'package:feature_auth/src/presentation/session/session_bloc.dart';
import 'package:feature_auth/src/presentation/widgets/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shown over a restored session until the biometric check passes.
///
/// It asks for the check as soon as it opens. The customer can always fall
/// back to the password, which signs the session out.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unlock();
    });
  }

  void _unlock() =>
      context.read<SessionBloc>().add(const SessionUnlockRequested());

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionBloc>().state;
    if (state is! SessionLocked) return const Scaffold();

    return Scaffold(
      body: AuthPage(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Wordmark(name: AuthStrings.productName),
          ),
          const SizedBox(height: AppSpacing.x8),
          AuthHeading(
            title: AuthStrings.unlockGreeting(state.firstName),
            body: AuthStrings.unlockBody,
          ),
          if (state.lastAttemptFailed) ...[
            const InlineAlert(message: AuthStrings.unlockFailed),
            const SizedBox(height: AppSpacing.componentGap),
          ],
          AppButton(
            label: AuthStrings.biometricUnlock,
            icon: Icons.fingerprint,
            onPressed: _unlock,
          ),
          const SizedBox(height: AppSpacing.x3),
          AppButton(
            label: AuthStrings.usePassword,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.read<SessionBloc>().add(
              const SessionSignOutRequested(),
            ),
          ),
        ],
      ),
    );
  }
}
