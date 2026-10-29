import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'auth_session.dart';
import 'location_fix.dart';
import 'background_location.dart';

/// Consentement distinct de la découverte approximative : ce flux précis est
/// attaché à un départ, continue en arrière-plan et se termine explicitement.
class JourneyLiveService extends ChangeNotifier {
  JourneyLiveService._();
  static final instance = JourneyLiveService._();
  final _api = ApiService();
  StreamSubscription<Position>? _positions;
  Timer? _watchdog;
  SessionTokens? _auth;
  String? advertisementId, sessionId, error;
  bool starting = false;
  int _generation = 0;
  DateTime? _lastSent;
  Future<void> _requests = Future<void>.value();
  bool get active => sessionId != null;

  Future<T> _queue<T>(Future<T> Function() action) {
    final pending = _requests.then((_) => action());
    _requests =
        pending.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return pending;
  }

  Map<String, dynamic> _fix(Position p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracyMeters': p.accuracy,
        'capturedAt': p.timestamp.toUtc().toIso8601String()
      };

  Future<void> start(String departureId) async {
    if (starting) return;
    starting = true;
    error = null;
    notifyListeners();
    await stop(clearError: false);
    final generation = ++_generation;
    try {
      final auth = await AuthSessionManager.instance.read();
      if (auth == null) throw StateError('Session requise');
      final position = await resolveCurrentPosition(
          accuracy: LocationAccuracy.bestForNavigation);
      if (generation != _generation) return;
      final session = await _queue(
          () => _api.startJourneyLive(departureId, _fix(position), auth));
      // Une déconnexion pendant l’activation ne doit laisser ni flux actif ni
      // publication associée au compte suivant.
      if (generation != _generation) {
        await _queue(() => _api.stopJourneyLive(departureId, session, auth));
        return;
      }
      _auth = auth;
      advertisementId = departureId;
      sessionId = session;
      _lastSent = position.timestamp;
      final settings = backgroundLocationSettings(
        title: 'ProColis · trajet en cours',
        text: 'Votre position reste partagée pour ce départ jusqu’à l’arrêt du suivi.');
      _watchdog = Timer.periodic(const Duration(seconds: 15), (_) async {
        if (generation == _generation &&
            _lastSent != null &&
            DateTime.now().difference(_lastSent!).inSeconds > 60) {
          // La fraîcheur reste contrôlée côté serveur. Une absence temporaire
          // de GPS n’annule pas le consentement ni le flux natif : il reprendra
          // dès qu’une vraie mesure récente redeviendra disponible.
          error = 'Signal GPS indisponible. En attente d’une nouvelle position.';
          notifyListeners();
        }
      });
      _positions = Geolocator.getPositionStream(locationSettings: settings)
          .listen((p) async {
        if (generation != _generation ||
            DateTime.now().difference(p.timestamp).inSeconds > 55 ||
            (_lastSent != null &&
                p.timestamp.difference(_lastSent!).inSeconds < 8)) return;
        _lastSent = p.timestamp;
        try {
          await _queue(() async {
            if (generation != _generation) return;
            await _api.updateJourneyLive(departureId, session, _fix(p), auth);
          });
          if (generation == _generation && error != null) {
            error = null;
            notifyListeners();
          }
        } catch (failure, stack) {
          if (generation != _generation) return;
          final temporary = failure is ApiException
              ? failure.statusCode == 429 || failure.statusCode >= 500
              : failure is! LocationFailure;
          if (temporary) {
            debugPrint('[JourneyLive] Envoi différé (${failure.runtimeType})');
            error = 'Connexion indisponible. Le suivi réessaiera automatiquement.';
            notifyListeners();
          } else {
            await _failed(failure, stack);
          }
        }
      }, onError: (Object failure, StackTrace stack) async {
        if (generation == _generation) await _failed(failure, stack);
      });
    } catch (failure, stack) {
      if (generation == _generation) await _failed(failure, stack);
    } finally {
      starting = false;
      notifyListeners();
    }
  }

  Future<void> _failed(Object failure, StackTrace stack) async {
    debugPrint('[JourneyLive] Suivi interrompu (${failure.runtimeType})');
    debugPrintStack(stackTrace: stack);
    await stop(clearError: false);
    error = failure is LocationFailure
        ? failure.message
        : failure is ApiException
            ? failure.message
            : 'Suivi interrompu. Vérifiez le GPS, la connexion et le départ, puis réessayez.';
    notifyListeners();
  }

  Future<void> stop({bool clearError = true}) async {
    ++_generation;
    _watchdog?.cancel();
    _watchdog = null;
    final auth = _auth, trip = advertisementId, session = sessionId;
    _auth = null;
    advertisementId = null;
    sessionId = null;
    await _positions?.cancel();
    _positions = null;
    if (clearError) error = null;
    notifyListeners();
    if (auth == null || trip == null || session == null) return;
    try {
      await _queue(() => _api.stopJourneyLive(trip, session, auth));
    } catch (failure) {
      debugPrint('[JourneyLive] Arrêt réseau différé (${failure.runtimeType})');
      error =
          'Suivi arrêté ici. Sans connexion, la dernière mesure disparaît sous une minute.';
      notifyListeners();
    }
  }
}
