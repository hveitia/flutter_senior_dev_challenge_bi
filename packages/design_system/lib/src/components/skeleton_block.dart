import 'dart:async';

import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_motion.dart';
import 'package:flutter/material.dart';

/// Placeholder with the geometry of the content that is loading.
///
/// A flat band sweeps across it; the block itself never changes size, so
/// the layout does not move when the real content arrives. With reduced
/// motion the block is static.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    required this.height,
    this.width,
    this.borderRadius,
    super.key,
  });

  final double height;

  /// Null takes the available width.
  final double? width;

  /// Defaults to the card radius.
  final BorderRadius? borderRadius;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  /// The band starts and ends fully outside the block.
  static const double _travel = 1.1;
  static const double _bandOpacity = 0.55;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmerDuration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.shimmerCurve,
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius:
              widget.borderRadius ??
              BorderRadius.circular(context.metrics.cardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: context.colors.surfaceInset),
              if (!_reduceMotion)
                AnimatedBuilder(
                  animation: _progress,
                  builder: (context, band) => FractionalTranslation(
                    translation: Offset(
                      -_travel + 2 * _travel * _progress.value,
                      0,
                    ),
                    child: band,
                  ),
                  child: ColoredBox(
                    key: const ValueKey('skeleton-band'),
                    color: scheme.surface.withValues(alpha: _bandOpacity),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
