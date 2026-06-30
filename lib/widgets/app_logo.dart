// lib/widgets/app_logo.dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool isWhite;

  const AppLogo({
    super.key,
    this.size = 40,
    this.isWhite = false,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = isWhite
        ? 'assets/images/icone_procolis_foreground.png'
        : 'assets/images/icone_procolis.png';

    return Image.asset(
      imagePath,
      height: size,
      width: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            gradient: isWhite ? null : AppTheme.brandGradient,
            color: isWhite ? Colors.white : null,
            borderRadius: BorderRadius.circular(size * 0.22),
          ),
          child: Center(
            child: Text(
              'PC',
              style: TextStyle(
                color: isWhite ? AppTheme.primary : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.4,
              ),
            ),
          ),
        );
      },
    );
  }
}
