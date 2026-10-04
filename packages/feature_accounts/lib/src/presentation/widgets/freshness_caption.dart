import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_accounts/src/presentation/formatting/time_labels.dart';
import 'package:flutter/material.dart';

/// How old the data next to it is. Shown only for data that did not just
/// come from the backend.
///
/// It writes itself again every minute: saved data keeps getting older
/// while nothing else on the screen changes, and a caption frozen at "hace
/// un momento" would say the opposite.
class FreshnessCaption extends StatefulWidget {
  const FreshnessCaption({
    required this.syncedAt,
    required this.now,
    super.key,
  });

  /// How often the caption is written again.
  static const Duration tick = Duration(minutes: 1);

  /// When the data was last confirmed by the backend, if known.
  final DateTime? syncedAt;

  /// The current moment.
  final DateTime Function() now;

  @override
  State<FreshnessCaption> createState() => _FreshnessCaptionState();
}

class _FreshnessCaptionState extends State<FreshnessCaption> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    // Nothing to store: rebuilding reads the clock again.
    _ticker = Timer.periodic(FreshnessCaption.tick, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      TimeLabels.freshness(widget.syncedAt, now: widget.now()),
      style: AppTypography.caption.copyWith(
        color: context.colors.textSecondary,
      ),
    );
  }
}
