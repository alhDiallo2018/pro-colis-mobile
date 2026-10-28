import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

class SessionExpiredException implements Exception {}

class SessionChangedException implements Exception {}

class SessionTokens {
  const SessionTokens(this.accessToken, this.refreshToken, this.generation);
  final String accessToken;
  final String? refreshToken;
  final String generation;

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'generation': generation,
      };
}

/// Coordinateur unique partage par TOUS les clients HTTP de l'application.
/// Un seul enregistrement securise contient le couple de jetons : un arret du
/// processus entre deux ecritures ne peut plus produire un couple incoherent.
class AuthSessionManager {
  AuthSessionManager({FlutterSecureStorage? storage, Dio? refreshDio})
      : _storage = storage ?? const FlutterSecureStorage(),
        _refreshDio = refreshDio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (status) => status != null && status < 500,
            ));

  static final instance = AuthSessionManager();
  static const storageKey = 'auth_session_v2';
  static const offlineCacheKey = 'offline_responses_v1';
  final FlutterSecureStorage _storage;
  final Dio _refreshDio;
  VoidCallback? onExpired;
  Future<void> _writes = Future<void>.value();
  Future<SessionTokens>? _refreshFlight;
  String? _refreshGeneration;

  String _newGeneration() => base64Url
      .encode(List<int>.generate(18, (_) => Random.secure().nextInt(256)));

  // Cette file ne couvre que le stockage, jamais le reseau. Un logout peut
  // donc invalider immediatement une requete de refresh encore en vol.
  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  // Le timeout doit etre DANS la file : sinon une lecture Keystore bloquee
  // retiendrait toutes les requetes suivantes meme apres leur propre timeout.
  Future<String?> _readValue(String key) =>
      _storage.read(key: key).timeout(const Duration(seconds: 5));

  Future<SessionTokens?> _read() async {
    final raw = await _readValue(storageKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['accessToken'] == null) return null;
      return SessionTokens(data['accessToken'] as String,
          data['refreshToken'] as String?, data['generation'] as String);
    }
    // Migration paresseuse des installations existantes. Le marqueur vide
    // ecrit au logout empeche de ressusciter d'anciennes cles residuelles.
    final access = await _readValue('token');
    if (access == null || access.isEmpty) return null;
    final session = SessionTokens(
        access, await _readValue('refresh_token'), _newGeneration());
    await _write(session);
    return session;
  }

  Future<void> _write(SessionTokens? session) async {
    await _storage.write(
        key: storageKey, value: jsonEncode(session?.toJson() ?? {}));
    // Nettoyage de compatibilite apres la sauvegarde atomique faisant autorite.
    try {
      await _storage.delete(key: 'token');
      await _storage.delete(key: 'refresh_token');
    } catch (error) {
      debugPrint(
          '[Session] Nettoyage des anciennes cles indisponible (${error.runtimeType})');
    }
  }

  Future<SessionTokens?> read() => _serialized(_read);
  Future<String?> accessToken() async => (await read())?.accessToken;

  /// Le cache et les jetons partagent la même file : un logout ou un changement
  /// de compte ne peut pas être suivi d'une écriture issue de l'ancienne session.
  /// Le contenu reste dans le Keystore/Keychain, jamais dans les préférences.
  Future<Map<String, dynamic>?> readCachedResponse(
          String generation, String key) =>
      _serialized(() async {
        try {
          if ((await _read())?.generation != generation) return null;
          final raw = await _readValue(offlineCacheKey);
          if (raw == null) return null;
          final cache = jsonDecode(raw) as Map<String, dynamic>;
          if (cache['generation'] != generation) return null;
          final entry = (cache['entries'] as Map)[key];
          if (entry is! Map) return null;
          final savedAt = DateTime.parse(entry['savedAt'] as String);
          if (DateTime.now().difference(savedAt) > const Duration(days: 30)) {
            return null;
          }
          return Map<String, dynamic>.from(entry);
        } catch (error, stack) {
          debugPrint(
              '[OfflineCache] Lecture impossible (${error.runtimeType})');
          debugPrintStack(stackTrace: stack);
          return null;
        }
      });

  Future<void> saveCachedResponse(
          String generation, String key, dynamic data) =>
      _serialized(() async {
        try {
          if ((await _read())?.generation != generation) return;
          final raw = await _readValue(offlineCacheKey);
          final cache = raw == null
              ? <String, dynamic>{}
              : jsonDecode(raw) as Map<String, dynamic>;
          final entries = cache['generation'] == generation
              ? Map<String, dynamic>.from(cache['entries'] as Map)
              : <String, dynamic>{};
          entries.remove(key);
          entries[key] = {
            'savedAt': DateTime.now().toUtc().toIso8601String(),
            'data': _withoutSecrets(data),
          };
          // Borne le volume et évince les réponses les plus anciennes. Aucun
          // fichier média n'est téléchargé pour la consultation hors ligne.
          while (entries.length > 40 ||
              utf8.encode(jsonEncode(entries)).length > 2 * 1024 * 1024) {
            // Le profil permet de rouvrir la session : les pages d'historique
            // sont évincées en priorité pour ne pas le perdre en paginant.
            entries.remove(entries.keys.firstWhere((key) => key != '/auth/me',
                orElse: () => entries.keys.first));
          }
          await _storage.write(
            key: offlineCacheKey,
            value: jsonEncode({'generation': generation, 'entries': entries}),
          );
        } catch (error, stack) {
          // Le stockage local est un confort : son échec n'annule jamais une
          // réponse valide du serveur. Ne pas journaliser le corps ou le jeton.
          debugPrint(
              '[OfflineCache] Écriture impossible (${error.runtimeType})');
          debugPrintStack(stackTrace: stack);
        }
      });

  static dynamic _withoutSecrets(dynamic value) {
    if (value is List) return value.map(_withoutSecrets).toList();
    if (value is! Map) return value;
    return <String, dynamic>{
      for (final entry in value.entries)
        if (!RegExp(
                r'pin|password|token|otp|deliverycode|verificationcode|secret',
                caseSensitive: false)
            .hasMatch(entry.key.toString().replaceAll('_', '')))
          entry.key.toString(): _withoutSecrets(entry.value),
    };
  }

  Future<void> _clearOfflineCache() async {
    try {
      await _storage.delete(key: offlineCacheKey);
    } catch (error, stack) {
      // La génération des jetons invalide également un cache non supprimable.
      debugPrint('[OfflineCache] Nettoyage impossible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
    }
  }

  /// Un refus explicite retire aussi l'ancienne copie, pour qu'une prochaine
  /// coupure ne réaffiche pas une ressource dont l'accès vient d'être retiré.
  Future<void> discardCachedResponse(String generation, String key) =>
      _serialized(() async {
        try {
          if ((await _read())?.generation != generation) return;
          final raw = await _readValue(offlineCacheKey);
          if (raw == null) return;
          final cache = jsonDecode(raw) as Map<String, dynamic>;
          if (cache['generation'] != generation) return;
          (cache['entries'] as Map).remove(key);
          await _storage.write(key: offlineCacheKey, value: jsonEncode(cache));
        } catch (error, stack) {
          debugPrint(
              '[OfflineCache] Retrait impossible (${error.runtimeType})');
          debugPrintStack(stackTrace: stack);
        }
      });

  Future<void> establish(Map<String, dynamic> data) => _serialized(() async {
        final access = data['accessToken']?.toString();
        final refresh = data['refreshToken']?.toString();
        if (access == null ||
            access.isEmpty ||
            refresh == null ||
            refresh.isEmpty) {
          throw const FormatException('Reponse de connexion incomplete');
        }
        final previous = await _read();
        final generation = _newGeneration();
        Map<String, dynamic>? retained;
        final nextUser = data['user'];
        if (previous != null && nextUser is Map && nextUser['id'] != null) {
          try {
            final raw = await _readValue(offlineCacheKey);
            final cache = raw == null ? null : jsonDecode(raw);
            final profile = cache?['entries']?['/auth/me']?['data']?['user'];
            // Une authentification serveur du même compte renouvelle les
            // jetons sans effacer les vrais colis déjà synchronisés. La nouvelle
            // génération interdit toujours aux anciennes requêtes d'écrire.
            if (cache?['generation'] == previous.generation &&
                profile is Map &&
                profile['id'] == nextUser['id'] &&
                profile['role'] == nextUser['role']) {
              retained = Map<String, dynamic>.from(cache);
              retained['generation'] = generation;
              retained['entries']['/auth/me'] = {
                'savedAt': DateTime.now().toUtc().toIso8601String(),
                'data': {'success': true, 'user': _withoutSecrets(nextUser)}
              };
            }
          } catch (error) {
            debugPrint(
                '[Session] Copie locale non transférable (${error.runtimeType})');
          }
        }
        await _write(SessionTokens(access, refresh, generation));
        if (retained != null) {
          try {
            await _storage.write(
                key: offlineCacheKey, value: jsonEncode(retained));
          } catch (error) {
            debugPrint(
                '[Session] Conservation locale impossible (${error.runtimeType})');
            await _clearOfflineCache();
          }
        } else {
          await _clearOfflineCache();
        }
      });

  Future<void> setAccessToken(String access) => _serialized(() async {
        final current = await _read();
        await _write(SessionTokens(access, current?.refreshToken,
            current?.generation ?? _newGeneration()));
      });

  Future<SessionTokens?> clear() => _serialized(() async {
        final previous = await _read();
        await _write(null);
        await _clearOfflineCache();
        return previous;
      });

  Future<bool> expire(SessionTokens expected) => _serialized(() async {
        final current = await _read();
        if (current?.generation != expected.generation ||
            current?.refreshToken != expected.refreshToken) return false;
        await _write(null);
        await _clearOfflineCache();
        onExpired?.call();
        return true;
      });

  Future<SessionTokens> refresh(SessionTokens failed) {
    if (_refreshFlight != null && _refreshGeneration == failed.generation)
      return _refreshFlight!;
    _refreshGeneration = failed.generation;
    late final Future<SessionTokens> flight;
    flight = _renew(failed).whenComplete(() {
      if (identical(_refreshFlight, flight)) {
        _refreshFlight = null;
        _refreshGeneration = null;
      }
    });
    _refreshFlight = flight;
    return flight;
  }

  Future<SessionTokens> _renew(SessionTokens failed) async {
    final start = await read();
    if (start == null || start.generation != failed.generation)
      throw SessionChangedException();
    // Un 401 tardif sur l'ancien access token reutilise le couple deja sauve.
    if (start.accessToken != failed.accessToken) return start;
    if (start.refreshToken == null || start.refreshToken!.isEmpty) {
      await expire(start);
      throw SessionExpiredException();
    }
    final response = await _refreshDio.post<dynamic>('/auth/refresh',
        data: {'refreshToken': start.refreshToken});
    if (response.statusCode == 401) {
      final cleared = await expire(start);
      if (!cleared) {
        final current = await read();
        if (current != null && current.generation == start.generation)
          return current;
        throw SessionChangedException();
      }
      throw SessionExpiredException();
    }
    if (response.statusCode != 200) {
      throw DioException.badResponse(
          statusCode: response.statusCode ?? 503,
          requestOptions: response.requestOptions,
          response: response);
    }
    final data = response.data;
    if (data is! Map ||
        data['accessToken'] is! String ||
        data['refreshToken'] is! String ||
        (data['accessToken'] as String).isEmpty ||
        (data['refreshToken'] as String).isEmpty) {
      throw const FormatException('Reponse de renouvellement incomplete');
    }
    return _serialized(() async {
      final current = await _read();
      if (current == null || current.generation != start.generation)
        throw SessionChangedException();
      if (current.refreshToken != start.refreshToken) return current;
      final next = SessionTokens(data['accessToken'] as String,
          data['refreshToken'] as String, start.generation);
      await _write(next);
      return next;
    });
  }
}

