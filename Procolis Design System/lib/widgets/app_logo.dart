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
    // Utiliser le bon chemin : assets/images/ (pas assets/assets/images/)
    final imagePath = isWhite 
        ? 'assets/images/icone_procolis_foreground.png' 
        : 'assets/images/procolis-logo.png';
    
    return Image.asset(
      imagePath,
      height: size,
      width: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        print('❌ Erreur chargement logo: $imagePath');
        print('   Erreur: $error');
        
        // Fallback si l'image n'existe pas
        return Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: isWhite ? Colors.white : AppTheme.primaryBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              'PC',
              style: TextStyle(
                color: isWhite ? AppTheme.primaryBlue : Colors.white,
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