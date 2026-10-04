import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:flutter/material.dart';

/// Where each of [values] falls inside [size]: spread evenly from the left
/// edge to the right, the highest at the top and the lowest at the bottom.
/// Values that are all the same run through the middle. Empty with fewer
/// than two values, which do not make a line.
List<Offset> trendLinePoints(List<int> values, Size size) {
  if (values.length < 2) return const [];

  var lowest = values.first;
  var highest = values.first;
  for (final value in values) {
    if (value < lowest) lowest = value;
    if (value > highest) highest = value;
  }
  final range = highest - lowest;
  final step = size.width / (values.length - 1);

  return [
    for (final (index, value) in values.indexed)
      Offset(
        index * step,
        range == 0
            ? size.height / 2
            : size.height - (value - lowest) / range * size.height,
      ),
  ];
}

/// How a figure moved over time, as a line with no axes: the shape is the
/// message, the amounts are said by whatever sits next to it.
///
/// A screen reader cannot read a shape, so [semanticLabel] says in words
/// what the line shows.
class TrendLine extends StatelessWidget {
  const TrendLine({
    required this.values,
    required this.semanticLabel,
    super.key,
  });

  /// Oldest first.
  final List<int> values;
  final String semanticLabel;

  static const double height = AppSizes.touchTarget;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();

    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _TrendLinePainter(
            values: values,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  const _TrendLinePainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke, so the line is not clipped at the extremes.
    const inset = AppSizes.progressStroke / 2;
    final points = trendLinePoints(
      values,
      Size(size.width - inset * 2, size.height - inset * 2),
    );
    if (points.isEmpty) return;

    final path = Path()
      ..moveTo(points.first.dx + inset, points.first.dy + inset);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx + inset, point.dy + inset);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSizes.progressStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TrendLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}