/// Meme comportement pour ApiService et les clients modulaires. Les erreurs
/// reseau/429/5xx remontent sans supprimer la session ni les brouillons.
class SessionAuthInterceptor extends Interceptor {
  SessionAuthInterceptor(this.dio, {AuthSessionManager? sessions})
      : sessions = sessions ?? AuthSessionManager.instance;
  final Dio dio;
  final AuthSessionManager sessions;
  static const _publicAuth = {
    '/auth/register',
    '/auth/google',
    '/auth/google/config',
    '/auth/google/link',
    '/auth/google/phone-otp',
    '/auth/google/register',
    '/auth/login',
    '/auth/login-with-pin',
    '/auth/refresh',
    '/auth/logout',
    '/auth/forgot-password',
    '/auth/reset-password',
    '/auth/send-otp',
    '/auth/verify-otp',
    '/auth/verify-email',
    '/auth/resend-verification',
  };
  bool _public(String path) =>
      _publicAuth.contains(path.split('?').first) ||
      path.startsWith('/public/') ||
      path == '/health';

  DioException _failure(
          Object error, StackTrace stack, RequestOptions options) =>
      error is DioException
          // Un refresh hors ligne doit conserver le contexte de la lecture
          // initiale, afin que son cache puisse servir malgré un access expiré.
          ? (error.response == null && error.requestOptions != options
              ? DioException(
                  requestOptions: options,
                  type: error.type,
                  error: error.error,
                  stackTrace: stack)
              : error)
          : DioException(
              requestOptions: options, error: error, stackTrace: stack);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      if (!_public(options.path)) {
        final session = await sessions.read();
        final previous = options.extra['authSession'] as SessionTokens?;
        // Un envoi GPS est lié au compte de son acquisition, sans être
        // considéré comme déjà renouvelé : un 401 peut encore rafraîchir le JWT.
        if ((options.extra['sessionRetried'] == true ||
                options.extra['authSessionPinned'] == true) &&
            previous?.generation != session?.generation) {
          throw SessionChangedException();
        }
        options.extra['authSession'] = session;
        if (session != null)
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
      handler.next(options);
    } catch (error, stack) {
      // Un Keystore temporairement indisponible n'est pas un refus serveur.
      handler.reject(_failure(error, stack, options));
    }
  }

  Future<Response<dynamic>> _recover(Response<dynamic> response) async {
    final options = response.requestOptions;
    final failed = options.extra['authSession'] as SessionTokens?;
    if (response.statusCode != 401 || _public(options.path) || failed == null)
      return response;
    if (options.extra['sessionRetried'] == true) {
      if (!await sessions.expire(failed)) throw SessionChangedException();
      throw SessionExpiredException();
    }
    final next = await sessions.refresh(failed);
    final current = await sessions.read();
    if (current?.generation != next.generation) throw SessionChangedException();
    options.extra['sessionRetried'] = true;
    options.headers['Authorization'] = 'Bearer ${next.accessToken}';
    return dio.fetch<dynamic>(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) async {
    try {
      // Laisse les intercepteurs de lecture enregistrer la réponse vérifiée.
      handler.next(await _recover(response));
    } catch (error, stack) {
      handler.reject(_failure(error, stack, response.requestOptions), true);
    }
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) async {
    if (error.response?.statusCode != 401) {
      handler.next(error);
      return;
    }
    try {
      handler.resolve(await _recover(error.response!));
    } catch (failure, stack) {
      handler.next(_failure(failure, stack, error.requestOptions));
    }
  }
}
