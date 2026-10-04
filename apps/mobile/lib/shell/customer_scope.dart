import 'package:app_platform/app_platform.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Provides what belongs to the signed-in customer to every screen that
/// needs a session: their accounts repository and the Bloc that follows
/// their accounts.
///
/// Both are created when a customer signs in and disposed when they sign
/// out, and they are keyed by the customer, so a second customer on the
/// same device starts from nothing.
class CustomerScope extends StatelessWidget {
  const CustomerScope({
    required this.accountsRepositoryFor,
    required this.child,
    super.key,
  });

  final AccountsRepository Function(String uid) accountsRepositoryFor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionBloc>().state;
    // The router is about to redirect. Building the screens meanwhile would
    // make them read providers that no longer exist.
    if (session is! SessionSignedIn) return const SizedBox.shrink();

    final uid = session.profile.uid;

    return RepositoryProvider<AccountsRepository>(
      key: ValueKey(uid),
      create: (context) => accountsRepositoryFor(uid),
      child: BlocProvider<AccountsBloc>(
        create: (context) => AccountsBloc(
          repository: context.read<AccountsRepository>(),
          telemetry: context.read<Telemetry>(),
        )..add(const AccountsStarted()),
        // Started with the session rather than with the first screen that
        // shows accounts, so they are ready when the customer gets there.
        lazy: false,
        child: child,
      ),
    );
  }
}
