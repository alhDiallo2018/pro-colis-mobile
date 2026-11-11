import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/generated/app_localizations.dart';

/// Préférence utilisateur pour la langue de l'app. Persistée dans
/// `SharedPreferences` sous la clé `app.locale`. Les 3 valeurs
/// acceptées : `fr`, `en`, `wo`.
///
/// Null → le mobile suit la langue du système (comportement par défaut).
class LocaleNotifier extends StateNotifier<Locale?> {
  static const _prefKey = 'app.locale';

  LocaleNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return;
      if (_isSupported(raw)) {
        state = Locale(raw);
      }
    } catch (_) {
      // Pas bloquant : tant pis pour la préférence.
    }
  }

  Future<void> set(Locale? locale) async {
    if (locale != null && !_isSupported(locale.languageCode)) return;
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_prefKey);
      } else {
        await prefs.setString(_prefKey, locale.languageCode);
      }
    } catch (_) {
      // Idem.
    }
  }

  static bool _isSupported(String code) {
    return AppLocalizations.supportedLocales.any((l) => l.languageCode == code);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});
