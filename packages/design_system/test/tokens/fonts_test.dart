import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

/// A font family that is used by the type scale but not declared in the
/// package silently falls back to the platform font. These checks make that
/// a test failure instead.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('every family in the type scale is declared by the package', () {
    for (final family in {
      AppTypography.headingFamily,
      AppTypography.textFamily,
    }) {
      expect(pubspec, contains('- family: $family'));
    }
  });

  test('every declared font file exists and ships with its license', () {
    final assets = RegExp(
      r'asset: (\S+)',
    ).allMatches(pubspec).map((match) => match[1]!).toList();

    expect(assets, hasLength(3));
    for (final asset in assets) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
    expect(File('assets/fonts/Poppins-OFL.txt').existsSync(), isTrue);
    expect(File('assets/fonts/OpenSans-OFL.txt').existsSync(), isTrue);
  });

  test('type styles resolve to the fonts bundled in this package', () {
    expect(AppTypography.display.fontFamily, 'packages/design_system/Poppins');
    expect(AppTypography.body.fontFamily, 'packages/design_system/Open Sans');
  });
}
