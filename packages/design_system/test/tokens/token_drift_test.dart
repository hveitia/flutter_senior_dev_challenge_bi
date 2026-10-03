import 'dart:convert';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against drift between the design reference (`tokens/tokens.json`)
/// and the hand-written Dart tokens. When a designer changes a value in the
/// JSON, the matching test fails until the Dart constant is updated.
void main() {
  final tokens =
      jsonDecode(File('tokens/tokens.json').readAsStringSync())
          as Map<String, dynamic>;

  Color hex(String key) {
    final value = (tokens[key] as String).substring(1);
    return Color(int.parse('FF$value', radix: 16));
  }

  Color rgba(String raw) {
    final match = RegExp(
      r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)',
    ).firstMatch(raw)!;
    return Color.fromRGBO(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      double.parse(match[4]!),
    );
  }

  double px(String key) =>
      double.parse((tokens[key] as String).replaceAll('px', ''));

  Duration ms(String key) => Duration(
    milliseconds: int.parse((tokens[key] as String).replaceAll('ms', '')),
  );

  Map<String, dynamic> type(String key) => tokens[key] as Map<String, dynamic>;

  final colors = <String, Color>{
    'brand/500': AppColors.brand500,
    'brand/600': AppColors.brand600,
    'brand/700': AppColors.brand700,
    'brand/50': AppColors.brand50,
    'ink/900': AppColors.ink900,
    'ink/600': AppColors.ink600,
    'ink/300': AppColors.ink300,
    'text/secondary-aa': AppColors.textSecondary,
    'border/line': AppColors.line,
    'surface/0': AppColors.surface0,
    'surface/1': AppColors.surface1,
    'surface/2': AppColors.surface2,
    'success/500': AppColors.success500,
    'success/tint': AppColors.successTint,
    'danger/500': AppColors.danger500,
    'danger/tint': AppColors.dangerTint,
    'warning/500': AppColors.warning500,
    'warning/tint': AppColors.warningTint,
    'info/500': AppColors.info500,
    'info/tint': AppColors.infoTint,
  };

  final lengths = <String, double>{
    'space/grid': AppSpacing.grid,
    'space/screenMargin': AppSpacing.screenMargin,
    'space/moduleGap': AppSpacing.moduleGap,
    'space/componentGap': AppSpacing.componentGap,
    'radius/card': AppRadii.card,
    'radius/input': AppRadii.input,
    'radius/button': AppRadii.button,
    'radius/chip': AppRadii.chip,
    'radius/sheet': AppRadii.sheet,
    'radius/partner': AppRadii.partner,
    'size/button-height': AppSizes.buttonHeight,
    'size/touch-target': AppSizes.touchTarget,
    'size/icon': AppSizes.icon,
    'size/icon-medium': AppSizes.iconMedium,
    'size/icon-small': AppSizes.iconSmall,
    'size/progress-stroke': AppSizes.progressStroke,
    'size/icon-stroke': AppSizes.iconStroke,
    'size/border': AppSizes.border,
    'size/bottom-navigation': AppSizes.bottomNavigation,
    'focus/width': AppSizes.focusWidth,
    'focus/offset': AppSizes.focusOffset,
  };

  final textStyles = <String, TextStyle>{
    'type/display': AppTypography.display,
    'type/title': AppTypography.title,
    'type/subtitle': AppTypography.subtitle,
    'type/body': AppTypography.body,
    'type/caption': AppTypography.caption,
    'type/overline': AppTypography.overline,
  };

  /// Tokens verified by a dedicated assertion below rather than by a table.
  const verifiedIndividually = {
    'type/amount',
    'focus/color',
    'color/scrim',
    'shadow/floating',
    'motion/transition-duration',
    'motion/transition-easing',
    'motion/shimmer-duration',
    'motion/shimmer-easing',
  };

  /// Tokens that intentionally have no Dart counterpart, with the reason.
  const outOfScope = {
    // Web admin console and design atlas chrome, not the mobile app.
    'radius/admin',
    'frame/mobile',
    'frame/admin',
    'surface/atlas',
    'border/atlas',
    'border/atlas-subtle',
    'border/atlas-divider',
    'border/atlas-control',
    // Aliases that only regroup tokens already covered above.
    'focus/ring',
    'motion/transition',
    'motion/shimmer',
    // Behavior notes, enforced by widget tests instead of constants.
    'motion/shimmer-iteration',
    'motion/reduced',
  };

  group('colors', () {
    for (final entry in colors.entries) {
      test(entry.key, () => expect(entry.value, hex(entry.key)));
    }

    test('focus/color points at ink/900', () {
      expect(tokens['focus/color'], '{ink/900}');
      expect(AppColors.focusRing, AppColors.ink900);
    });

    test('color/scrim', () {
      expect(AppColors.scrim, rgba(tokens['color/scrim'] as String));
    });
  });

  group('lengths', () {
    for (final entry in lengths.entries) {
      test(entry.key, () => expect(entry.value, px(entry.key)));
    }
  });

  group('typography', () {
    for (final entry in textStyles.entries) {
      test(entry.key, () {
        final spec = type(entry.key);
        final style = entry.value;
        final weights = spec['weight'] is List
            ? (spec['weight'] as List<dynamic>).cast<int>()
            : [spec['weight'] as int];

        expect(style.fontFamily, endsWith('/${spec['family']}'));
        expect(style.fontSize, spec['size']);
        expect(
          style.height! * style.fontSize!,
          closeTo(spec['height'] as num, 0.001),
        );
        expect(weights, contains(style.fontWeight!.value));
        // No tracking in the reference means none: an unset value would
        // inherit Material's default letter spacing instead.
        expect(style.letterSpacing, spec['tracking'] ?? 0);
      });
    }

    test('strong variants use the second declared weight', () {
      expect(AppTypography.bodyStrong.fontWeight, FontWeight.w600);
      expect(AppTypography.bodyStrong.fontSize, AppTypography.body.fontSize);
      expect(AppTypography.captionStrong.fontWeight, FontWeight.w600);
      expect(
        AppTypography.captionStrong.fontSize,
        AppTypography.caption.fontSize,
      );
    });

    test('type/amount', () {
      final spec = type('type/amount');
      expect(spec['tabular'], isTrue);
      expect(
        AppTypography.amountFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(AppTypography.amountCentsScale, spec['centsScale']);
    });
  });

  group('motion and elevation', () {
    test('motion/transition', () {
      expect(AppMotion.transitionDuration, ms('motion/transition-duration'));
      expect(tokens['motion/transition-easing'], 'ease-out');
      expect(AppMotion.transitionCurve, Curves.easeOut);
    });

    test('motion/shimmer', () {
      expect(AppMotion.shimmerDuration, ms('motion/shimmer-duration'));
      expect(tokens['motion/shimmer-easing'], 'linear');
      expect(AppMotion.shimmerCurve, Curves.linear);
    });

    test('shadow/floating', () {
      final match = RegExp(
        r'^(\d+) (\d+)px (\d+)px (rgba\(.+\))$',
      ).firstMatch(tokens['shadow/floating'] as String)!;
      final shadow = AppShadows.floating.single;

      expect(
        shadow.offset,
        Offset(double.parse(match[1]!), double.parse(match[2]!)),
      );
      expect(shadow.blurRadius, double.parse(match[3]!));
      expect(shadow.color, rgba(match[4]!));
    });
  });

  test('every token in the reference is mapped or explicitly out of scope', () {
    final covered = {
      ...colors.keys,
      ...lengths.keys,
      ...textStyles.keys,
      ...verifiedIndividually,
      ...outOfScope,
    };

    expect(tokens.keys.toSet().difference(covered), isEmpty);
    expect(covered.difference(tokens.keys.toSet()), isEmpty);
  });
}
