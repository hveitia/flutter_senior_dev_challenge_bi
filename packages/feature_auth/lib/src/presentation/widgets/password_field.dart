import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';
import 'package:flutter/material.dart';

/// Password input with a control to reveal what was typed.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.onChanged,
    required this.autofillHint,
    this.errorText,
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// `AutofillHints.password` to fill a saved one, `newPassword` to let the
  /// password manager offer to save it.
  final String autofillHint;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: AuthStrings.password,
      controller: widget.controller,
      obscureText: _obscured,
      errorText: widget.errorText,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: [widget.autofillHint],
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      suffixIcon: IconButton(
        tooltip: _obscured
            ? AuthStrings.showPassword
            : AuthStrings.hidePassword,
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
    );
  }
}
