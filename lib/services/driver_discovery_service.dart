import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'auth_session.dart';
import 'location_fix.dart';

/// Partage volontaire au premier plan, indépendant du suivi de livraison.
/// La position expire côté serveur après dix minutes sans actualisation.
class DriverDiscoveryService extends ValueNotifier<bool> {
  DriverDiscoveryService._() : super(false);
  static final instance = DriverDiscoveryService._();
  final _api = ApiService();
  Timer? _timer;
  SessionTokens? _session;
  int _generation = 0;
  bool _updating = false;
  Future<void> _requests = Future<void>.value();
  String? error;

  Future<void> _serialize(Future<void> Function() action) {
    final result = _requests.then((_) => action());
    _requests = result.catchError((Object _) {});
    return result;
  }

  Future<void> start() async {
    final generation = ++_generation;
    final session = await AuthSessionManager.instance.read();
    if (generation != _generation) return;
    if (session == null) throw StateError('Session requise');
    _session = session;
    error = null;
    try {
      await _publish(generation);
      if (generation != _generation) return;
      value = true;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
        try {
          if (!_updating) await _publish(generation);
        } catch (failure, stack) {
          debugPrint(
              '[Discovery] Actualisation impossible (${failure.runtimeType})');
          debugPrintStack(stackTrace: stack);
          await stop();
          error =
              'Partage interrompu. La dernière position expire sous 10 minutes.';
          notifyListeners();
        }
      });
    } catch (failure) {
      value = false;
      error = failure is LocationFailure
          ? failure.message
          : 'Impossible d’activer le partage de position.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _publish(int generation) async {
    if (generation != _generation) return;
    if (_updating) throw StateError('Une acquisition GPS est déjà en cours');
    _updating = true;
    final session = _session;
    try {
      final position = await resolveCurrentPosition();
      // Une désactivation pendant l'acquisition annule l'envoi. La file
      // ordonne aussi la suppression après toute publication déjà en vol.
      if (session == null || generation != _generation) return;
      await _serialize(() async {
        if (generation != _generation) return;
        await _api.shareDiscoveryPosition(
            enabled: true,
            session: session,
            latitude: position.latitude,
            longitude: position.longitude);
      });
    } finally {
      _updating = false;
    }
  }

  Future<void> stop() async {
    _generation++;
    _timer?.cancel();
    _timer = null;
    value = false;
    final session = _session;
    _session = null;
    if (session == null) return;
    try {
      await _serialize(
          () => _api.shareDiscoveryPosition(enabled: false, session: session));
      error = null;
    } catch (failure, stack) {
      error =
          'Partage arrêté sur ce téléphone. La dernière position expire sous 10 minutes.';
      debugPrint('[Discovery] Suppression différée (${failure.runtimeType})');
      debugPrintStack(stackTrace: stack);
    }
    notifyListeners();
  }
}
