import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The connection banner of the home, fed by the app's
/// `ConnectivityCubit`. It shows nothing while the connection is fine.
class ConnectionNotice extends StatelessWidget {
  const ConnectionNotice({required this.hasSavedData, super.key});

  /// Whether the screen is showing something.
  final bool hasSavedData;

  @override
  Widget build(BuildContext context) {
    return ConnectionBanner(
      kind: switch (context.watch<ConnectivityCubit>().state) {
        ConnectivityStatus.online => null,
        ConnectivityStatus.offline => StatusBannerKind.offline,
        ConnectivityStatus.slow => StatusBannerKind.slow,
        ConnectivityStatus.restored => StatusBannerKind.restored,
      },
      hasSavedData: hasSavedData,
    );
  }
}
