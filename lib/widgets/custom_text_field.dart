// lib/widgets/custom_text_field.dart

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;
  final bool readOnly;
  final int? maxLength;
  final void Function(String)? onChanged;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final bool autoFocus;
  final TextAlign textAlign;
  final TextStyle? style;
  final String? helperText;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixPressed,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.maxLength,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.autoFocus = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      maxLength: maxLength,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      autofocus: autoFocus,
      textAlign: textAlign,
      style:
          style ?? const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        labelStyle: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: AppTheme.textSecondary.withOpacity( 0.5),
          fontSize: 14,
        ),
        helperStyle: TextStyle(
          color: AppTheme.textSecondary.withOpacity( 0.7),
          fontSize: 12,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: AppTheme.primary)
            : null,
        suffixIcon: suffixIcon != null
            ? IconButton(
                icon: Icon(suffixIcon, size: 20, color: AppTheme.textSecondary),
                onPressed: onSuffixPressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            : null,
        filled: true,
        fillColor: readOnly ? AppTheme.slate100 : AppTheme.cardColor,
        counterText: maxLength != null ? null : '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}
