import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/broadcast.dart';
import '../services/broadcast_service.dart';

final broadcastProvider = FutureProvider<List<Broadcast>>((ref) async {
  // `/public/broadcasts` accepte un visiteur anonyme et constitue désormais
  // l'unique source de lecture. Le service gère le cache hors ligne.
  return BroadcastService().fetchActiveBroadcasts();
});

final dismissedBroadcastsProvider = StateProvider<Set<String>>((ref) => {});

Future<Set<String>> _loadDismissed() async {
  try {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList('procolis-broadcasts-dismissed');
    return raw?.toSet() ?? {};
  } catch (_) {
    return {};
  }
}

Future<void> _saveDismissed(Set<String> ids) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setStringList('procolis-broadcasts-dismissed', ids.toList());
}

Future<void> dismissBroadcast(String id) async {
  final dismissed = await _loadDismissed();
  dismissed.add(id);
  await _saveDismissed(dismissed);
}

List<Broadcast> filterActiveBroadcasts(
    List<Broadcast> all, Set<String> dismissed, String? role) {
  if (role == null) return [];
  final now = DateTime.now();
  return all.where((b) {
    if (!b.active) return false;
    if (!b.targetRoles.contains(role)) return false;
    if (b.startsAt?.isAfter(now) == true) return false;
    if (b.endsAt?.isBefore(now) == true) return false;
    if (dismissed.contains(b.id)) return false;
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
