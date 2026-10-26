import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/app_update_policy.dart';

final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
  final notifier = AppUpdateNotifier();
  unawaited(notifier.refresh());
  return notifier;
});

class AppUpdateState {
  const AppUpdateState(
      {this.initialized = false,
      this.policy,
      this.installed,
      this.showPrompt = false,
      this.mandatory = false,
      this.checking = false,
      this.checkFailed = false});
  final bool initialized;
  final AppUpdatePolicy? policy;
  final AppRelease? installed;
  final bool showPrompt;
  final bool mandatory;
  final bool checking;
  final bool checkFailed;
}

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  AppUpdateNotifier({
    Future<Map<String, dynamic>> Function()? loadPolicy,
    Future<AppRelease> Function()? loadInstalled,
    Future<SharedPreferences> Function()? loadPreferences,
    DateTime Function()? now,
    bool? supported,
  })  : _loadPolicy = loadPolicy ?? _fetchPolicy,
        _loadInstalled = loadInstalled ?? _readInstalled,
        _loadPreferences = loadPreferences ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now,
        _supported = supported ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android),
        super(const AppUpdateState());

  // Isoler Docker et production évite qu'une politique de test bloque un autre serveur.
  static final cacheKey = 'android_update_policy_v2:${AppConfig.apiBaseUrl}';
  static final dismissalKey =
      'android_update_dismissal_v2:${AppConfig.apiBaseUrl}';
  final Future<Map<String, dynamic>> Function() _loadPolicy;
  final Future<AppRelease> Function() _loadInstalled;
  final Future<SharedPreferences> Function() _loadPreferences;
  final DateTime Function() _now;
  final bool _supported;
  SharedPreferences? _preferences;
  AppRelease? _installed;
  AppUpdatePolicy? _policy;
  String? _dismissedRelease;
  DateTime? _dismissedUntil;
  DateTime? _lastCheck;
  bool _cacheLoaded = false;
  bool _initialized = false;
  bool get supported => _supported;
  Future<void>? _pending;

  static Future<AppRelease> _readInstalled() async {
    final info = await PackageInfo.fromPlatform();
    return AppRelease(info.version, int.parse(info.buildNumber));
  }

  static Future<Map<String, dynamic>> _fetchPolicy() async {
    // Client public indépendant des intercepteurs d'authentification : une
    // vérification de version ne doit ni renouveler ni effacer une session.
    final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10)));
    try {
      final response = await dio.get('/public/mobile-update');
      final data = response.data;
      if (data is! Map || data['success'] != true || data['android'] is! Map) {
        throw const FormatException('Réponse de mise à jour invalide');
      }
      return Map<String, dynamic>.from(data['android'] as Map);
    } finally {
      dio.close(force: true);
    }
  }

  /// Single-flight entre démarrage, retour du store et vérification périodique.
  /// Le délai limite les appels après les multiples événements Android resumed.
  Future<void> refresh({bool force = false}) async {
    if (!_supported) {
      _initialized = true;
      _emit();
      return;
    }
    if (_pending != null) return _pending!;
    if (!force &&
        _lastCheck != null &&
        _now().difference(_lastCheck!) < const Duration(minutes: 1)) return;
    final pending = _refresh();
    _pending = pending;
    try {
      await pending;
    } finally {
      _pending = null;
    }
  }

  Future<void> _refresh() async {
    _lastCheck = _now();
    _emit(checking: true);
    try {
      _installed = await _loadInstalled().timeout(const Duration(seconds: 10));
      await _readCache();
      _emit(checking: true);
      final raw = await _loadPolicy().timeout(const Duration(seconds: 12));
      final policy = AppUpdatePolicy.fromJson(raw);
      if (!mounted) return;
      _policy = policy;
      _initialized = true;
      _emit();
      // L'échec d'écriture du cache ne doit pas annuler une règle fraîchement
      // reçue, notamment une désactivation décidée côté serveur.
      try {
        await _preferences?.setString(cacheKey, jsonEncode(policy.toJson()));
      } catch (error, stack) {
        _log('Écriture du cache', error, stack);
      }
    } catch (error, stack) {
      _log('Vérification', error, stack);
      _initialized = true;
      _emit(checkFailed: true);
    }
  }

  Future<void> _readCache() async {
    if (_cacheLoaded) return;
    try {
      _preferences ??=
          await _loadPreferences().timeout(const Duration(seconds: 5));
      final raw = _preferences!.getString(cacheKey);
      if (raw != null)
        _policy = AppUpdatePolicy.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw)));
      final dismissal = _preferences!.getString(dismissalKey);
      if (dismissal != null) {
        final data = jsonDecode(dismissal) as Map;
        _dismissedRelease = data['release'] as String;
        _dismissedUntil = DateTime.parse(data['until'] as String);
      }
      _cacheLoaded = true;
    } catch (error, stack) {
      // Un cache absent/corrompu ou un stockage indisponible n'empêche pas la
      // lecture réseau. Une règle déjà connue reste en mémoire.
      _log('Lecture du cache', error, stack);
    }
  }

  Future<void> dismiss() async {
    if (!state.showPrompt || state.mandatory || _policy == null) return;
    _dismissedRelease = _policy!.latest.build.toString();
    _dismissedUntil = _now().add(Duration(hours: _policy!.remindAfterHours));
    _emit();
    try {
      await _preferences?.setString(
          dismissalKey,
          jsonEncode({
            'release': _dismissedRelease,
            'until': _dismissedUntil!.toIso8601String(),
          }));
    } catch (error, stack) {
      _log('Report du rappel', error, stack);
    }
  }

  /// Une vérification explicite depuis les paramètres peut rouvrir une
  /// proposition reportée. Elle ne contourne jamais le seuil obligatoire.
  Future<void> checkNow() async {
    await refresh(force: true);
    if (!mounted ||
        _installed == null ||
        !(_policy?.hasUpdate(_installed!) ?? false)) return;
    _dismissedRelease = null;
    _dismissedUntil = null;
    _emit(checkFailed: state.checkFailed);
    try {
      await _preferences?.remove(dismissalKey);
    } catch (error, stack) {
      _log('Suppression du report', error, stack);
    }
  }

  void _emit({bool checking = false, bool checkFailed = false}) {
    if (!mounted) return;
    final mandatory =
        _installed != null && (_policy?.requiresUpdate(_installed!) ?? false);
    final deferred = _policy?.latest.build.toString() == _dismissedRelease &&
        (_dismissedUntil?.isAfter(_now()) ?? false);
    state = AppUpdateState(
        initialized: _initialized,
        policy: _policy,
        installed: _installed,
        mandatory: mandatory,
        checking: checking,
        checkFailed: checkFailed,
        // Une hausse du minimum l'emporte sur « Plus tard ».
        showPrompt: mandatory ||
            (_installed != null &&
                !deferred &&
                (_policy?.hasUpdate(_installed!) ?? false)));
  }

  void _log(String action, Object error, StackTrace stack) {
    debugPrint('[AppUpdate] $action : ${error.runtimeType}');
    debugPrintStack(stackTrace: stack);
  }
}
