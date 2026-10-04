import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/published_faults.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Provides what belongs to the signed-in customer to every screen that
/// needs a session: their accounts, and the published configuration read
/// for their segment.
///
/// Everything here is created when a customer signs in and disposed when
/// they sign out, and it is keyed by the customer, so a second customer on
/// the same device starts from nothing.
class CustomerScope extends StatelessWidget {
  const CustomerScope({
    required this.accountsRepositoryFor,
    required this.configRepository,
    required this.publishedFaults,
    required this.child,
    super.key,
  });

  final AccountsRepository Function(String uid) accountsRepositoryFor;
  final ConfigRepository configRepository;
  final PublishedFaults publishedFaults;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionBloc>().state;
    // The router is about to redirect. Building the screens meanwhile would
    // make them read providers that no longer exist.
    if (session is! SessionSignedIn) return const SizedBox.shrink();

    final uid = session.profile.uid;
    final segmentId = session.profile.segment.id;

    return RepositoryProvider<AccountsRepository>(
      key: ValueKey(uid),
      create: (context) => accountsRepositoryFor(uid),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AccountsBloc>(
            create: (context) => AccountsBloc(
              repository: context.read<AccountsRepository>(),
              telemetry: context.read<Telemetry>(),
            )..add(const AccountsStarted()),
            // Started with the session rather than with the first screen
            // that shows accounts, so they are ready when the customer gets
            // there.
            lazy: false,
          ),
          BlocProvider<AmountVisibilityCubit>(
            create: (context) => AmountVisibilityCubit(),
          ),
          BlocProvider<RemoteConfigCubit>(
            // Listened to from sign-in on: the published document can only
            // be read with a session.
            create: (context) =>
                RemoteConfigCubit(configRepository, segmentId: segmentId)
                  ..start(),
            lazy: false,
          ),
        ],
        child: _ConfigFollower(
          segmentId: segmentId,
          publishedFaults: publishedFaults,
          child: child,
        ),
      ),
    );
  }
}

/// Keeps what depends on the configuration in step with it for as long as
/// the customer is signed in: the segment the home is composed for and the
/// faults the resilience policy applies.
class _ConfigFollower extends StatefulWidget {
  const _ConfigFollower({
    required this.segmentId,
    required this.publishedFaults,
    required this.child,
  });

  final String segmentId;
  final PublishedFaults publishedFaults;
  final Widget child;

  @override
  State<_ConfigFollower> createState() => _ConfigFollowerState();
}

class _ConfigFollowerState extends State<_ConfigFollower> {
  late final Future<void> Function() _stopFollowing;

  @override
  void initState() {
    super.initState();
    _stopFollowing = widget.publishedFaults.follow(
      context.read<RemoteConfigCubit>(),
    );
  }

  @override
  void didUpdateWidget(_ConfigFollower oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The same customer with a different segment gets a different home
    // without signing in again.
    if (widget.segmentId != oldWidget.segmentId) {
      context.read<RemoteConfigCubit>().selectSegment(widget.segmentId);
    }
  }

  @override
  void dispose() {
    // A fault published for a session must not outlive it. Stopping only
    // undoes this follower: the next customer's may already be in place.
    unawaited(_stopFollowing());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
