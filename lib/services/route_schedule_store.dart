import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrairement à un brouillon ordinaire, une demande envoyée ne doit pas
/// expirer : son identifiant permet de vérifier un résultat réseau incertain.
class RouteScheduleStore {
  RouteScheduleStore(this.ownerId);
  final String ownerId;
  String get _key {
    if (ownerId.isEmpty) throw StateError('Compte requis');
    return 'route_schedule_pending.$ownerId';
  }

  Future<Map<String, dynamic>?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> save(Map<String, dynamic> value) async {
    if (!await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(value)))
      throw StateError('Impossible de sécuriser la demande sur ce téléphone');
  }

  Future<void> clear() async {
    if (!await (await SharedPreferences.getInstance()).remove(_key))
      throw StateError('Impossible de terminer la demande locale');
  }
}
