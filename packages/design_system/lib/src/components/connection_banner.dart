import 'package:design_system/src/components/status_banner.dart';
import 'package:flutter/widgets.dart';

/// Tells the customer about the connection, under the header of a screen.
///
/// The screen says what the connection is like; this widget only decides
/// the wording, which depends on whether the screen has something to show.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    required this.kind,
    required this.hasSavedData,
    super.key,
  });

  /// What to tell the customer, or null while the connection is fine.
  final StatusBannerKind? kind;

  /// Whether the screen is showing something. Without it, the banner must
  /// not claim that saved data is on screen.
  final bool hasSavedData;

  /// Said without a connection when there is nothing saved to show.
  static const String offlineWithoutData = 'Sin conexión';

  @override
  Widget build(BuildContext context) {
    final kind = this.kind;
    if (kind == null) return const SizedBox.shrink();

    return StatusBanner(
      kind: kind,
      message: kind == StatusBannerKind.offline && !hasSavedData
          ? offlineWithoutData
          : null,
    );
  }
}
