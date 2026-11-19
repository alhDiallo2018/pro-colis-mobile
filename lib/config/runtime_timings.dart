// mobile/lib/config/runtime_timings.dart
//
// Snapshot runtime des timings administrables (`PublicConfig.timings`).
// Les services hors-Widget (Dio, GPS, workers de background) consomment ces
// variables ; dès que `PublicConfig` est chargé, un listener dans
// `main.dart` / `AppBootstrap` appelle `RuntimeTimings.apply(...)` pour
// réaligner les valeurs.
//
// Fallback = valeurs par défaut historiques (30 s pour les timeouts HTTP,
// 15 s pour le GPS, etc.). Les tests unitaires qui n'instancient pas de
// `PublicConfigProvider` continuent de voir ces valeurs stables.

import '../models/public_config.dart';
import '../providers/broadcast_provider.dart' as broadcast;
import '../providers/message_provider.dart' as message;
import '../services/background_location.dart' as bg_location;
import '../services/location_service.dart' as location;

/// Timeout HTTP effectif (connect + receive) utilisé par `Dio` lorsque le
/// service lit cette valeur au moment d'une création d'instance.
Duration kApiRequestTimeout = const Duration(milliseconds: 30000);

/// Timeout GPS effectif (fonctions `Geolocator.getCurrentPosition` et dérivés).
Duration kGeolocationTimeout = const Duration(milliseconds: 15000);

/// Intervalle de polling discovery driver (ex. provider carte chauffeurs).
Duration kDriverDiscoveryPoll = const Duration(milliseconds: 60000);

/// Durée maximale pendant laquelle on accepte une position chauffeur comme
/// « fraîche » sur la carte (côté serveur : `timings.positionTtlMs`).
Duration kDriverPositionTtl = const Duration(milliseconds: 600000);

/// API unique pour pousser le snapshot timings reçu de `/public/config` dans
/// toutes les constantes runtime. Laisse tout service continuer d'importer
/// une simple constante au lieu d'une Future.
class RuntimeTimings {
  const RuntimeTimings._();

  /// Applique la configuration — à appeler depuis un listener du provider.
  /// Chaque champ est validé (> 0) pour éviter qu'une valeur corrompue en DB
  /// paralyse le client.
  static void apply(TimingsConfig t) {
    if (t.apiRequestTimeoutMs > 0) {
      kApiRequestTimeout = Duration(milliseconds: t.apiRequestTimeoutMs);
    }
    if (t.geolocationTimeoutMs > 0) {
      kGeolocationTimeout = Duration(milliseconds: t.geolocationTimeoutMs);
    }
    if (t.driverDiscoveryPollMs > 0) {
      kDriverDiscoveryPoll = Duration(milliseconds: t.driverDiscoveryPollMs);
    }
    if (t.positionTtlMs > 0) {
      kDriverPositionTtl = Duration(milliseconds: t.positionTtlMs);
    }
    // Les modules possèdent déjà leur propre helper pour piloter leurs
    // constantes historiques ; on les relaie pour centraliser le point d'entrée.
    location.configureLocationTimings(
      uploadIntervalSec: t.locationUploadIntervalSec,
      freshnessSec: t.locationFreshnessSec,
    );
    // Garde `kLocationFreshness` aligné même si `background_location.dart`
    // est importé seul (ex. tests Geolocator).
    if (t.locationFreshnessSec > 0) {
      bg_location.kLocationFreshness =
          Duration(seconds: t.locationFreshnessSec);
    }
    message.configureMessagingTimings(editWindowMs: t.messageEditWindowMs);
    broadcast.configureBroadcastTimings(snoozeHours: t.broadcastSnoozeHours);
  }
}
