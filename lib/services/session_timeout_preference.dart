// Preference utilisateur : combien de temps l'application peut rester en
// arriere-plan avant de forcer une nouvelle authentification (ou un
// deverrouillage biometrique). Remplace le reglage statique `AppConfig
// .sessionLockTimeout` cote utilisateur. Les valeurs sont stables entre les
// versions : une migration suffirait a en ajouter, pas a les renommer.

import 'package:shared_preferences/shared_preferences.dart';

enum SessionTimeoutOption {
  immediate('immediate', 'Immediate', 'Des la sortie de l\'application',
      Duration.zero),
  oneMinute('1min', '1 minute', 'Apres 1 minute inactif', Duration(minutes: 1)),
  fiveMinutes(
      '5min', '5 minutes', 'Apres 5 minutes inactifs', Duration(minutes: 5)),
  thirtyMinutes('30min', '30 minutes', 'Apres 30 minutes inactifs',
      Duration(minutes: 30)),
  oneHour('1h', '1 heure', 'Apres 1 heure inactif', Duration(hours: 1)),
  threeHours(
      '3h', '3 heures', 'Apres 3 heures inactifs', Duration(hours: 3));

  const SessionTimeoutOption(this.key, this.label, this.description, this.duration);

  final String key;
  final String label;
  final String description;
  final Duration duration;

  static const SessionTimeoutOption defaultOption =
      SessionTimeoutOption.thirtyMinutes;

  static SessionTimeoutOption fromKey(String? key) {
    for (final option in SessionTimeoutOption.values) {
      if (option.key == key) return option;
    }
    return defaultOption;
  }
}

/// Lecteur/ecrivain des preferences, utilise par le provider Riverpod et la
/// page Parametres. Garde l'API fine : pas de notifier ici, le provider
/// s'occupe de la diffusion aux consommateurs.
abstract final class SessionTimeoutStore {
  static const String prefKey = 'pref_session_timeout';

  static Future<SessionTimeoutOption> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return SessionTimeoutOption.fromKey(prefs.getString(prefKey));
    } catch (_) {
      return SessionTimeoutOption.defaultOption;
    }
  }

  static Future<void> write(SessionTimeoutOption value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, value.key);
  }
}
