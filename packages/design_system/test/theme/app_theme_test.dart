import 'package:design_system/design_system.dart';
import 'package:design_system/src/accessibility/contrast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final theme = AppTheme.light;

  group('AppTheme.light', () {
    test('is a light Material 3 theme on the app background', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppColors.surface1);
    });

    test('exposes semantic colors and metrics as theme extensions', () {
      expect(theme.extension<AppSemanticColors>(), AppSemanticColors.light);
      expect(theme.extension<AppMetrics>(), AppMetrics.standard);
    });

    test('maps the type scale onto the Material text theme', () {
      final text = theme.textTheme;

      expect(text.headlineMedium!.fontSize, AppTypography.display.fontSize);
      expect(text.titleLarge!.fontSize, AppTypography.title.fontSize);
      expect(text.titleMedium!.fontSize, AppTypography.subtitle.fontSize);
      expect(text.bodyMedium!.fontSize, AppTypography.body.fontSize);
      expect(text.bodySmall!.fontSize, AppTypography.caption.fontSize);
      expect(text.labelLarge!.fontWeight, FontWeight.w600);
      expect(text.labelSmall!.letterSpacing, 0.6);
      expect(text.titleLarge!.fontFamily, AppTypography.title.fontFamily);
      expect(text.bodyMedium!.fontFamily, AppTypography.body.fontFamily);
    });

    test('no text style or "on" color is the brand orange', () {
      final text = theme.textTheme;
      final scheme = theme.colorScheme;
      final colors = [
        for (final style in [
          text.displayLarge,
          text.displayMedium,
          text.displaySmall,
          text.headlineLarge,
          text.headlineMedium,
          text.headlineSmall,
          text.titleLarge,
          text.titleMedium,
          text.titleSmall,
          text.bodyLarge,
          text.bodyMedium,
          text.bodySmall,
          text.labelLarge,
          text.labelMedium,
          text.labelSmall,
        ])
          style!.color,
        scheme.primary,
        scheme.onPrimary,
        scheme.onPrimaryContainer,
        scheme.onSecondary,
        scheme.onSurface,
        scheme.onSurfaceVariant,
        scheme.onError,
      ];

      expect(colors, isNot(contains(AppColors.brand500)));
      expect(colors, isNot(contains(AppColors.brand600)));
    });

    test('scheme.primary is safe wherever Material paints it as text', () {
      final scheme = theme.colorScheme;

      expect(
        contrastRatio(scheme.primary, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(scheme.primaryContainer, AppColors.brand500);
      expect(
        contrastRatio(scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('button themes', () {
    T resolve<T>(
      WidgetStateProperty<T>? property, [
      Set<WidgetState>? states,
    ]) => property!.resolve(states ?? const {});

    test('primary is the brand fill with ink text', () {
      final style = theme.filledButtonTheme.style!;

      expect(resolve(style.backgroundColor), AppColors.brand500);
      expect(resolve(style.foregroundColor), AppColors.ink900);
      expect(
        resolve(style.minimumSize)!.height,
        AppSizes.buttonHeight,
      );
      expect(
        resolve(style.shape),
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.button)),
        ),
      );
    });

    test('secondary is a 1px ink outline', () {
      final style = theme.outlinedButtonTheme.style!;

      expect(
        resolve(style.side),
        const BorderSide(color: AppColors.ink900),
      );
      expect(resolve(style.foregroundColor), AppColors.ink900);
    });

    test('text buttons use the text-safe orange', () {
      final style = theme.textButtonTheme.style!;

      expect(resolve(style.foregroundColor), AppTextColors.link);
    });

    test('focus is a 2px ink ring on every button variant', () {
      const ring = BorderSide(
        color: AppColors.focusRing,
        width: AppSizes.focusWidth,
      );

      for (final style in [
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
      ]) {
        expect(resolve(style.side, {WidgetState.focused}), ring);
      }
    });

    test('disabled buttons stay legible', () {
      final style = theme.filledButtonTheme.style!;
      const disabled = {WidgetState.disabled};

      expect(
        contrastRatio(
          resolve(style.foregroundColor, disabled)!,
          resolve(style.backgroundColor, disabled)!,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('theme extensions', () {
    test('AppSemanticColors resolves the colors of each tone', () {
      const colors = AppSemanticColors.light;

      const expected = {
        AppTone.success: (AppColors.success500, AppColors.successTint),
        AppTone.danger: (AppColors.danger500, AppColors.dangerTint),
        AppTone.warning: (AppColors.warning500, AppColors.warningTint),
        AppTone.info: (AppColors.info500, AppColors.infoTint),
      };

      expect(expected.keys, AppTone.values);
      for (final MapEntry(key: tone, value: (foreground, tint))
          in expected.entries) {
        expect(colors.foreground(tone), foreground);
        expect(colors.tint(tone), tint);
      }
    });

    test('AppSemanticColors copies and interpolates', () {
      const colors = AppSemanticColors.light;
      final changed = colors.copyWith(line: AppColors.ink900);

      expect(changed.line, AppColors.ink900);
      expect(changed.brandFill, colors.brandFill);
      expect(colors.lerp(changed, 0), colors);
      expect(colors.lerp(changed, 1), changed);
      expect(colors.lerp(null, 0.5), colors);
    });

    test('AppMetrics copies and interpolates', () {
      const metrics = AppMetrics.standard;
      final changed = metrics.copyWith(screenMargin: 40);

      expect(changed.screenMargin, 40);
      expect(changed.cardRadius, metrics.cardRadius);
      expect(metrics.lerp(changed, 0.5).screenMargin, 30);
      expect(metrics.lerp(null, 0.5), metrics);
    });
  });

  testWidgets('context accessors read the extensions from the theme', (
    tester,
  ) async {
    late AppSemanticColors colors;
    late AppMetrics metrics;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            colors = context.colors;
            metrics = context.metrics;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(colors, AppSemanticColors.light);
    expect(metrics, AppMetrics.standard);
  });
}
