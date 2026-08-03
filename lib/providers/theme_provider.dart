import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clé de persistance du mode d'affichage choisi par l'utilisateur.
const String kThemeModePrefKey = 'pref_theme_mode';

/// Mode d'affichage de l'application (système / clair / sombre).
///
/// La valeur est restaurée depuis les préférences au démarrage : tant que la
/// lecture asynchrone n'est pas terminée, on reste sur `ThemeMode.system`, ce
/// qui évite un flash de thème au lancement pour la majorité des utilisateurs.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(kThemeModePrefKey);
      final restored = _decode(stored);
      if (restored != null) state = restored;
    } catch (_) {
      // Préférences illisibles : on garde le mode système.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kThemeModePrefKey, _encode(mode));
    } catch (_) {
      // Le choix reste actif pour la session même si l'écriture échoue.
    }
  }

  static ThemeMode? _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Libellé affiché dans les réglages.
String themeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Clair';
    case ThemeMode.dark:
      return 'Sombre';
    case ThemeMode.system:
      return 'Système';
  }
}
