import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_session.dart';
import 'background_location.dart';
import 'location_fix.dart';

/// Le booléen représente le choix du chauffeur, pas la présence d’un signal.
/// Ce choix est mémorisé par compte jusqu’à une désactivation explicite.
class DriverDiscoveryService extends ValueNotifier<bool> {
  DriverDiscoveryService._()
      : _api = ApiService(),
        super(false);
  DriverDiscoveryService.forTesting(ApiService api)
      : _api = api,
        super(false);
  static final instance = DriverDiscoveryService._();
  final ApiService _api;
  StreamSubscription<Position>? _positions;
  Timer? _retry;
  SessionTokens? _session;
  String? _userId;
  bool _available = false;
  int _generation = 0;
  int? _updatingGeneration;
  DateTime? _lastSent;
  Future<void>? _starting;
  Future<void> _requests = Future<void>.value();
  Future<void> _preferences = Future<void>.value();
  String? error;
  static String preferenceKey(String userId) =>
      'procolis.discovery.enabled.$userId';

  Future<void> _serialize(Future<void> Function() action) {
    final result = _requests.then((_) => action());
    _requests = result.catchError((Object _) {});
    return result;
  }

  Future<void> _remember(String userId, bool enabled) {
    final result = _preferences.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setBool(preferenceKey(userId), enabled)) {
        throw StateError('Préférence de partage non enregistrée');
      }
    });
    _preferences = result.catchError((Object _) {});
    return result;
  }

  Future<void> restoreForUser(String? userId, {required bool available}) async {
    if (_userId == userId && _available == available) {
      if (value && available) await resume();
      return;
    }
    // Invalidation immédiate avant toute lecture disque : un ancien GPS ne
    // peut pas publier sous le compte suivant pendant son chargement.
    final closing = _stopNative();
    final generation = _generation;
    _userId = userId;
    _available = available;
    value = false;
    error = null;
    try {
      await closing;
      if (userId == null) return;
      await _preferences;
      final preferences = await SharedPreferences.getInstance();
      if (generation != _generation || _userId != userId) return;
      value = preferences.getBool(preferenceKey(userId)) ?? false;
      if (!value) return;
      if (!available) {
        error =
            'Partage activé. La position sera actualisée lorsque vous serez disponible.';
        notifyListeners();
        return;
      }
      await resume();
    } catch (failure, stack) {
      if (generation != _generation) return;
      _waiting(failure, stack);
    }
  }

  Future<void> start({required String userId}) async {
    await restoreForUser(userId, available: true);
    // La préférence est écrite avant l’activation, puis les erreurs GPS/réseau
    // ne la modifient plus. Seul stop() enregistre explicitement false.
    final generation = _generation;
    await _remember(userId, true);
    if (generation != _generation || _userId != userId) return;
    value = true;
    error = null;
    _retry ??= Timer.periodic(
        const Duration(seconds: 30), (_) => unawaited(_ensureRunning()));
    await _ensureRunning(requestPermission: true);
  }

  Future<void> resume() async {
    if (!value || !_available || _userId == null) return;
    _retry ??= Timer.periodic(
        const Duration(seconds: 30), (_) => unawaited(_ensureRunning()));
    await _ensureRunning();
  }

  Future<void> _ensureRunning({bool requestPermission = false}) async {
    if (!value || !_available || _userId == null || _positions != null) return;
    final starting = _starting;
    if (starting != null) return starting;
    final pending =
        _startNative(_generation, requestPermission: requestPermission);
    _starting = pending;
    try {
      await pending;
    } finally {
      if (identical(_starting, pending)) _starting = null;
    }
  }

  Future<void> _startNative(int generation,
      {required bool requestPermission}) async {
    try {
      final session = await AuthSessionManager.instance.read();
      if (generation != _generation) return;
      if (session == null) throw StateError('Session requise');
      // Une reprise automatique ne doit jamais multiplier les demandes de
      // permission : seul le geste d’activation peut ouvrir le dialogue système.
      if (!requestPermission) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw const LocationFailure(LocationFailureKind.permissionDenied,
              'Autorisez la localisation dans les réglages de l’application.');
        }
      }
      final position = await resolveCurrentPosition();
      if (generation != _generation || !value || !_available) return;
      _session = session;
      _positions = Geolocator.getPositionStream(
          locationSettings: backgroundLocationSettings(
        title: 'ProColis · partage de position activé',
        text:
            'Votre position reste partagée jusqu’à sa désactivation dans l’application.',
      )).listen((position) async {
        try {
          await _publish(position, generation);
        } catch (failure, stack) {
          if (generation == _generation) _waiting(failure, stack);
        }
      }, onError: (Object failure, StackTrace stack) {
        if (generation != _generation) return;
        final positions = _positions;
        _positions = null;
        if (positions != null) unawaited(positions.cancel());
        _waiting(failure, stack);
      }, onDone: () {
        if (generation != _generation) return;
        _positions = null;
        error = 'Partage activé. En attente d’une nouvelle position.';
        notifyListeners();
      });
      await _publish(position, generation);
    } catch (failure, stack) {
      if (generation == _generation) _waiting(failure, stack);
    }
  }

  void _waiting(Object failure, StackTrace stack) {
    debugPrint('[Discovery] Actualisation différée (${failure.runtimeType})');
    debugPrintStack(stackTrace: stack);
    error = failure is LocationFailure
        ? 'Partage activé. ${failure.message} Reprise automatique dès que possible.'
        : 'Partage activé. En attente de connexion pour actualiser la position.';
    notifyListeners();
  }

  Future<void> _publish(Position position, int generation) async {
    final session = _session;
    if (session == null ||
        generation != _generation ||
        !value ||
        _updatingGeneration == generation ||
        !isRecentPosition(position) ||
        (_lastSent != null &&
            position.timestamp.difference(_lastSent!) <
                const Duration(minutes: 1))) return;
    _updatingGeneration = generation;
    try {
      await _serialize(() async {
        if (generation != _generation || !value) return;
        await _api.shareDiscoveryPosition(
            enabled: true,
            session: session,
            latitude: position.latitude,
            longitude: position.longitude);
      });
      if (generation == _generation) {
        _lastSent = position.timestamp;
        error = null;
        notifyListeners();
      }
    } finally {
      if (_updatingGeneration == generation) _updatingGeneration = null;
    }
  }

  /// Suspension de session/indisponibilité : aucun effacement du consentement.
  Future<void> suspend() => _stopNative();

  Future<void> _stopNative() async {
    _generation++;
    _retry?.cancel();
    _retry = null;
    _starting = null;
    final positions = _positions;
    _positions = null;
    _lastSent = null;
    final session = _session;
    _session = null;
    await positions?.cancel();
    if (session == null) return;
    try {
      await _serialize(
          () => _api.shareDiscoveryPosition(enabled: false, session: session));
    } catch (failure) {
      debugPrint('[Discovery] Suppression différée (${failure.runtimeType})');
    }
  }

  Future<void> stop() async {
    final userId = _userId;
    value = false;
    final closing = _stopNative();
    try {
      if (userId != null) await _remember(userId, false);
      await closing;
      error = null;
    } catch (failure, stack) {
      // L’arrêt local est immédiat, même si le stockage ou le réseau échoue.
      error =
          'Partage arrêté ici. Vérifiez son état lors de la prochaine ouverture.';
      debugPrint('[Discovery] Arrêt non confirmé (${failure.runtimeType})');
      debugPrintStack(stackTrace: stack);
    }
    notifyListeners();
  }
}
