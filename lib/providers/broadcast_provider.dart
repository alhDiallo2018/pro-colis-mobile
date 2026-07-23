import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/broadcast.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

const _cacheKey = 'procolis-broadcasts';

final broadcastProvider = FutureProvider<List<Broadcast>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) return [];

  final cached = await _loadCachedBroadcasts();
  if (cached.isNotEmpty) {
    _refreshFromApi();
    return cached;
  }

  try {
    final api = ApiService();
    final config = await api.getAdminConfig();
    final broadcasts = _extractBroadcasts(config);
    if (broadcasts.isNotEmpty) {
      _cacheBroadcasts(broadcasts);
      return broadcasts;
    }
  } catch (_) {}

  return cached;
});

Future<void> _refreshFromApi() async {
  try {
    final api = ApiService();
    final config = await api.getAdminConfig();
    final broadcasts = _extractBroadcasts(config);
    if (broadcasts.isNotEmpty) {
      _cacheBroadcasts(broadcasts);
    }
  } catch (_) {}
}

List<Broadcast> _extractBroadcasts(Map<String, dynamic> response) {
  final raw = _findBroadcastsRaw(response);
  if (raw is! List) return [];
  return raw
      .map((b) => Broadcast.fromJson(b is Map<String, dynamic> ? b : {}))
      .toList();
}

dynamic _findBroadcastsRaw(Map<String, dynamic> response) {
  final keys = ['config', 'data'];
  for (final k in keys) {
    final val = response[k];
    if (val is List) {
      for (final item in val) {
        if (item is Map<String, dynamic> && item['key'] == 'broadcasts') {
          final raw = item['value'];
          if (raw is String) {
            try { return jsonDecode(raw); } catch (_) {}
          }
          return raw;
        }
      }
    }
    if (val is Map<String, dynamic>) {
      final broadcasts = val['broadcasts'];
      if (broadcasts != null) return broadcasts;
    }
  }
  final broadcasts = response['broadcasts'];
  if (broadcasts != null) return broadcasts;
  return null;
}

Future<void> _cacheBroadcasts(List<Broadcast> broadcasts) async {
  try {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(broadcasts.map((b) => b.toJson()).toList());
    await sp.setString(_cacheKey, encoded);
  } catch (_) {}
}

Future<List<Broadcast>> _loadCachedBroadcasts() async {
  try {
    final sp = await SharedPreferences.getInstance();
    final encoded = sp.getString(_cacheKey);
    if (encoded == null || encoded.isEmpty) return [];
    final list = jsonDecode(encoded) as List<dynamic>;
    return list.map((e) => Broadcast.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

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
