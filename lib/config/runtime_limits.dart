// mobile/lib/config/runtime_limits.dart
//
// Snapshot runtime des limites administrables (`PublicConfig.limits`).
// Les services hors-Widget (ApiService pagination zones, parseurs CSV)
// consomment ces variables ; dès que `PublicConfig` est chargé, un listener
// dans `app.dart` appelle `RuntimeLimits.apply(...)` pour réaligner les
// valeurs.
//
// Fallback = valeurs par défaut historiques (CSV 2 MiB / 50 lignes, photos
// colis max 4, description 280 chars, etc.). Les tests unitaires qui
// n'instancient pas de `PublicConfigProvider` continuent de voir ces valeurs
// stables.

import '../models/public_config.dart';

/// Point d'accès unique aux limites runtime. Les écrans Flutter lisent
/// généralement `ref.watch(limitsConfigProvider)`; mais pour un code hors
/// Widget (service, store, helper), `RuntimeLimits.current` est accessible
/// synchroniquement.
class RuntimeLimits {
  const RuntimeLimits._();

  /// Snapshot courant — par défaut le fallback statique, mis à jour par
  /// `apply()` dès que `/public/config` répond.
  static LimitsConfig current = kLimitsFallback;

  /// Applique la configuration — à appeler depuis un listener du provider.
  /// Chaque champ est fourni par `LimitsConfig.fromJson` qui valide déjà
  /// la positivité, donc on peut remplacer l'instance entière en toute
  /// sécurité.
  static void apply(LimitsConfig limits) {
    current = limits;
  }
}
