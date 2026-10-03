import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.1 contrast ratio between two opaque colors, from 1 to 21.
///
/// Not part of the public API: the test suite uses it to keep every text and
/// background pairing the design system allows at or above AA.
double contrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}
