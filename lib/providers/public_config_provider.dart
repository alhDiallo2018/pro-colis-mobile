// lib/providers/public_config_provider.dart
//
// Charge la configuration publique (`/public/config`) et la partage dans
// l'application. Les valeurs métier (commission, points, retraits, contact
// support) proviennent exclusivement de cette configuration : rien n'est codé
// en dur dans les écrans.

import 'package:flutter/foundation.dart';
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
  PublicConfigNotifier({Future<Map<String, dynamic>> Function()? loadConfig})
      : _loadConfig = loadConfig ?? ApiService().getPublicConfig,
        super(null);

  final Future<Map<String, dynamic>> Function() _loadConfig;
  Future<bool>? _pendingLoad;

  /// Partage la requête en cours entre le démarrage et l'ouverture de l'aide :
  /// une réponse plus ancienne ne doit pas écraser une configuration récente.
  Future<bool> load() async {
    if (_pendingLoad != null) return _pendingLoad!;
    final pending = _load();
    _pendingLoad = pending;
    try {
      return await pending;
    } finally {
      _pendingLoad = null;
    }
  }

  Future<bool> _load() async {
    try {
      final raw = await _loadConfig();
      if (raw.isEmpty) {
        throw const FormatException("Configuration publique indisponible");
      }
      final config = PublicConfig.fromJson(raw);

      // Applique la commission configurée au service de calcul local, afin que
      // les écrans (points, missions) reflètent la valeur administrée.
      CommissionService.configure(CommissionConfig(
        percentage: config.commissionPercentage,
        minimum: config.commissionMinimum,
        maximum: config.commissionMaximum,
      ));
      CommissionService.setInsufficientPolicy(config.insufficientPolicy);

      if (!mounted) return false;
      state = config;
      return true;
    } catch (error, stackTrace) {
      // Conserve la dernière réponse valide sans remplacer le contenu administré
      // par des FAQ locales. L'appelant peut proposer de réessayer.
      debugPrint('[PublicConfig] Chargement impossible : $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
