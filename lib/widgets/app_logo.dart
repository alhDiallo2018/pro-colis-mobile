// lib/widgets/app_logo.dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/fonts.dart';

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

/// Logo et nom de marque interactifs utilisés sur les écrans publics.
///
/// La zone tactile englobe aussi le nom afin de rester confortable sur mobile,
/// tandis que [Semantics] annonce clairement la destination aux lecteurs d’écran.
class AppBrandLink extends StatelessWidget {
  final VoidCallback onTap;
  final double logoSize;
  final double fontSize;
  final bool isWhite;

  const AppBrandLink({
    super.key,
    required this.onTap,
    this.logoSize = 30,
    this.fontSize = 21,
    this.isWhite = true,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isWhite ? Colors.white : AppTheme.textPrimary;

    return Semantics(
      button: true,
      label: 'Retourner à l’onboarding Send ProColis',
      child: Tooltip(
        message: 'Retour à l’onboarding',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: isWhite
                          ? Colors.white.withValues(alpha: 0.16)
                          : AppTheme.slate100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AppLogo(size: logoSize, isWhite: isWhite),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Send ProColis',
                    style: AppFonts.plusJakartaSans(
                      color: foreground,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
