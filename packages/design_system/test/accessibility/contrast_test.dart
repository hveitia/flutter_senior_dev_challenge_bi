import 'package:design_system/design_system.dart';
import 'package:design_system/src/accessibility/contrast.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 minimums: 4.5:1 for text (1.4.3) and 3:1 for non-text UI such as
/// focus indicators, icons and control borders (1.4.11).
const double _text = 4.5;
const double _nonText = 3;

typedef _Pair = ({String name, Color foreground, Color background});

void main() {
  group('contrastRatio', () {
    test('is 21 for black on white and symmetric', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);

      expect(contrastRatio(black, white), closeTo(21, 0.01));
      expect(contrastRatio(white, black), closeTo(21, 0.01));
    });

    test('is 1 for identical colors', () {
      expect(contrastRatio(AppColors.ink900, AppColors.ink900), 1);
    });
  });

  group('text pairings the system allows reach AA', () {
    const surfaces = {
      'surface/0': AppColors.surface0,
      'surface/1': AppColors.surface1,
      'surface/2': AppColors.surface2,
    };

    final pairs = <_Pair>[
      for (final surface in surfaces.entries) ...[
        (
          name: 'primary on ${surface.key}',
          foreground: AppTextColors.primary,
          background: surface.value,
        ),
        (
          name: 'secondary on ${surface.key}',
          foreground: AppTextColors.secondary,
          background: surface.value,
        ),
      ],
      (
        name: 'primary on brand/50',
        foreground: AppTextColors.primary,
        background: AppColors.brand50,
      ),
      (
        name: 'secondary on brand/50',
        foreground: AppTextColors.secondary,
        background: AppColors.brand50,
      ),
      (
        name: 'onBrand on brand/500',
        foreground: AppTextColors.onBrand,
        background: AppColors.brand500,
      ),
      (
        name: 'onBrand on brand/600',
        foreground: AppTextColors.onBrand,
        background: AppColors.brand600,
      ),
      (
        name: 'link on surface/0',
        foreground: AppTextColors.link,
        background: AppColors.surface0,
      ),
      (
        name: 'link on surface/1',
        foreground: AppTextColors.link,
        background: AppColors.surface1,
      ),
      (
        name: 'link on brand/50',
        foreground: AppTextColors.link,
        background: AppColors.brand50,
      ),
      for (final tone in AppTone.values) ...[
        (
          name: '${tone.name} on its tint',
          foreground: AppSemanticColors.light.foreground(tone),
          background: AppSemanticColors.light.tint(tone),
        ),
        (
          name: '${tone.name} on surface/0',
          foreground: AppSemanticColors.light.foreground(tone),
          background: AppColors.surface0,
        ),
        (
          name: '${tone.name} on surface/1',
          foreground: AppSemanticColors.light.foreground(tone),
          background: AppColors.surface1,
        ),
      ],
    ];

    for (final pair in pairs) {
      test(pair.name, () {
        expect(
          contrastRatio(pair.foreground, pair.background),
          greaterThanOrEqualTo(_text),
        );
      });
    }
  });

  group('non-text indicators reach 3:1', () {
    final pairs = <_Pair>[
      for (final background in {
        'surface/0': AppColors.surface0,
        'surface/1': AppColors.surface1,
        'surface/2': AppColors.surface2,
        'brand/500': AppColors.brand500,
        'brand/50': AppColors.brand50,
      }.entries)
        (
          name: 'focus ring on ${background.key}',
          foreground: AppColors.focusRing,
          background: background.value,
        ),
      (
        name: 'icon ink/600 on surface/1',
        foreground: AppColors.ink600,
        background: AppColors.surface1,
      ),
      (
        name: 'error border on surface/0',
        foreground: AppColors.danger500,
        background: AppColors.surface0,
      ),
    ];

    for (final pair in pairs) {
      test(pair.name, () {
        expect(
          contrastRatio(pair.foreground, pair.background),
          greaterThanOrEqualTo(_nonText),
        );
      });
    }
  });

  group('brand orange is a fill, never a text color', () {
    test('brand/500 and brand/600 are not exposed as text colors', () {
      expect(AppTextColors.values, isNot(contains(AppColors.brand500)));
      expect(AppTextColors.values, isNot(contains(AppColors.brand600)));
    });

    test('the rule exists because brand/500 fails AA on every surface', () {
      for (final surface in [
        AppColors.surface0,
        AppColors.surface1,
        AppColors.surface2,
      ]) {
        expect(contrastRatio(AppColors.brand500, surface), lessThan(_nonText));
      }
    });

    test('white on brand/500 fails AA, so text on brand is ink/900', () {
      expect(
        contrastRatio(AppColors.surface0, AppColors.brand500),
        lessThan(_text),
      );
    });

    test('ink/600 fails AA on surface/1, so secondary text uses its own '
        'token', () {
      expect(
        contrastRatio(AppColors.ink600, AppColors.surface1),
        lessThan(_text),
      );
    });
  });
}
