import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
    final Color effectiveBackground = backgroundColor ?? AppTheme.primary;
    final Color effectiveText = textColor ?? Colors.white;

    final buttonStyle = outlined
        ? OutlinedButton.styleFrom(
            side: BorderSide(color: effectiveBackground),
            foregroundColor: effectiveBackground,
            elevation: 0,
            textStyle: Theme.of(context).textTheme.labelLarge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: effectiveBackground,
            foregroundColor: effectiveText,
            elevation: 0,
            shadowColor: effectiveBackground.withOpacity( 0.24),
            disabledBackgroundColor: AppTheme.slate200,
            disabledForegroundColor: AppTheme.slate400,
            textStyle: Theme.of(context).textTheme.labelLarge,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          );

    // Le loader garde la taille du bouton stable pendant les appels réseau.
    final Widget buttonChild;
    if (isLoading) {
      buttonChild = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            outlined ? effectiveBackground : Colors.white,
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    } else {
      buttonChild = Text(
        text,
        style: TextStyle(
          fontSize: fontSize ?? 16,
          fontWeight: FontWeight.w800,
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
