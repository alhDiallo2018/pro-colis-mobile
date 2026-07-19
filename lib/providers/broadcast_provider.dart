import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/broadcast.dart';
import '../services/broadcast_service.dart';
import '../providers/auth_provider.dart';

final broadcastProvider = FutureProvider<List<Broadcast>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) return [];
  final service = BroadcastService();
  return service.fetchActiveBroadcasts();
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

List<Broadcast> filterActiveBroadcasts(List<Broadcast> all, Set<String> dismissed, String? role) {
  if (role == null) return [];
  final now = DateTime.now().toIso8601String();
  return all.where((b) {
    if (!b.active) return false;
    if (!b.targetRoles.contains(role)) return false;
    if (b.startsAt.isNotEmpty && b.startsAt.compareTo(now) > 0) return false;
    if (b.endsAt.isNotEmpty && b.endsAt.compareTo(now) < 0) return false;
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
    case 'super_admin':
      return 'Super Admin';
    default:
      return role;
  }
}
