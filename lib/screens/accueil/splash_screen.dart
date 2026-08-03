import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/app_logo.dart';

/// Écran affiché pendant la résolution de la session, en prolongement direct de
/// l'écran de lancement natif.
///
/// Le fond (`scaffoldBackgroundColor`, cf. `AppTheme.backgroundColor`) et la
/// marque reprennent exactement ceux des ressources natives — `LaunchImage` côté
/// iOS, `splash_logo` côté Android — pour que la bascule du natif vers Flutter
/// passe inaperçue. Toute modification de la taille ou du fond doit donc être
/// répercutée des deux côtés.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Largeur de la marque, identique aux écrans de lancement natifs.
  static const double _markWidth = 180;

  /// `icone_procolis.png` est une toile carrée de 512 px où la marque, centrée,
  /// n'occupe que 420 px : on agrandit l'image d'autant pour que la marque
  /// mesure bien [_markWidth] à l'écran.
  static const double _logoSize = _markWidth * 512 / 420;

  /// L'indicateur n'apparaît qu'au-delà de ce délai : quand la session se
  /// résout immédiatement, l'utilisateur ne voit aucun rebond.
  static const Duration _indicatorDelay = Duration(milliseconds: 400);

  Timer? _timer;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_indicatorDelay, () {
      if (mounted) setState(() => _showIndicator = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Le logo reste strictement centré, à la même place que sur l'écran
          // natif : l'indicateur est posé par-dessus et ne le décale pas.
          const Center(child: AppLogo(size: _logoSize)),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: AnimatedOpacity(
                opacity: _showIndicator ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
