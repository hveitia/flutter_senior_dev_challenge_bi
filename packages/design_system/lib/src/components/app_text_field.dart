import 'package:design_system/src/theme/app_theme_context.dart';
import 'package:design_system/src/tokens/app_sizes.dart';
import 'package:design_system/src/tokens/app_spacing.dart';
import 'package:design_system/src/tokens/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Text input with its label above and helper or error below.
///
/// The label stays visible while typing (it is not a floating placeholder),
/// and an error is always an icon plus a message under the field.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? helperText;

  /// When set, replaces [helperText] and outlines the field as invalid.
  final String? errorText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Makes the field as tall as a button with one line of body text.
  static const double _verticalPadding = 15;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final hasError = errorText != null;
    final radius = BorderRadius.circular(context.metrics.inputRadius);

    OutlineInputBorder outline(Color color, [double width = AppSizes.border]) {
      return OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final resting = outline(hasError ? colors.danger : colors.line);
    final focused = outline(
      hasError ? colors.danger : colors.focusRing,
      AppSizes.focusWidth,
    );

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.captionStrong.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: AppTypography.body.copyWith(
            color: enabled ? scheme.onSurface : colors.textSecondary,
          ),
          cursorColor: scheme.onSurface,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.body.copyWith(
              color: colors.textSecondary,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? scheme.surface : colors.surfaceInset,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: _verticalPadding,
            ),
            border: resting,
            enabledBorder: resting,
            disabledBorder: outline(colors.line),
            focusedBorder: focused,
          ),
        ),
        if (!hasError && helperText != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            helperText!,
            style: AppTypography.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label and helper are merged into the field so assistive technology
        // announces them with it instead of as loose text around it.
        MergeSemantics(
          child: Semantics(
            validationResult: hasError
                ? SemanticsValidationResult.invalid
                : SemanticsValidationResult.none,
            child: field,
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.x2),
          // A live region of its own: the message is announced when it
          // appears. Inside the merged field it would make every keystroke
          // announce the whole field again.
          Semantics(
            container: true,
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: AppSizes.iconSmall,
                    color: colors.danger,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    errorText!,
                    style: AppTypography.caption.copyWith(
                      color: colors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
