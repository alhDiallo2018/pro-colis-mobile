// lib/providers/public_config_provider.dart
//
// Charge la configuration publique (`/public/config`) et la partage dans
// l'application. Les valeurs métier (commission, points, retraits, contact
// support) proviennent exclusivement de cette configuration : rien n'est codé
// en dur dans les écrans.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/public_config.dart';
import '../services/api_service.dart';
import '../services/commission_service.dart';

/// Dernière configuration publique chargée (null tant qu'elle n'est pas lue).
final publicConfigProvider =
    StateNotifierProvider<PublicConfigNotifier, PublicConfig?>((ref) {
  final notifier = PublicConfigNotifier();
  notifier.load();
  return notifier;
});

class PublicConfigNotifier extends StateNotifier<PublicConfig?> {
  PublicConfigNotifier() : super(null);

  final ApiService _api = ApiService();

  Future<void> load() async {
    try {
      final raw = await _api.getPublicConfig();
      if (raw.isEmpty) return;
      final config = PublicConfig.fromJson(raw);

      // Applique la commission configurée au service de calcul local, afin que
      // les écrans (points, missions) reflètent la valeur administrée.
      CommissionService.configure(CommissionConfig(
        percentage: config.commissionPercentage,
        minimum: config.commissionMinimum,
        maximum: config.commissionMaximum,
      ));
      CommissionService.setInsufficientPolicy(config.insufficientPolicy);

      state = config;
    } catch (_) {
      // Échec réseau : on conserve les valeurs déjà en mémoire. Les écrans
      // affichent un repli cohérent tant que la config n'est pas disponible.
    }
  }
}
