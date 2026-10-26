import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api/client.dart';

final googleAuthServiceProvider = Provider((ref) => GoogleAuthService());

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message, [this.code]);
  final String message;
  final String? code;
}

class GoogleAuthService {
  GoogleAuthService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  static Future<void>? _initialization;
  static String? _initializedClient;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<Map<String, dynamic>> configuration() =>
      _request('/auth/google/config');

  Future<Map<String, dynamic>?> signIn() async {
    if (!supported)
      throw const GoogleAuthException(
          'La connexion Google sera bientôt disponible sur cet appareil.');
    final config = await configuration();
    final clientId = config['serverClientId'] as String?;
    if (config['enabled'] != true || clientId == null) {
      throw const GoogleAuthException(
          'La connexion Google est momentanément indisponible. Utilisez votre email et votre PIN.');
    }
    try {
      // Le client OAuth est public. Le serveur est la source de configuration
      // et vérifie lui-même les jetons ; aucune clé secrète n'entre dans l'app.
      if (_initializedClient != null && _initializedClient != clientId) {
        throw const GoogleAuthException(
            'Fermez puis rouvrez l’application pour réessayer.');
      }
      _initializedClient = clientId;
      try {
        await (_initialization ??=
            GoogleSignIn.instance.initialize(serverClientId: clientId));
      } catch (_) {
        _initialization = null;
        _initializedClient = null;
        rethrow;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null)
        throw const GoogleAuthException(
            'Connexion Google impossible. Veuillez réessayer.');
      return _request('/auth/google', {'idToken': token});
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('[GoogleAuth] SDK : ${error.code.name}');
      throw const GoogleAuthException(
          'Connexion Google impossible. Réessayez ou utilisez votre PIN.');
    }
  }

  Future<Map<String, dynamic>> link(
          String challenge, String identifier, String pin) =>
      _request('/auth/google/link',
          {'challengeToken': challenge, 'identifier': identifier, 'pin': pin});

  Future<Map<String, dynamic>> sendOtp(String challenge, String phone) =>
      _request('/auth/google/phone-otp',
          {'challengeToken': challenge, 'phone': phone});

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) =>
      _request('/auth/google/register', data);

  Future<Map<String, dynamic>> _request(String path,
      [Map<String, dynamic>? data]) async {
    try {
      final response = data == null
          ? await _client.dio.get<dynamic>(path)
          : await _client.dio.post<dynamic>(path, data: data);
      final body = _client.handle(response);
      if ((response.statusCode ?? 500) >= 400 || body['success'] != true)
        throw _failure(body);
      return body;
    } on GoogleAuthException {
      rethrow;
    } on DioException catch (error) {
      // Dio peut contenir le corps de la requête : ne jamais journaliser
      // l'exception complète avec son PIN, son OTP ou son jeton Google.
      debugPrint('[GoogleAuth] Réseau : ${error.type.name}');
      if (error.response?.data is Map)
        throw _failure(Map<String, dynamic>.from(error.response!.data));
      throw const GoogleAuthException(
          'Serveur injoignable. Vérifiez votre connexion et réessayez.');
    }
  }

  GoogleAuthException _failure(Map<String, dynamic> body) {
    final error = body['error'];
    return GoogleAuthException(
        body['message']?.toString() ??
            'Connexion impossible. Veuillez réessayer.',
        error is Map ? error['code']?.toString() : null);
  }
}
