// lib/services/parcel_template_store.dart
//
// Modèles de colis réutilisables (local-only). Un modèle encapsule un
// snapshot JSON des champs métier d'un formulaire de création — pas de
// fichier ni d'identifiant distant : purement une aide à la saisie.
//
// Cloisonné par `ownerId` et, comme les brouillons, stocké dans
// SharedPreferences sous `parcel_templates.<owner>`. Pas de synchronisation
// serveur : si l'utilisateur change de téléphone ou réinstalle, les modèles
// disparaissent. C'est intentionnel — un modèle local évite d'inventer un
// endpoint serveur juste pour ça.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ParcelTemplate {
  final String id;
  final String name;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  const ParcelTemplate({
    required this.id,
    required this.name,
    required this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ParcelTemplate.fromJson(Map<String, dynamic> json) =>
      ParcelTemplate(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class ParcelTemplateStore {
  ParcelTemplateStore({String? ownerId})
      : _owner = (ownerId == null || ownerId.trim().isEmpty)
            ? 'anon'
            : ownerId.trim();

  static const _prefix = 'parcel_templates';
  static const _uuid = Uuid();

  final String _owner;

  String get _key => '$_prefix.$_owner';

  Future<List<ParcelTemplate>> list() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => ParcelTemplate.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (error) {
      debugPrint('[ParcelTemplateStore] Lecture impossible: $error');
      return const [];
    }
  }

  Future<ParcelTemplate> save({
    required String name,
    required Map<String, dynamic> data,
  }) async {
    final templates = await list();
    final template = ParcelTemplate(
      id: _uuid.v4(),
      name: name.trim(),
      data: data,
      createdAt: DateTime.now(),
    );
    final next = [template, ...templates];
    await _persist(next);
    return template;
  }

  Future<void> delete(String id) async {
    final templates = await list();
    final next = templates.where((t) => t.id != id).toList();
    await _persist(next);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _persist(List<ParcelTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }
}
