import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/broadcast.dart';
import '../services/broadcast_service.dart';

final broadcastProvider = FutureProvider<List<Broadcast>>((ref) async {
  // `/public/broadcasts` accepte un visiteur anonyme et constitue désormais
  // l'unique source de lecture. Le service gère le cache hors ligne.
  return BroadcastService().fetchActiveBroadcasts();
});

/// Une fermeture utilisateur met le bandeau en veille sans le supprimer.
///
/// Deux heures évitent qu'il réapparaisse à chaque navigation tout en
/// garantissant qu'une annonce encore active sera revue plus tard.
const Duration broadcastSnoozeDuration = Duration(hours: 2);

const String _legacyDismissedKey = 'procolis-broadcasts-dismissed';
const String _snoozeKeyPrefix = 'procolis-broadcasts-snoozed-until';

String _snoozeKey(String userScope) =>
    '$_snoozeKeyPrefix-${Uri.encodeComponent(userScope)}';

Future<Map<String, DateTime>> loadBroadcastSnoozes(String userScope) async {
  try {
    final sp = await SharedPreferences.getInstance();
    // Les anciennes versions masquaient les identifiants définitivement.
    // Supprimer cette clé fait réapparaître ces annonces si elles sont encore
    // actives, puis seul le nouveau mécanisme horodaté est utilisé.
    if (sp.containsKey(_legacyDismissedKey)) {
      await sp.remove(_legacyDismissedKey);
    }

    final encoded = sp.getString(_snoozeKey(userScope));
    if (encoded == null || encoded.isEmpty) return {};

    final decoded = jsonDecode(encoded);
    if (decoded is! Map) return {};

    final now = DateTime.now();
    final activeSnoozes = <String, DateTime>{};
    for (final entry in decoded.entries) {
      final until = DateTime.tryParse(entry.value.toString());
      if (until != null && until.isAfter(now)) {
        activeSnoozes[entry.key.toString()] = until;
      }
    }

    // Purger les délais expirés empêche le stockage local de grossir au fil
    // des campagnes administrateur.
    if (activeSnoozes.length != decoded.length) {
      await _saveBroadcastSnoozes(userScope, activeSnoozes);
    }
    return activeSnoozes;
  } catch (error, stackTrace) {
    debugPrint(
      'BroadcastProvider: lecture des mises en veille impossible '
      '($error)\n$stackTrace',
    );
    return {};
  }
}

Future<void> _saveBroadcastSnoozes(
  String userScope,
  Map<String, DateTime> snoozes,
) async {
  final sp = await SharedPreferences.getInstance();
  final encoded = jsonEncode(
    snoozes.map(
      (broadcastId, until) =>
          MapEntry(broadcastId, until.toUtc().toIso8601String()),
    ),
  );
  await sp.setString(_snoozeKey(userScope), encoded);
}

Future<DateTime> snoozeBroadcast(
  String id,
  String userScope, {
  Duration duration = broadcastSnoozeDuration,
}) async {
  final snoozes = await loadBroadcastSnoozes(userScope);
  final until = DateTime.now().add(duration);
  snoozes[id] = until;
  await _saveBroadcastSnoozes(userScope, snoozes);
  return until;
}

Future<void> restoreBroadcast(String id, String userScope) async {
  final snoozes = await loadBroadcastSnoozes(userScope);
  snoozes.remove(id);
  await _saveBroadcastSnoozes(userScope, snoozes);
}

List<Broadcast> filterActiveBroadcasts(
  List<Broadcast> all,
  Map<String, DateTime> snoozedUntil,
  String? role,
) {
  if (role == null) return [];
  final now = DateTime.now();
  return all.where((b) {
    if (!b.active) return false;
    if (!b.targetRoles.contains(role)) return false;
    if (b.startsAt?.isAfter(now) == true) return false;
    if (b.endsAt?.isBefore(now) == true) return false;
    if (snoozedUntil[b.id]?.isAfter(now) == true) return false;
    return true;
  }).toList();
}

String broadcastRoleLabel(String role) {
  switch (role) {
    case 'client':
      return 'Client';
    case 'driver':
      return 'Chauffeur';
    case 'admin':
      return 'Admin zone';
    case 'support_technique':
      return 'Support technique';
    case 'support_commercial':
      return 'Support commercial';
    case 'support':
      return 'Support';
    case 'super_admin':
      return 'Super Admin';
    default:
      return role;
  }
}
