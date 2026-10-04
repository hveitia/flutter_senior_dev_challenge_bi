import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/presentation/accounts_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tells the customer about the connection, under the header of a screen.
///
/// It reads the app's `ConnectivityCubit` from the tree and shows nothing
/// while the connection is fine.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({required this.hasSavedData, super.key});

  /// Whether the screen is showing something. Without it, the banner must
  /// not claim that saved data is on screen.
  final bool hasSavedData;

  @override
  Widget build(BuildContext context) {
    final status = context.watch<ConnectivityCubit>().state;

    return switch (status) {
      ConnectivityStatus.online => const SizedBox.shrink(),
      ConnectivityStatus.offline => StatusBanner(
        kind: StatusBannerKind.offline,
        message: hasSavedData ? null : AccountsStrings.offlineWithoutData,
      ),
      ConnectivityStatus.slow => const StatusBanner(
        kind: StatusBannerKind.slow,
      ),
      ConnectivityStatus.restored => const StatusBanner(
        kind: StatusBannerKind.restored,
      ),
    };
  }
}
