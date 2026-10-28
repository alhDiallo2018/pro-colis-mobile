import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'auth_session.dart';

class OfflineStatus {
  const OfflineStatus({this.disconnected = false, this.savedAt});
  final bool disconnected;
  final DateTime? savedAt;
  bool get showNotice => disconnected || savedAt != null;
}

/// État commun aux clients HTTP. Les dates restent visibles après le retour
/// du réseau tant que certaines réponses affichées proviennent encore du cache.
class OfflineAccess extends ValueNotifier<OfflineStatus> {
  OfflineAccess() : super(const OfflineStatus());
  static final instance = OfflineAccess();
  final Map<String, DateTime> _stale = {};
  String? _generation;

  void useSession(String? generation) {
    if (_generation == generation) return;
    _generation = generation;
    _stale.clear();
    value = const OfflineStatus();
  }

  void failed() => _emit(true);
  void cached(String key, DateTime date) {
    _stale[key] = date;
    _emit(true);
  }

  void fresh(String key, {bool verifiedSession = false}) {
    _stale.remove(key);
    _emit(verifiedSession ? false : value.disconnected);
  }

  void _emit(bool disconnected) {
    final dates = _stale.values.toList()..sort();
    value = OfflineStatus(
      disconnected: disconnected,
      savedAt: dates.isEmpty ? null : dates.first,
    );
  }
}

class OfflineUnavailable implements Exception {
  const OfflineUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Repli strictement en lecture : seules les ressources personnelles listées
/// sont conservées. Un refus HTTP (401/403/404/5xx), une annulation ou une erreur
/// de certificat ne doit jamais être masqué par une ancienne autorisation.
class OfflineAccessInterceptor extends Interceptor {
  OfflineAccessInterceptor(
      {AuthSessionManager? sessions, OfflineAccess? access})
      : sessions = sessions ?? AuthSessionManager.instance,
        access = access ?? OfflineAccess.instance;

  final AuthSessionManager sessions;
  final OfflineAccess access;
  static const profileKey = '/auth/me';
  static const onlineOnly = 'offlineForceNetwork';

  static String cacheKey(RequestOptions options) => options.uri.toString();
  String _key(RequestOptions options) =>
      options.path == profileKey ? profileKey : cacheKey(options);

  // Liste fermée : seules les lectures personnelles déjà autorisées par le
  // serveur sont conservées. Les paramètres (page, filtres) font partie de la
  // clé ; les actions, codes de livraison et données administratives restent
  // exclus. Chaque réponse garde sa date afin de signaler les soldes anciens.
  static const _personalReads = {
    profileKey,
    '/client/parcels/my-parcels',
    '/driver/parcels',
    '/users/stats',
    '/client/bids/stats',
    '/client/bids/received',
    '/client/debts',
    '/driver/stats',
    '/driver/bids/sent',
    '/driver/proposals',
    '/driver/vehicle',
    '/driver/wallet',
    '/driver/cash-declarations',
    '/payments/history',
    '/score/balance',
    '/score/history',
    '/notifications',
    '/notifications/unread-count',
    '/notifications/preferences',
    '/addresses',
    '/favorites/zones',
    '/advertisements/my',
  };

  bool _eligible(RequestOptions options) {
    if (options.method != 'GET') return false;
    return _personalReads.contains(options.path) ||
        RegExp(r'^/(client|driver)/parcels/[^/]+$').hasMatch(options.path) ||
        RegExp(r'^/parcels/[^/]+/timeline$').hasMatch(options.path);
  }

  bool _transportFailure(DioException error) =>
      error.response == null &&
      {
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      }.contains(error.type);

  Future<Response<dynamic>?> _cached(RequestOptions options) async {
    final session = options.extra['authSession'] as SessionTokens?;
    if (!_eligible(options) || session == null) return null;
    final entry =
        await sessions.readCachedResponse(session.generation, _key(options));
    if (entry == null) return null;
    access.cached(_key(options), DateTime.parse(entry['savedAt'] as String));
    return Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      data: entry['data'],
      extra: {'offlineCache': true},
    );
  }

  DioException _unavailable(RequestOptions options) => DioException(
        requestOptions: options,
        error: OfflineUnavailable(options.method == 'GET'
            ? 'Ces informations ne sont pas disponibles hors ligne. Connectez-vous pour les charger.'
            : 'Cette action nécessite Internet. Aucune modification n’a été envoyée.'),
      );

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final session = options.extra['authSession'] as SessionTokens?;
      if (session != null) {
        access.useSession(session.generation);
        if (access.value.disconnected && options.extra[onlineOnly] != true) {
          final response = await _cached(options);
          if (response != null) {
            handler.resolve(response);
          } else {
            handler.reject(_unavailable(options));
          }
          return;
        }
        if (_eligible(options)) {
          options.connectTimeout = const Duration(seconds: 6);
          options.receiveTimeout = const Duration(seconds: 6);
        }
      }
      handler.next(options);
    } catch (error, stack) {
      debugPrint('[Offline] Préparation impossible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      handler.reject(_unavailable(options));
    }
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) async {
    try {
      final options = response.requestOptions;
      final session = options.extra['authSession'] as SessionTokens?;
      if (session != null &&
          (await sessions.read())?.generation != session.generation) {
        throw SessionChangedException();
      }
      if (session != null && {401, 403, 404}.contains(response.statusCode)) {
        await sessions.discardCachedResponse(session.generation, _key(options));
      }
      if (session != null &&
          response.extra['offlineCache'] != true &&
          response.statusCode == 200 &&
          response.data is Map &&
          response.data['success'] != false) {
        final isProfile = options.path == profileKey;
        final user = response.data['user'];
        final canCacheProfile = user is Map &&
            {'client', 'driver'}.contains(user['role']) &&
            user['id'] != null &&
            (user['status'] == null || user['status'] == 'active');
        if (_eligible(options) && (!isProfile || canCacheProfile)) {
          await sessions.saveCachedResponse(
              session.generation, _key(options), response.data);
        } else if (isProfile) {
          await sessions.discardCachedResponse(
              session.generation, _key(options));
        }
        access.fresh(_key(options), verifiedSession: isProfile && user is Map);
      }
      handler.next(response);
    } catch (error, stack) {
      debugPrint('[Offline] Réponse impossible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      handler.reject(DioException(
          requestOptions: response.requestOptions,
          error: error,
          stackTrace: stack));
    }
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) async {
    try {
      final options = error.requestOptions;
      final session = options.extra['authSession'] as SessionTokens?;
      if (session != null && {401, 403, 404}.contains(error.response?.statusCode)) {
        await sessions.discardCachedResponse(session.generation, _key(options));
      }
      if (_transportFailure(error) &&
          session != null &&
          (await sessions.read())?.generation == session.generation) {
        access.failed();
        if (options.extra[onlineOnly] != true) {
          final response = await _cached(options);
          if (response != null) {
            handler.resolve(response);
            return;
          }
        }
        handler.next(_unavailable(options));
        return;
      }
    } catch (failure, stack) {
      debugPrint('[Offline] Repli impossible (${failure.runtimeType})');
      debugPrintStack(stackTrace: stack);
    }
    handler.next(error);
  }
}
