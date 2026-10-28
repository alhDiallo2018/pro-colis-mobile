import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  GoogleAuthService(
      {ApiClient? client,
      Future<Map<String, dynamic>> Function()? nativeConfiguration,
      Future<String?> Function(String serverClientId, String? clientId)?
          authenticate})
      : _client = client ?? ApiClient(),
        _nativeConfiguration = nativeConfiguration ?? _readNativeConfiguration,
        _authenticate = authenticate ?? _authenticateNative;
  final Future<Map<String, dynamic>> Function() _nativeConfiguration;
  final Future<String?> Function(String, String?) _authenticate;
  static const _nativeChannel =
      MethodChannel('sendprocolis/google-auth-config');
  static Future<Map<String, dynamic>> _readNativeConfiguration() async =>
      Map<String, dynamic>.from(
          await _nativeChannel.invokeMapMethod<String, dynamic>('read') ?? {});
  final ApiClient _client;
  static Future<void>? _initialization;
  static String? _initializedClient;

  bool get supported =>
      !kIsWeb &&
      {TargetPlatform.android, TargetPlatform.iOS}
          .contains(defaultTargetPlatform);

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
      String? nativeClientId;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final native = await _nativeConfiguration();
        nativeClientId = native['clientId'] as String?;
        if (nativeClientId == null ||
            nativeClientId.isEmpty ||
            native['urlSchemeConfigured'] != true) {
          throw const GoogleAuthException(
              'Google n’est pas encore configuré pour cette version iPhone. Utilisez votre PIN ou le déverrouillage local.',
              'GOOGLE_IOS_NOT_CONFIGURED');
        }
      }
      final token = await _authenticate(clientId, nativeClientId);
      if (token == null || token.isEmpty) {
        throw const GoogleAuthException(
            'Google n’a pas retourné de preuve de connexion. Réessayez.',
            'GOOGLE_TOKEN_MISSING');
      }
      return _request('/auth/google', {'idToken': token});
    } on GoogleSignInException catch (error) {
      debugPrint('[GoogleAuth] SDK : ${error.code.name}');
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw GoogleAuthException(
            'La configuration Google de cette version de l’application est incomplète. Utilisez votre PIN en attendant sa correction.',
            error.code.name);
      }
      throw GoogleAuthException(
          'Connexion Google impossible. Vérifiez Internet puis réessayez, ou utilisez votre PIN.',
          error.code.name);
    } on PlatformException catch (error) {
      debugPrint('[GoogleAuth] Configuration native : ${error.code}');
      throw const GoogleAuthException(
          'Configuration Google indisponible sur cet appareil. Utilisez votre PIN.',
          'GOOGLE_NATIVE_CONFIGURATION');
    }
  }

  static Future<String?> _authenticateNative(
      String serverClientId, String? clientId) async {
    // L'identifiant Web est l'audience vérifiée par notre API ; l'identifiant
    // iOS désigne l'application native et son schéma de retour enregistré.
    final identity = '$serverClientId:${clientId ?? ''}';
    if (_initializedClient != null && _initializedClient != identity) {
      throw const GoogleAuthException(
          'Fermez puis rouvrez l’application pour réessayer.');
    }
    _initializedClient = identity;
    try {
      await (_initialization ??= GoogleSignIn.instance
          .initialize(serverClientId: serverClientId, clientId: clientId));
    } catch (_) {
      _initialization = null;
      _initializedClient = null;
      rethrow;
    }
    final account = await GoogleSignIn.instance.authenticate();
    return account.authentication.idToken;
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
