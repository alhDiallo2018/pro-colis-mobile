// lib/widgets/custom_button.dart (version alternative avec plus d'options)

import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final double? fontSize;
  final IconData? icon;
  final bool outlined;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.fontSize,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = outlined
        ? OutlinedButton.styleFrom(
            side: BorderSide(color: backgroundColor ?? const Color(0xFF0B6E3A)),
            foregroundColor: backgroundColor ?? const Color(0xFF0B6E3A),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? const Color(0xFF0B6E3A),
            foregroundColor: textColor ?? Colors.white,
            elevation: 0,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );

    final Widget buttonChild;
    if (isLoading) {
      buttonChild = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            outlined ? (backgroundColor ?? const Color(0xFF0B6E3A)) : Colors.white,
          ),
        ),
      );
    } else if (icon != null) {
      buttonChild = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize ?? 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else {
      buttonChild = Text(
        text,
        style: TextStyle(
          fontSize: fontSize ?? 16,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 50,
      child: outlined
          ? OutlinedButton(
              onPressed: (isLoading || onPressed == null) ? null : onPressed,
              style: buttonStyle,
              child: buttonChild,
            )
          : ElevatedButton(
              onPressed: (isLoading || onPressed == null) ? null : onPressed,
              style: buttonStyle,
              child: buttonChild,
            ),
    );
  }
}