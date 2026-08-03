// lib/services/form_draft_store.dart
//
// Brouillons de formulaires : conserve la saisie en cours pour qu'une sortie
// par inadvertance (swipe, croix, retour système) ne la fasse pas perdre.
//
// Un brouillon est un simple document JSON dans les SharedPreferences, cloisonné
// par formulaire (`slot`) et par compte (`ownerId`) pour qu'un utilisateur ne
// retrouve jamais la saisie d'un autre sur le même appareil. Les pièces jointes
// sont recopiées dans un dossier durable de l'app, parce que les fichiers rendus
// par `image_picker` vivent dans un cache que l'OS peut purger à tout moment.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Brouillon relu depuis le disque.
class FormDraft {
  const FormDraft({required this.data, required this.savedAt});

  final Map<String, dynamic> data;
  final DateTime savedAt;
}

class FormDraftStore {
  FormDraftStore({required this.slot, String? ownerId})
      : _owner = (ownerId == null || ownerId.trim().isEmpty)
            ? 'anon'
            : ownerId.trim();

  /// Identifie le formulaire : `colis`, `annonce`…
  final String slot;
  final String _owner;

  static const String _prefix = 'form_draft';
  static const String _mediaFolder = 'form_drafts';

  /// Au-delà, le brouillon est considéré comme périmé et ignoré : reproposer
  /// une saisie vieille de plusieurs semaines crée plus de confusion qu'il
  /// n'en évite.
  static const Duration maxAge = Duration(days: 7);

  String get _prefsKey => '$_prefix.$slot.$_owner';

  // ---- Lecture / écriture ----

  Future<FormDraft?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clear();
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
      final data = map['data'];
      if (savedAt == null || data is! Map) {
        await clear();
        return null;
      }
      if (DateTime.now().difference(savedAt) > maxAge) {
        await clear();
        return null;
      }
      return FormDraft(
        data: Map<String, dynamic>.from(data),
        savedAt: savedAt,
      );
    } catch (error) {
      // Une entrée illisible ne doit pas rester en travers : sans purge, elle
      // ferait échouer toutes les lectures suivantes de ce formulaire.
      debugPrint(
          '[FormDraftStore] Lecture du brouillon $slot impossible: $error');
      await clear();
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'data': data,
        }),
      );
    } catch (error) {
      debugPrint(
          '[FormDraftStore] Écriture du brouillon $slot impossible: $error');
    }
  }

  /// Supprime le brouillon et les pièces jointes qu'il détenait.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (error) {
      debugPrint(
          '[FormDraftStore] Suppression du brouillon $slot impossible: $error');
    }
    await purgeMedia();
  }

  // ---- Pièces jointes ----

  Future<Directory?> _mediaDir({bool create = true}) async {
    if (kIsWeb) return null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/$_mediaFolder/$slot/$_owner');
      if (create && !dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (error) {
      debugPrint('[FormDraftStore] Dossier média $slot indisponible: $error');
      return null;
    }
  }

  /// Recopie un fichier dans le dossier durable du brouillon et renvoie son
  /// nouveau chemin. Un fichier déjà adopté est renvoyé tel quel, ce qui rend
  /// l'appel idempotent : les sauvegardes automatiques répétées ne recopient
  /// rien.
  Future<String?> adoptMedia(String sourcePath) async {
    if (kIsWeb || sourcePath.isEmpty) return null;
    final dir = await _mediaDir();
    if (dir == null) return null;

    if (sourcePath.startsWith('${dir.path}/')) {
      return File(sourcePath).existsSync() ? sourcePath : null;
    }

    try {
      final source = File(sourcePath);
      if (!source.existsSync()) return null;

      final dotIndex = sourcePath.lastIndexOf('.');
      final slashIndex = sourcePath.lastIndexOf('/');
      final extension = (dotIndex > slashIndex && dotIndex != -1)
          ? sourcePath.substring(dotIndex)
          : '';
      final name =
          '${DateTime.now().microsecondsSinceEpoch}_${source.hashCode.toUnsigned(16)}$extension';
      final target = await source.copy('${dir.path}/$name');
      return target.path;
    } catch (error) {
      debugPrint('[FormDraftStore] Copie de $sourcePath impossible: $error');
      return null;
    }
  }

  /// Adopte une liste de chemins en écartant ceux qui ont disparu.
  Future<List<String>> adoptAll(Iterable<String> paths) async {
    final adopted = <String>[];
    for (final path in paths) {
      final result = await adoptMedia(path);
      if (result != null) adopted.add(result);
    }
    return adopted;
  }

  Future<void> purgeMedia() async {
    final dir = await _mediaDir(create: false);
    if (dir == null) return;
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (error) {
      debugPrint('[FormDraftStore] Purge média $slot impossible: $error');
    }
  }

  /// Retire du dossier durable les fichiers qui ne sont plus référencés — cas
  /// d'une pièce jointe ajoutée puis supprimée par l'utilisateur.
  Future<void> pruneMediaExcept(Iterable<String> keepPaths) async {
    final dir = await _mediaDir(create: false);
    if (dir == null || !dir.existsSync()) return;
    final keep = keepPaths.toSet();
    try {
      for (final entity in dir.listSync()) {
        if (entity is File && !keep.contains(entity.path)) {
          await entity.delete();
        }
      }
    } catch (error) {
      debugPrint('[FormDraftStore] Nettoyage média $slot impossible: $error');
    }
  }

  /// Efface tous les brouillons de l'appareil, quel que soit le compte. Appelé
  /// à la déconnexion pour ne rien laisser derrière soi.
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith('$_prefix.')) await prefs.remove(key);
      }
    } catch (error) {
      debugPrint(
          '[FormDraftStore] Purge globale des brouillons impossible: $error');
    }
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/$_mediaFolder');
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (error) {
      debugPrint(
          '[FormDraftStore] Purge globale des médias impossible: $error');
    }
  }
}
