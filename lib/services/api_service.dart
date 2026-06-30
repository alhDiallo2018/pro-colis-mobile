// mobile/lib/services/api_service.dart
// ignore_for_file: unused_import, deprecated_member_use, avoid_print, empty_catches, curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/garage.dart';
import '../models/parcel.dart';
import '../models/user.dart';
import 'mock_data.dart';

class ApiService {
  // Pour Android Emulator
  // static const String baseUrl = 'http://10.0.2.2:8080';
  // L'URL API est configurable au build web via --dart-define=API_BASE_URL=...
  // Cela permet d'utiliser Docker, staging ou production sans modifier le code source.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  // Pour site  (render)
  // static const String baseUrl = 'https://procolis-backend.onrender.com';

  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();

  static const bool isMockMode = MockData.enabled;

  // Liste des routes publiques qui ne nécessitent pas de token
  static const Set<String> _publicRoutes = {
    '/auth/register',
    '/auth/send-otp',
    '/auth/verify-otp',
    '/auth/login',
    '/auth/login-with-pin',
    '/auth/refresh',
    '/auth/forgot-password',
    '/auth/reset-password',
    '/auth/verify-email',
    '/auth/resend-verification',
    '/public/',
    '/health',
  };

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.headers['Content-Type'] = 'application/json';
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.validateStatus = (status) => status! < 500;

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final isPublic = _isPublicRoute(options.path);

        if (isPublic) {
          debugPrint('🔓 [PUBLIC] ${options.method} ${options.path}');
          return handler.next(options);
        }

        final token = await _storage.read(key: 'token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
          debugPrint(
              '🔐 [PROTECTED] ${options.method} ${options.path} - Token ajouté');
        } else {
          debugPrint('⚠️ [NO TOKEN] ${options.method} ${options.path}');
        }

        return handler.next(options);
      },
      onResponse: (response, handler) async {
        debugPrint(
            '✅ [${response.statusCode}] ${response.requestOptions.method} ${response.requestOptions.path}');
        if (response.statusCode == 401 &&
            !_isPublicRoute(response.requestOptions.path) &&
            response.requestOptions.extra['retriedAfterRefresh'] != true) {
          final refreshedToken = await _refreshAccessToken();

          if (refreshedToken != null && refreshedToken.isNotEmpty) {
            final retryOptions = response.requestOptions;
            retryOptions.extra['retriedAfterRefresh'] = true;
            retryOptions.headers['Authorization'] = 'Bearer $refreshedToken';

            debugPrint(
                '🔁 Token renouvelé, nouvelle tentative ${retryOptions.method} ${retryOptions.path}');
            final retryResponse =
                await _retryRequestWithToken(retryOptions, refreshedToken);
            return handler.resolve(retryResponse);
          }

          debugPrint('🔐 Session invalide, nettoyage du token local...');
          await clearToken();
        }

        return handler.next(response);
      },
      onError: (DioError error, handler) async {
        final statusCode = error.response?.statusCode;
        final path = error.requestOptions.path;

        debugPrint('❌ [ERROR] $statusCode - $path');
        debugPrint('   Message: ${error.message}');

        if (statusCode == 401 && !_isPublicRoute(path)) {
          debugPrint('🔐 Token invalide/expiré, nettoyage...');
          await clearToken();
        }

        return handler.next(error);
      },
    ));
  }

  bool _isPublicRoute(String path) {
    return _publicRoutes.any((route) => path.contains(route));
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      // Le refresh utilise un client Dio séparé pour éviter de repasser dans
      // l'intercepteur courant et de créer une boucle sur les erreurs 401.
      final refreshDio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) => status != null && status < 500,
      ));

      final response = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final responseData = response.data ?? {};

      if (response.statusCode == 200 && responseData['success'] == true) {
        await _storeAuthTokens(responseData);
        return responseData['accessToken']?.toString();
      }

      debugPrint(
          '❌ Refresh token refusé: ${responseData['message'] ?? response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ Erreur refresh token: $e');
      return null;
    }
  }

  Future<Response<dynamic>> _retryRequestWithToken(
    RequestOptions requestOptions,
    String accessToken,
  ) async {
    // Le retry ne doit pas utiliser `_dio.fetch` depuis l'intercepteur queue,
    // sinon la requête peut attendre la fin de l'intercepteur qui l'attend elle-même.
    final retryDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 500,
    ));

    requestOptions.headers['Authorization'] = 'Bearer $accessToken';
    return retryDio.fetch<dynamic>(requestOptions);
  }

  Future<String?> getToken() async => await _storage.read(key: 'token');

  Future<void> setToken(String token) async {
    debugPrint(
        '🔐 Token stocké: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
    await _storage.write(key: 'token', value: token);
  }

  Future<void> clearToken() async {
    debugPrint('🔐 Token effacé');
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'mock_user_id');
  }

  Future<void> _storeAuthTokens(Map<String, dynamic> responseData) async {
    // Les tokens renvoyes par l'API alimentent l'intercepteur Dio pour les routes protegees.
    final accessToken = responseData['accessToken']?.toString();
    final refreshToken = responseData['refreshToken']?.toString();

    if (accessToken != null && accessToken.isNotEmpty) {
      await setToken(accessToken);
    }

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: 'refresh_token', value: refreshToken);
    }
  }

  Map<String, dynamic> _handleResponse(Response response) {
    if (response.data is String) {
      return jsonDecode(response.data as String);
    }
    return response.data as Map<String, dynamic>;
  }

  String _getContentType(String path) {
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  // ==================== MÉTHODES D'AUTHENTIFICATION ====================

  Future<Map<String, dynamic>> register({
    required String email,
    required String phone,
    required String fullName,
    required String password,
    String role = 'client',
    String? address,
    String? city,
    String? region,
    String? vehiclePlate,
    String? vehicleModel,
    String? vehicleColor,
    int? vehicleYear,
    String? garageId,
  }) async {
    try {
      print('📤 Envoi requête register: email=$email, phone=$phone');

      final response = await _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'phone': phone,
          'fullName': fullName,
          'password': password,
          'role': role,
          'address': address,
          'city': city,
          'region': region,
          'vehiclePlate': vehiclePlate,
          'vehicleModel': vehicleModel,
          'vehicleColor': vehicleColor,
          'vehicleYear': vehicleYear,
          'garageId': garageId,
        },
      );

      print('✅ Réponse reçue: ${response.statusCode}');
      print('📦 Type de réponse: ${response.data.runtimeType}');

      Map<String, dynamic> responseData;

      if (response.data is String) {
        responseData = jsonDecode(response.data);
        print('🔄 Réponse convertie depuis String');
      } else if (response.data is Map) {
        responseData = Map<String, dynamic>.from(response.data);
        print('✅ Réponse déjà en Map');
      } else {
        throw Exception(
            'Format de réponse inattendu: ${response.data.runtimeType}');
      }

      print('📊 Réponse parsée: $responseData');

      if (responseData['success'] == true && responseData['userId'] != null) {
        print('✅ Inscription réussie pour userId: ${responseData['userId']}');
      }

      return responseData;
    } catch (e) {
      print('❌ Erreur register: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendOtp(String identifier) async {
    try {
      if (isMockMode) {
        final user = MockData.findUserByIdentifier(identifier);
        return {
          'success': user != null,
          'userId': user?.id,
          'message': user != null
              ? 'Code OTP mock envoyé. Utilisez 123456.'
              : 'Compte mock introuvable',
        };
      }

      debugPrint('📤 Envoi OTP pour: $identifier');
      final response =
          await _dio.post('/auth/send-otp', data: {'identifier': identifier});
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur sendOtp: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(
      String userId, String code, String type) async {
    try {
      if (isMockMode) {
        if (code != MockData.pin) {
          return {'success': false, 'message': 'Code OTP mock incorrect'};
        }
        final user = MockData.userById(userId);
        await setToken('mock-token-${user.id}');
        await _storage.write(key: 'mock_user_id', value: user.id);
        return MockData.loginPayload(user);
      }

      final response = await _dio.post('/auth/verify-otp', data: {
        'userId': userId,
        'code': code,
        'type': type,
      });
      final responseData = _handleResponse(response);
      if (responseData['success'] == true &&
          responseData['accessToken'] != null) {
        await _storeAuthTokens(responseData);
      }
      return responseData;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> logout() async {
    await clearToken();
  }

  Future<Map<String, dynamic>> loginWithPin(
      String pin, String identifier) async {
    try {
      debugPrint('📤 [loginWithPin] Tentative pour: $identifier');
      if (isMockMode) {
        final user = MockData.findUserByIdentifier(identifier);
        if (user == null || pin != MockData.pin) {
          return {
            'success': false,
            'message': 'Compte mock ou PIN incorrect. PIN: ${MockData.pin}',
          };
        }

        // Le mock conserve un token et l'id utilisateur pour restaurer la session au redémarrage.
        await setToken('mock-token-${user.id}');
        await _storage.write(key: 'mock_user_id', value: user.id);
        debugPrint('✅ [MOCK_LOGIN] ${user.fullName} connecté');
        return MockData.loginPayload(user);
      }

      final response = await _dio.post('/auth/login', data: {
        'identifier': identifier,
        'pin': pin,
      });
      final responseData = _handleResponse(response);
      if (responseData['success'] == true &&
          responseData['accessToken'] != null) {
        await _storeAuthTokens(responseData);
        debugPrint('✅ [loginWithPin] Connexion réussie');
      }
      return responseData;
    } catch (e) {
      debugPrint('❌ [loginWithPin] Erreur: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== AUTHENTIFICATION AVANCÉE ====================

  Future<Map<String, dynamic>> refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) {
        return {'success': false, 'message': 'No refresh token'};
      }
      final response = await _dio.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });
      final responseData = _handleResponse(response);
      if (responseData['success'] == true &&
          responseData['accessToken'] != null) {
        await setToken(responseData['accessToken']);
        if (responseData['refreshToken'] != null) {
          await _storage.write(
              key: 'refresh_token', value: responseData['refreshToken']);
        }
      }
      return responseData;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response =
          await _dio.post('/auth/forgot-password', data: {'email': email});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetPassword(
      {required String token, required String newPassword}) async {
    try {
      final response = await _dio.post('/auth/reset-password', data: {
        'token': token,
        'newPassword': newPassword,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changePassword(
      {required String currentPassword, required String newPassword}) async {
    try {
      final response = await _dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyEmail(String otpCode) async {
    try {
      final response =
          await _dio.post('/auth/verify-email', data: {'otpCode': otpCode});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resendVerificationEmail() async {
    try {
      final response = await _dio.post('/auth/resend-verification');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== MÉTHODES UTILISATEUR ====================

  Future<User> getCurrentUser() async {
    try {
      if (isMockMode) {
        final userId = await _storage.read(key: 'mock_user_id');
        if (userId == null || userId.isEmpty) {
          throw Exception('Aucun utilisateur mock connecté');
        }
        return MockData.userById(userId);
      }

      final response = await _dio.get('/auth/me');
      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['user'] != null) {
        return User.fromJson(responseData['user']);
      }
      throw Exception('Utilisateur non trouvé');
    } catch (e) {
      debugPrint('❌ Erreur getCurrentUser: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String email,
    required String phone,
    String? address,
    String? city,
    String? region,
    String? vehiclePlate,
    String? vehicleModel,
    String? vehicleColor,
    int? vehicleYear,
  }) async {
    try {
      final currentUser = await getCurrentUser();
      final role = currentUser.role;
      String endpoint;
      switch (role) {
        case UserRole.client:
          endpoint = '/client/profile';
          break;
        case UserRole.driver:
          endpoint = '/driver/profile';
          break;
        case UserRole.admin:
          endpoint = '/garage-admin/profile';
          break;
        case UserRole.superAdmin:
          endpoint = '/super-admin/profile';
          break;
      }
      final response = await _dio.put(endpoint, data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'region': region,
        'vehiclePlate': vehiclePlate,
        'vehicleModel': vehicleModel,
        'vehicleColor': vehicleColor,
        'vehicleYear': vehicleYear,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updatePin(
      String currentPin, String newPin) async {
    try {
      final response = await _dio.put('/users/pin', data: {
        'currentPin': currentPin,
        'newPin': newPin,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateProfileByRole(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur updateProfileByRole: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final response = await _dio.delete('/users/account',
          options: Options(headers: {'Content-Type': 'application/json'}));
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur deleteAccount: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final response = await _dio.get('/users/stats',
          options: Options(headers: {'Content-Type': 'application/json'}));
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur getUserStats: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== MÉTHODES PARCELS ====================

  Future<List<Parcel>> getMyParcels({String? status}) async {
    try {
      if (isMockMode) {
        final user = await getCurrentUser();
        final parcels = MockData.parcelsForUser(user);
        if (status == null || status.isEmpty) return parcels;
        return parcels
            .where((parcel) => parcel.status.value == status)
            .toList();
      }

      final queryParams =
          status != null ? {'status': status} : <String, dynamic>{};
      final response = await _dio.get('/client/parcels/my-parcels',
          queryParameters: queryParams);
      final responseData = _handleResponse(response);
      final List<dynamic> parcelsData = responseData['parcels'] ?? [];
      return parcelsData
          .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getMyParcels: $e');
      return [];
    }
  }

  Future<List<Parcel>> getDriverParcels() async {
    try {
      if (isMockMode) {
        final user = await getCurrentUser();
        return MockData.parcelsForUser(user)
            .where((parcel) => parcel.driverId == user.id)
            .toList();
      }

      final response = await _dio.get('/driver/parcels');
      final responseData = _handleResponse(response);
      final List<dynamic> parcelsData = responseData['parcels'] ?? [];
      return parcelsData
          .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getDriverParcels: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> confirmPickup(String parcelId) async {
    try {
      final response = await _dio.put('/driver/parcels/$parcelId/pickup');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> markAsInTransit(String parcelId,
      {String? location}) async {
    try {
      final response = await _dio.put('/driver/parcels/$parcelId/transit',
          data: location != null ? {'location': location} : null);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> markAsArrived(String parcelId,
      {String? location}) async {
    try {
      final response = await _dio.put('/driver/parcels/$parcelId/arrived',
          data: location != null ? {'location': location} : null);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> markAsOutForDelivery(String parcelId,
      {String? location}) async {
    try {
      final response = await _dio.put(
          '/driver/parcels/$parcelId/out-for-delivery',
          data: location != null ? {'location': location} : null);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> confirmDelivery(String parcelId,
      {String? signature, String? photoUrl}) async {
    try {
      final response =
          await _dio.put('/driver/parcels/$parcelId/deliver', data: {
        'signature': signature,
        'photoUrl': photoUrl,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<String?> uploadParcelPhoto(XFile file, String parcelId) async {
    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final response = await _dio.post('/upload/parcel-photo', data: {
        'file': base64Image,
        'parcelId': parcelId,
        'filename': file.name,
      });
      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['url'] != null) {
        return responseData['url'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur uploadParcelPhoto: $e');
      return null;
    }
  }

  Future<String?> uploadParcelVideo(XFile file, String parcelId) async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) {
        debugPrint('❌ Aucun token trouvé');
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64Video = base64Encode(bytes);

      final response = await _dio.post(
        '/upload/parcel-video',
        data: {
          'file': base64Video,
          'parcelId': parcelId,
          'filename': file.name,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      debugPrint('📹 Statut: ${response.statusCode}');
      debugPrint('📹 Réponse: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> responseData;
        if (response.data is Map) {
          responseData = response.data as Map<String, dynamic>;
        } else if (response.data is String) {
          responseData = jsonDecode(response.data);
        } else {
          debugPrint(
              '❌ Format de réponse inattendu: ${response.data.runtimeType}');
          return null;
        }

        final dynamic urlValue = responseData['url'];
        if (urlValue != null) {
          final String videoUrl = urlValue.toString();
          if (videoUrl.isNotEmpty && videoUrl.startsWith('http')) {
            debugPrint('✅ Vidéo uploadée: $videoUrl');
            return videoUrl;
          }
        }

        debugPrint('⚠️ Aucune URL valide trouvée dans la réponse');
      }

      return null;
    } catch (e) {
      debugPrint('❌ Erreur uploadParcelVideo: $e');
      return null;
    }
  }

  // ✅ Upload d'un message vocal
  Future<String?> uploadAudio(XFile audio, String parcelId) async {
    try {
      debugPrint('🎤 Upload du message vocal pour le colis $parcelId');
      final bytes = await audio.readAsBytes();
      final base64Audio = base64Encode(bytes);

      final response = await _dio.post('/upload/parcel-audio', data: {
        'file': base64Audio,
        'parcelId': parcelId,
        'filename': audio.name,
      });

      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['url'] != null) {
        debugPrint('✅ Message vocal uploadé: ${responseData['url']}');
        return responseData['url'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur uploadAudio: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateParcelMedia(
      String parcelId, Map<String, dynamic> mediaData) async {
    try {
      final token = await _storage.read(key: 'token');

      if (token == null) {
        debugPrint('❌ Aucun token pour mise à jour média');
        return {'success': false, 'message': 'Token manquant'};
      }

      final currentUser = await getCurrentUser();
      final role = currentUser.role;

      debugPrint('📝 Mise à jour des médias du colis $parcelId');
      debugPrint('   Rôle: ${role.name}');
      debugPrint('   Photos: ${mediaData['photoUrls']}');
      debugPrint('   Vidéos: ${mediaData['videoUrls']}');
      debugPrint('   Audios: ${mediaData['audioUrls']}');

      String endpoint;
      switch (role) {
        case UserRole.client:
          endpoint = '/client/parcels/$parcelId/media';
          break;
        case UserRole.driver:
          endpoint = '/driver/parcels/$parcelId/media';
          break;
        case UserRole.admin:
          endpoint = '/garage-admin/parcels/$parcelId/media';
          break;
        case UserRole.superAdmin:
          endpoint = '/super-admin/parcels/$parcelId/media';
          break;
      }

      try {
        final response = await _dio.patch(
          endpoint,
          data: mediaData,
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ),
        );
        debugPrint('✅ Mise à jour média (PATCH): ${response.statusCode}');
        return _handleResponse(response);
      } catch (patchError) {
        debugPrint('⚠️ PATCH échoué, tentative avec POST sur $endpoint');

        final response = await _dio.post(
          endpoint,
          data: mediaData,
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ),
        );
        debugPrint('✅ Mise à jour média (POST): ${response.statusCode}');
        return _handleResponse(response);
      }
    } catch (e) {
      debugPrint('❌ Erreur updateParcelMedia: $e');

      if (e.toString().contains('404') || e.toString().contains('403')) {
        debugPrint(
            '⚠️ Endpoint non disponible ou accès refusé, mais les médias sont déjà uploadés');
        return {'success': true, 'message': 'Médias déjà uploadés'};
      }

      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Parcel> createParcelByDriver(Map<String, dynamic> data) async {
    try {
      String? paymentMethodValue;
      if (data['paymentMethod'] != null) {
        if (data['paymentMethod'] is String) {
          paymentMethodValue = data['paymentMethod'];
        } else if (data['paymentMethod'].value != null) {
          paymentMethodValue = data['paymentMethod'].value;
        } else {
          paymentMethodValue = data['paymentMethod'].toString();
        }
      }

      final cleanedData = <String, dynamic>{
        'senderName': data['senderName'],
        'senderPhone': data['senderPhone'],
        'senderEmail': data['senderEmail'],
        'receiverName': data['receiverName'],
        'receiverPhone': data['receiverPhone'],
        'receiverEmail': data['receiverEmail'],
        'receiverAddress': data['receiverAddress'],
        'description': data['description'],
        'weight': data['weight'],
        'type': data['type'] ?? 'package',
        'departureGarageId': data['departureGarageId'],
        'departureGarageName': data['departureGarageName'],
        'arrivalGarageId': data['arrivalGarageId'],
        'arrivalGarageName': data['arrivalGarageName'],
        'price': data['price'],
        'isUrgent': data['isUrgent'] ?? false,
        'isInsured': data['isInsured'] ?? false,
        'paymentMethod': paymentMethodValue,
        'paymentPhoneNumber': data['paymentPhoneNumber'],
        'photoUrls': data['photoUrls'] ?? [],
        'videoUrls': data['videoUrls'] ?? [],
        'notes': data['notes'],
      };

      if (data['senderId'] != null && data['senderId'].toString().isNotEmpty) {
        cleanedData['senderId'] = data['senderId'];
      }

      cleanedData.removeWhere((key, value) => value == null);

      debugPrint('📦 Envoi au backend: ${jsonEncode(cleanedData)}');
      cleanedData.removeWhere(
          (key, value) => value == null || (value is String && value.isEmpty));
      final response =
          await _dio.post('/driver/parcels/create', data: cleanedData);
      final responseData = _handleResponse(response);
      return Parcel.fromMinimalJson(responseData['parcel'] ?? responseData);
    } catch (e) {
      debugPrint('❌ Erreur createParcelByDriver: $e');
      rethrow;
    }
  }

  Future<Parcel> createParcel(Map<String, dynamic> data) async {
    try {
      final currentUser = await getCurrentUser();
      final role = currentUser.role;

      if (role == UserRole.driver) {
        return createParcelByDriver(data);
      }

      String endpoint;
      switch (role) {
        case UserRole.client:
          endpoint = '/client/parcels/create';
          break;
        case UserRole.driver:
          endpoint = '/driver/parcels/create';
          break;
        case UserRole.admin:
          endpoint = '/garage-admin/parcels/create';
          break;
        case UserRole.superAdmin:
          endpoint = '/super-admin/parcels/create';
          break;
      }

      final cleanedData = <String, dynamic>{
        'senderName': data['senderName'],
        'senderPhone': data['senderPhone'],
        'senderEmail': data['senderEmail'],
        'senderId': currentUser.id,
        'receiverName': data['receiverName'],
        'receiverPhone': data['receiverPhone'],
        'receiverEmail': data['receiverEmail'],
        'receiverAddress': data['receiverAddress'],
        'description': data['description'],
        'weight': data['weight'],
        'type': data['type'] ?? 'package',
        'departureGarageId': data['departureGarageId'],
        'departureGarageName': data['departureGarageName'],
        'arrivalGarageId': data['arrivalGarageId'],
        'arrivalGarageName': data['arrivalGarageName'],
        'price': data['price'],
        'isUrgent': data['isUrgent'] ?? false,
        'isInsured': data['isInsured'] ?? false,
        'photoUrls': data['photoUrls'] ?? [],
        'videoUrls': data['videoUrls'] ?? [],
        'driverId': data['driverId'],
        'driverName': data['driverName'],
        'driverPhone': data['driverPhone'],
        'isFreeForBidding': data['isFreeForBidding'] ?? false,
        'proposedPrice': data['proposedPrice'],
        'status': data['status'] ??
            (data['isFreeForBidding'] == true ? 'free' : 'pending'),
      };

      cleanedData.removeWhere(
          (key, value) => value == null || (value is String && value.isEmpty));

      debugPrint('📤 Envoi création colis à $endpoint');
      debugPrint('📦 Données: ${jsonEncode(cleanedData)}');

      final response = await _dio.post(endpoint, data: cleanedData);
      final responseData = _handleResponse(response);

      debugPrint('📥 Réponse création: $responseData');

      if (responseData['success'] == false) {
        final errorMsg = responseData['error'] ??
            responseData['message'] ??
            'Erreur inconnue';
        debugPrint('❌ Erreur backend: $errorMsg');
        throw Exception(errorMsg);
      }

      Map<String, dynamic> parcelData;

      if (responseData['parcel'] != null && responseData['parcel'] is Map) {
        parcelData = responseData['parcel'] as Map<String, dynamic>;
        debugPrint('📦 Format 1: colis trouvé dans responseData["parcel"]');
      } else if (responseData['data'] != null && responseData['data'] is Map) {
        parcelData = responseData['data'] as Map<String, dynamic>;
        debugPrint('📦 Format 2: colis trouvé dans responseData["data"]');
      } else if (responseData['id'] != null) {
        parcelData = responseData;
        debugPrint('📦 Format 3: réponse directement le colis');
      } else {
        debugPrint('❌ Format de réponse inattendu: $responseData');
        throw Exception('Format de réponse inattendu');
      }

      if (parcelData['id'] == null || parcelData['id'].toString().isEmpty) {
        debugPrint('❌ ID du colis manquant dans la réponse');
        throw Exception('ID du colis manquant');
      }

      debugPrint('✅ Colis créé avec ID: ${parcelData['id']}');

      return Parcel.fromMinimalJson(parcelData);
    } catch (e) {
      debugPrint('❌ Erreur createParcel: $e');
      rethrow;
    }
  }

  Future<Parcel> trackParcel(String trackingNumber) async {
    try {
      final response = await _dio.get('/public/parcels/track/$trackingNumber');
      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['parcel'] != null) {
        return Parcel.fromJson(responseData['parcel'] as Map<String, dynamic>);
      } else {
        throw Exception(responseData['message'] ?? 'Colis non trouvé');
      }
    } catch (e) {
      debugPrint('❌ Erreur trackParcel: $e');
      rethrow;
    }
  }

  Future<List<ParcelEvent>> getParcelEvents(String parcelId) async {
    try {
      final response = await _dio.get('/public/parcels/$parcelId/events');
      final responseData = _handleResponse(response);
      final dynamic rawEvents =
          responseData['events'] ?? responseData['data'] ?? [];
      List<dynamic> eventsData = rawEvents is List ? rawEvents : [];
      return eventsData.map((event) {
        final json = Map<String, dynamic>.from(event);
        Map<String, dynamic> metadata = {};
        if (json['metadata'] != null) {
          if (json['metadata'] is Map) {
            metadata = Map<String, dynamic>.from(json['metadata']);
          } else if (json['metadata'] is String) {
            try {
              final decoded = jsonDecode(json['metadata']);
              if (decoded is Map) metadata = Map<String, dynamic>.from(decoded);
            } catch (e) {}
          }
        }
        DateTime? parseDate(dynamic value) {
          if (value == null) return null;
          if (value is DateTime) return value;
          if (value is String) {
            try {
              return DateTime.parse(value);
            } catch (e) {
              return null;
            }
          }
          return null;
        }

        return ParcelEvent(
          id: json['id']?.toString() ?? '',
          parcelId: json['parcelId']?.toString() ??
              json['parcel_id']?.toString() ??
              '',
          status:
              ParcelStatus.fromString(json['status']?.toString() ?? 'pending'),
          description: json['description']?.toString() ?? '',
          location: json['location']?.toString(),
          locationLat: json['locationLat']?.toString(),
          locationLng: json['locationLng']?.toString(),
          userId: json['userId']?.toString(),
          userName: json['userName']?.toString(),
          userRole: json['userRole']?.toString(),
          photoUrl: json['photoUrl']?.toString(),
          metadata: metadata,
          timestamp: parseDate(json['timestamp'] ??
                  json['createdAt'] ??
                  json['created_at']) ??
              DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Erreur getParcelEvents: $e');
      return [];
    }
  }

  Future<Parcel> updateParcelStatus(String parcelId, String status,
      {String? location}) async {
    try {
      debugPrint('🔥🔥🔥 updateParcelStatus APPELEE !!! 🔥🔥🔥');
      debugPrint('   parcelId: $parcelId');
      debugPrint('   status: $status');
      debugPrint('   location: $location');
      final currentUser = await getCurrentUser();
      final role = currentUser.role;
      String endpoint;
      switch (role) {
        case UserRole.client:
          endpoint = '/client/parcels/$parcelId/status';
          break;
        case UserRole.driver:
          endpoint = '/driver/parcels/$parcelId/status';
          break;
        case UserRole.admin:
          endpoint = '/garage-admin/parcels/$parcelId/status';
          break;
        case UserRole.superAdmin:
          endpoint = '/super-admin/parcels/$parcelId/status';
          break;
      }
      final response = await _dio
          .put(endpoint, data: {'status': status, 'location': location});
      final responseData = _handleResponse(response);
      if (responseData['success'] == true) {
        if (responseData['parcel'] != null) {
          return Parcel.fromJson(
              responseData['parcel'] as Map<String, dynamic>);
        }
        final updatedParcel = await getParcelById(parcelId);
        if (updatedParcel != null) {
          return updatedParcel;
        }
        throw Exception(
            'Statut mis à jour mais impossible de récupérer le colis');
      } else {
        throw Exception(
            responseData['message'] ?? 'Erreur lors de la mise à jour');
      }
    } catch (e) {
      debugPrint('❌ Erreur updateParcelStatus: $e');
      rethrow;
    }
  }

  Future<Parcel?> getParcelById(String parcelId) async {
    try {
      final currentUser = await getCurrentUser();
      final role = currentUser.role;
      String endpoint;
      switch (role) {
        case UserRole.client:
          endpoint = '/client/parcels/$parcelId';
          break;
        case UserRole.driver:
          endpoint = '/driver/parcels/$parcelId';
          break;
        case UserRole.admin:
          endpoint = '/garage-admin/parcels/$parcelId';
          break;
        case UserRole.superAdmin:
          endpoint = '/super-admin/parcels/$parcelId';
          break;
      }
      final response = await _dio.get(endpoint);
      final responseData = _handleResponse(response);
      if (responseData['id'] != null) {
        return Parcel.fromJson(responseData);
      }
      if (responseData['success'] == true && responseData['parcel'] != null) {
        return Parcel.fromJson(responseData['parcel'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur getParcelById: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> estimateDeliveryPrice({
    required double weight,
    required String departureGarageId,
    required String arrivalGarageId,
    required String type,
    bool urgent = false,
    bool insured = false,
  }) async {
    try {
      final response = await _dio.post('/parcels/estimate', data: {
        'weight': weight,
        'departureGarageId': departureGarageId,
        'arrivalGarageId': arrivalGarageId,
        'type': type,
        'urgent': urgent,
        'insured': insured,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getParcelTimeline(String parcelId) async {
    try {
      final response = await _dio.get('/parcels/$parcelId/timeline');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addParcelNote(
      String parcelId, String note) async {
    try {
      final response =
          await _dio.post('/parcels/$parcelId/notes', data: {'note': note});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getParcelNotes(String parcelId) async {
    try {
      final response = await _dio.get('/parcels/$parcelId/notes');
      final responseData = _handleResponse(response);
      final List<dynamic> notesData = responseData['notes'] ?? [];
      return notesData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Erreur getParcelNotes: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> downloadDeliveryProof(String parcelId) async {
    try {
      final response = await _dio.get('/parcels/$parcelId/proof');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== ADMIN GARAGE ====================

  Future<List<Parcel>> getGarageParcels({String? status}) async {
    try {
      if (isMockMode) {
        final user = await getCurrentUser();
        final parcels = MockData.parcelsForUser(user);
        if (status == null || status.isEmpty) return parcels;
        return parcels
            .where((parcel) => parcel.status.value == status)
            .toList();
      }

      final response = await _dio.get('/garage-admin/parcels');
      final responseData = _handleResponse(response);
      final List<dynamic> parcelsData = responseData['parcels'] ?? [];
      return parcelsData
          .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getGarageParcels: $e');
      return [];
    }
  }

  Future<List<User>> getGarageDrivers() async {
    try {
      if (isMockMode) return MockData.drivers;

      final response = await _dio.get('/garage-admin/drivers');
      final responseData = _handleResponse(response);
      final List<dynamic> driversData = responseData['drivers'] ?? [];
      return driversData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getGarageDrivers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> assignDriverToParcel(
      String parcelId, String driverId) async {
    try {
      if (isMockMode) {
        return {'success': true, 'message': 'Chauffeur assigné en mode mock'};
      }

      final response = await _dio.put(
          '/garage-admin/parcels/$parcelId/assign-driver',
          data: {'driverId': driverId});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteParcelAdmin(String parcelId) async {
    try {
      final response = await _dio.delete('/garage-admin/parcels/$parcelId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getGarageDailyReport(DateTime date) async {
    try {
      final response = await _dio.get('/garage-admin/reports/daily',
          queryParameters: {'date': date.toIso8601String().split('T').first});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getGarageMonthlyReport(
      int year, int month) async {
    try {
      final response = await _dio.get('/garage-admin/reports/monthly',
          queryParameters: {'year': year, 'month': month});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> exportGarageReport(
      {required String format, DateTime? startDate, DateTime? endDate}) async {
    try {
      final queryParams = <String, dynamic>{'format': format};
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String().split('T').first;
      if (endDate != null)
        queryParams['endDate'] = endDate.toIso8601String().split('T').first;
      final response = await _dio.get('/garage-admin/reports/export',
          queryParameters: queryParams);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> bulkAssignDrivers(
      List<Map<String, String>> assignments) async {
    try {
      final response = await _dio.post('/garage-admin/parcels/bulk-assign',
          data: {'assignments': assignments});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== SUPER ADMIN ====================

  Future<Map<String, dynamic>> getSuperAdminStats() async {
    try {
      final response = await _dio.get('/super-admin/stats');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAdvancedStats() async {
    try {
      final response = await _dio.get('/super-admin/stats/advanced');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getMonthlyReport({int? year, int? month}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (year != null) queryParams['year'] = year;
      if (month != null) queryParams['month'] = month;
      final response = await _dio.get('/super-admin/reports/monthly',
          queryParameters: queryParams);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<User>> getAllUsersSuperAdmin() async {
    try {
      if (isMockMode) return MockData.users;

      final response = await _dio.get('/super-admin/users');
      final responseData = _handleResponse(response);
      final List<dynamic> usersData = responseData['users'] ?? [];
      return usersData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getAllUsersSuperAdmin: $e');
      return [];
    }
  }

  Future<List<User>> getAllDrivers() async {
    try {
      final response = await _dio
          .get('/public/drivers/search', queryParameters: {'limit': 100});

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData;

        if (response.data is String) {
          responseData = jsonDecode(response.data as String);
          debugPrint('📦 Réponse parsée depuis String');
        } else if (response.data is Map) {
          responseData = response.data as Map<String, dynamic>;
          debugPrint('📦 Réponse déjà en Map');
        } else {
          debugPrint(
              '❌ Type de réponse inattendu: ${response.data.runtimeType}');
          return [];
        }

        if (responseData['success'] == true) {
          final List<dynamic> driversData = responseData['drivers'] ?? [];
          debugPrint(
              '✅ ${driversData.length} chauffeurs chargés depuis getAllDrivers');
          return driversData
              .map((json) => User.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          debugPrint('⚠️ Erreur API getAllDrivers: ${responseData['message']}');
          return [];
        }
      }
      debugPrint('⚠️ getAllDrivers: Statut HTTP ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('❌ Erreur getAllDrivers: $e');
      return [];
    }
  }

  Future<User?> getUserByIdSuperAdmin(String userId) async {
    try {
      final response = await _dio.get('/super-admin/users/$userId');
      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['user'] != null) {
        return User.fromJson(responseData['user']);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur getUserByIdSuperAdmin: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createUserSuperAdmin({
    required String fullName,
    required String email,
    required String phone,
    required String role,
    required String status,
    String? address,
    String? city,
    String? region,
    required String pin,
    String? gender,
    String? vehiclePlate,
    String? vehicleModel,
    String? driverStatus,
    String? garageId,
  }) async {
    try {
      final response = await _dio.post('/super-admin/users', data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'status': status,
        'address': address,
        'city': city,
        'region': region,
        'pin': pin,
        'gender': gender,
        'vehiclePlate': vehiclePlate,
        'vehicleModel': vehicleModel,
        'driverStatus': driverStatus,
        'garageId': garageId,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUserSuperAdmin({
    required String userId,
    required String fullName,
    required String email,
    required String phone,
    required String role,
    required String status,
    String? address,
    String? city,
    String? region,
    String? vehiclePlate,
    String? vehicleModel,
    String? driverStatus,
    String? garageId,
  }) async {
    try {
      final response = await _dio.put('/super-admin/users/$userId', data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'status': status,
        'address': address,
        'city': city,
        'region': region,
        'vehiclePlate': vehiclePlate,
        'vehicleModel': vehicleModel,
        'driverStatus': driverStatus,
        'garageId': garageId,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUserRoleSuperAdmin(
      String userId, String role) async {
    try {
      final response = await _dio
          .patch('/super-admin/users/$userId/role', data: {'role': role});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUserStatusSuperAdmin(
      String userId, String status) async {
    try {
      final response = await _dio
          .patch('/super-admin/users/$userId/status', data: {'status': status});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteUserSuperAdmin(String userId) async {
    try {
      final response = await _dio.delete('/super-admin/users/$userId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Garage>> getAllGaragesSuperAdmin() async {
    try {
      final response = await _dio.get('/super-admin/garages');
      final responseData = _handleResponse(response);
      final List<dynamic> garagesData = responseData['garages'] ?? [];
      return garagesData
          .map((json) => Garage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getAllGaragesSuperAdmin: $e');
      return [];
    }
  }

  Future<Garage?> getGarageByIdSuperAdmin(String garageId) async {
    try {
      final response = await _dio.get('/super-admin/garages/$garageId');
      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['garage'] != null) {
        return Garage.fromJson(responseData['garage']);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur getGarageByIdSuperAdmin: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createGarageSuperAdmin({
    required String name,
    required String city,
    required String region,
    String? address,
    String? phone,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.post('/super-admin/garages', data: {
        'name': name,
        'city': city,
        'region': region,
        'address': address,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateGarageSuperAdmin({
    required String garageId,
    required String name,
    required String city,
    required String region,
    String? address,
    String? phone,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.put('/super-admin/garages/$garageId', data: {
        'name': name,
        'city': city,
        'region': region,
        'address': address,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteGarageSuperAdmin(String garageId) async {
    try {
      final response = await _dio.delete('/super-admin/garages/$garageId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Parcel>> getAllParcelsSuperAdmin() async {
    try {
      if (isMockMode) return MockData.parcels;

      final response = await _dio.get('/super-admin/parcels');
      final responseData = _handleResponse(response);
      final List<dynamic> parcelsData = responseData['parcels'] ?? [];
      return parcelsData
          .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getAllParcelsSuperAdmin: $e');
      return [];
    }
  }

  Future<Parcel?> getParcelByIdSuperAdmin(String parcelId) async {
    try {
      final response = await _dio.get('/super-admin/parcels/$parcelId');
      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['parcel'] != null) {
        return Parcel.fromJson(responseData['parcel']);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur getParcelByIdSuperAdmin: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateParcelSuperAdmin({
    required String parcelId,
    required String status,
    String? driverId,
    double? price,
  }) async {
    try {
      final response = await _dio.put('/super-admin/parcels/$parcelId', data: {
        'status': status,
        'driverId': driverId,
        'price': price,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteParcelSuperAdmin(String parcelId) async {
    try {
      final response = await _dio.delete('/super-admin/parcels/$parcelId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final response = await _dio.get('/super-admin/system/health');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAuditLogs({
    int page = 1,
    int limit = 50,
    String? userId,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};
      if (userId != null) queryParams['userId'] = userId;
      if (action != null) queryParams['action'] = action;
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String().split('T').first;
      if (endDate != null)
        queryParams['endDate'] = endDate.toIso8601String().split('T').first;
      final response = await _dio.get('/super-admin/audit-logs',
          queryParameters: queryParams);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getSystemConfig() async {
    try {
      final response = await _dio.get('/super-admin/config');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateSystemConfig(
      Map<String, dynamic> config) async {
    try {
      final response = await _dio.put('/super-admin/config', data: config);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> backupDatabase() async {
    try {
      final response = await _dio.post('/super-admin/backup');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> restoreDatabase(String backupId) async {
    try {
      final response =
          await _dio.post('/super-admin/restore', data: {'backupId': backupId});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getBackups() async {
    try {
      final response = await _dio.get('/super-admin/backups');
      final responseData = _handleResponse(response);
      final List<dynamic> backupsData = responseData['backups'] ?? [];
      return backupsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Erreur getBackups: $e');
      return [];
    }
  }

  // ==================== GESTION DES ADMINS GARAGE (SUPER ADMIN) ====================

  Future<Map<String, dynamic>> createGarageAdminSuperAdmin({
    required String email,
    required String phone,
    required String fullName,
    required String garageId,
    String pin = '123456',
  }) async {
    try {
      final response = await _dio.post('/super-admin/garage-admins', data: {
        'email': email,
        'phone': phone,
        'fullName': fullName,
        'garageId': garageId,
        'pin': pin,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<User>> getAllGarageAdminsSuperAdmin() async {
    try {
      final response = await _dio.get('/super-admin/garage-admins');
      final responseData = _handleResponse(response);
      final List<dynamic> adminsData = responseData['admins'] ?? [];
      return adminsData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getAllGarageAdminsSuperAdmin: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> updateGarageAdminSuperAdmin(
      {required String adminId, required String garageId}) async {
    try {
      final response = await _dio.put('/super-admin/garage-admins/$adminId',
          data: {'garageId': garageId});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteGarageAdminSuperAdmin(
      String adminId) async {
    try {
      final response = await _dio.delete('/super-admin/garage-admins/$adminId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== GESTION DES CHAUFFEURS ====================

  Future<List<User>> getAllDriversSuperAdmin() async {
    try {
      if (isMockMode) return MockData.drivers;

      final response = await _dio
          .get('/super-admin/users', queryParameters: {'role': 'driver'});
      final responseData = _handleResponse(response);
      final List<dynamic> usersData = responseData['users'] ?? [];
      return usersData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .where((user) => user.role == UserRole.driver)
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getAllDriversSuperAdmin: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> updateDriverStatusSuperAdmin(
      String driverId, String status) async {
    try {
      final response = await _dio.patch('/super-admin/users/$driverId/status',
          data: {'status': status});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateDriverDocument(
      {required String type, required String documentUrl}) async {
    try {
      final response = await _dio.put('/driver/documents',
          data: {'type': type, 'documentUrl': documentUrl});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getDriverDocuments() async {
    try {
      final response = await _dio.get('/driver/documents');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getDriverSchedule(DateTime date) async {
    try {
      final response = await _dio.get('/driver/schedule',
          queryParameters: {'date': date.toIso8601String().split('T').first});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateDriverSchedule(
      {required DateTime date, required bool isAvailable}) async {
    try {
      final response = await _dio.post('/driver/schedule', data: {
        'date': date.toIso8601String().split('T').first,
        'isAvailable': isAvailable
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getDriverPerformance() async {
    try {
      final response = await _dio.get('/driver/performance');
      final responseData = _handleResponse(response);
      final List<dynamic> performanceData = responseData['performance'] ?? [];
      return performanceData
          .map((json) => json as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getDriverPerformance: $e');
      return [];
    }
  }

  // ==================== GESTION DES CLIENTS ====================

  Future<List<User>> getAllClientsSuperAdmin() async {
    try {
      final response = await _dio.get('/super-admin/clients');
      final responseData = _handleResponse(response);
      final List<dynamic> clientsData = responseData['clients'] ?? [];
      return clientsData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getAllClientsSuperAdmin: $e');
      return [];
    }
  }

  // ==================== STATISTIQUES ====================

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _dio.get('/admin/stats/dashboard');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getGarageStats(String garageId) async {
    try {
      final response = await _dio.get('/garage-admin/stats');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getDriverStats() async {
    try {
      final response = await _dio.get('/driver/stats');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== NOTIFICATIONS ====================

  /// Récupérer les notifications de l'utilisateur
  Future<List<Map<String, dynamic>>> getNotifications({
    String? type,
    bool? isRead,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (type != null) queryParams['type'] = type;
      if (isRead != null) queryParams['isRead'] = isRead.toString();
      queryParams['limit'] = limit;
      queryParams['offset'] = offset;

      final response = await _dio.get(
        '/notifications',
        queryParameters: queryParams,
      );
      final responseData = _handleResponse(response);

      if (responseData['success'] == true) {
        return List<Map<String, dynamic>>.from(
            responseData['notifications'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Erreur getNotifications: $e');
      return [];
    }
  }

  /// Récupérer le nombre de notifications non lues
  Future<int> getUnreadNotificationsCount() async {
    try {
      if (isMockMode) return 3;

      final response = await _dio.get('/notifications/unread-count');
      final responseData = _handleResponse(response);

      if (responseData['success'] == true) {
        return responseData['unreadCount'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Erreur getUnreadNotificationsCount: $e');
      return 0;
    }
  }

  /// Marquer une notification comme lue
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final response = await _dio.patch('/notifications/$notificationId/read');
      final responseData = _handleResponse(response);
      return responseData['success'] == true;
    } catch (e) {
      debugPrint('❌ Erreur markNotificationAsRead: $e');
      return false;
    }
  }

  /// Marquer toutes les notifications comme lues
  Future<bool> markAllNotificationsAsRead() async {
    try {
      final response = await _dio.post('/notifications/read-all');
      final responseData = _handleResponse(response);
      return responseData['success'] == true;
    } catch (e) {
      debugPrint('❌ Erreur markAllNotificationsAsRead: $e');
      return false;
    }
  }

  /// Supprimer une notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final response = await _dio.delete('/notifications/$notificationId');
      final responseData = _handleResponse(response);
      return responseData['success'] == true;
    } catch (e) {
      debugPrint('❌ Erreur deleteNotification: $e');
      return false;
    }
  }

  /// Supprimer toutes les notifications
  Future<bool> deleteAllNotifications() async {
    try {
      final response = await _dio.delete('/notifications/all');
      final responseData = _handleResponse(response);
      return responseData['success'] == true;
    } catch (e) {
      debugPrint('❌ Erreur deleteAllNotifications: $e');
      return false;
    }
  }

  // ==================== PAIEMENTS ====================

  Future<Map<String, dynamic>> initiatePayment(
      {required double amount,
      required String method,
      String? parcelId,
      String? phoneNumber}) async {
    try {
      final response = await _dio.post('/payments/initiate', data: {
        'amount': amount,
        'method': method,
        'parcelId': parcelId,
        'phoneNumber': phoneNumber,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> confirmPayment(String paymentId,
      {String? transactionId}) async {
    try {
      final response = await _dio.post('/payments/$paymentId/confirm',
          data: {'transactionId': transactionId});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final response = await _dio.get('/payments/history');
      final responseData = _handleResponse(response);
      final List<dynamic> paymentsData = responseData['payments'] ?? [];
      return paymentsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Erreur getPaymentHistory: $e');
      return [];
    }
  }

  // ==================== UPLOAD ====================

  Future<String?> uploadXFile(XFile file, String type) async {
    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final response = await _dio.post('/upload/base64', data: {
        'file': base64Image,
        'type': type,
        'filename': file.name,
        'contentType': _getContentType(file.name),
      });
      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['url'] != null) {
        return responseData['url'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur uploadXFile: $e');
      return null;
    }
  }

  Future<String?> uploadFile(File file, String type) async {
    if (kIsWeb) {
      debugPrint(
          '⚠️ uploadFile ne fonctionne pas sur Web, utilisez uploadXFile à la place');
      return null;
    }
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path,
            filename: file.path.split('/').last,
            contentType: MediaType('image', 'jpeg')),
        'type': type,
      });
      final response = await _dio.post('/upload', data: formData);
      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['url'] != null) {
        return responseData['url'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur uploadFile: $e');
      return null;
    }
  }

  Future<String?> uploadFileFromXFile(XFile file, String type) async {
    try {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes,
              filename: file.name, contentType: MediaType('image', 'jpeg')),
          'type': type,
        });
        final response = await _dio.post('/upload', data: formData);
        final responseData = _handleResponse(response);
        if (responseData['success'] == true && responseData['url'] != null)
          return responseData['url'];
        return null;
      } else {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path,
              filename: file.name, contentType: MediaType('image', 'jpeg')),
          'type': type,
        });
        final response = await _dio.post('/upload', data: formData);
        final responseData = _handleResponse(response);
        if (responseData['success'] == true && responseData['url'] != null)
          return responseData['url'];
        return null;
      }
    } catch (e) {
      debugPrint('❌ Erreur uploadFileFromXFile: $e');
      return null;
    }
  }

  Future<List<String>> uploadMultipleFiles(
      List<XFile> files, String type) async {
    try {
      final List<String> urls = [];
      for (final file in files) {
        final url = await uploadXFile(file, type);
        if (url != null) urls.add(url);
      }
      return urls;
    } catch (e) {
      debugPrint('❌ Erreur uploadMultipleFiles: $e');
      return [];
    }
  }

  Future<List<String>> uploadMultipleFilesFromXFile(
      List<XFile> files, String type) async {
    try {
      final List<String> urls = [];
      for (final file in files) {
        final url = await uploadFileFromXFile(file, type);
        if (url != null) urls.add(url);
      }
      return urls;
    } catch (e) {
      debugPrint('❌ Erreur uploadMultipleFilesFromXFile: $e');
      return [];
    }
  }

  Future<String?> uploadProfilePhoto(XFile file) async {
    return uploadXFile(file, 'profile');
  }

  Future<String?> uploadProfilePhotoFromFile(dynamic file) async {
    try {
      if (kIsWeb && file is XFile) {
        final bytes = await file.readAsBytes();
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: file.name),
          'type': 'profile',
        });
        final response = await _dio.post('/upload',
            data: formData,
            options: Options(headers: {'Content-Type': 'multipart/form-data'}));
        final responseData = _handleResponse(response);
        if (responseData['success'] == true && responseData['url'] != null)
          return responseData['url'];
        return null;
      } else if (file is XFile) {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path, filename: file.name),
          'type': 'profile',
        });
        final response = await _dio.post('/upload',
            data: formData,
            options: Options(headers: {'Content-Type': 'multipart/form-data'}));
        final responseData = _handleResponse(response);
        if (responseData['success'] == true && responseData['url'] != null)
          return responseData['url'];
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur uploadProfilePhotoFromFile: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> uploadFileDirect(FormData formData) async {
    try {
      final response = await _dio.post('/upload',
          data: formData,
          options: Options(headers: {'Content-Type': 'multipart/form-data'}));
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur uploadFileDirect: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateProfilePhoto(String photoUrl) async {
    try {
      final currentUser = await getCurrentUser();
      final role = currentUser.role;
      String endpoint;
      switch (role) {
        case UserRole.client:
          endpoint = '/client/profile-photo';
          break;
        case UserRole.driver:
          endpoint = '/driver/profile-photo';
          break;
        case UserRole.admin:
          endpoint = '/garage-admin/profile-photo';
          break;
        case UserRole.superAdmin:
          endpoint = '/super-admin/profile-photo';
          break;
      }
      final response = await _dio.put(endpoint, data: {'photoUrl': photoUrl});
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur updateProfilePhoto: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateProfilePhotoUrl(String photoUrl) async {
    try {
      final currentUser = await getCurrentUser();
      final role = currentUser.role;
      String endpoint;
      switch (role) {
        case UserRole.client:
          endpoint = '/client/profile-photo';
          break;
        case UserRole.driver:
          endpoint = '/driver/profile-photo';
          break;
        case UserRole.admin:
          endpoint = '/garage-admin/profile-photo';
          break;
        case UserRole.superAdmin:
          endpoint = '/super-admin/profile-photo';
          break;
      }
      final response = await _dio.put(endpoint, data: {'photoUrl': photoUrl});
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur updateProfilePhotoUrl: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadAndUpdateProfilePhoto(XFile file) async {
    try {
      final photoUrl = await uploadProfilePhoto(file);
      if (photoUrl == null)
        return {'success': false, 'message': 'Erreur lors de l\'upload'};
      return await updateProfilePhotoUrl(photoUrl);
    } catch (e) {
      debugPrint('❌ Erreur uploadAndUpdateProfilePhoto: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<String?> uploadProfilePhotoFile(File file) async {
    return uploadFile(file, 'profile');
  }

  // ==================== MÉTHODES ADMIN STANDARD ====================

  Future<List<Garage>> getAllGarages() async {
    try {
      final response = await _dio.get('/public/garages');
      final responseData = _handleResponse(response);
      if (responseData['success'] != true) {
        debugPrint('❌ Erreur API garages: ${responseData['message']}');
        return [];
      }
      final List<dynamic> garagesData = responseData['garages'] ?? [];
      debugPrint('📦 ${garagesData.length} garages reçus de l\'API');
      return garagesData
          .map((json) => Garage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getAllGarages: $e');
      return [];
    }
  }

  Future<List<User>> getAllUsers() async {
    try {
      final response = await _dio.get('/admin/users');
      final responseData = _handleResponse(response);
      final List<dynamic> usersData = responseData['users'] ?? [];
      return usersData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getAllUsers: $e');
      return [];
    }
  }

  Future<List<User>> getAllClients() async {
    try {
      final response = await _dio.get('/public/clients');
      final responseData = _handleResponse(response);
      final List<dynamic> usersData = responseData['users'] ?? [];
      return usersData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getAllClients: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createUserByAdmin({
    required String fullName,
    required String email,
    required String phone,
    required String role,
    required String status,
    String? address,
    String? city,
    String? region,
    required String pin,
    String? gender,
    String? vehiclePlate,
    String? vehicleModel,
    String? driverStatus,
  }) async {
    try {
      final response = await _dio.post('/admin/users', data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'status': status,
        'address': address,
        'city': city,
        'region': region,
        'pin': pin,
        'gender': gender,
        'vehiclePlate': vehiclePlate,
        'vehicleModel': vehicleModel,
        'driverStatus': driverStatus,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUserByAdmin({
    required String userId,
    required String fullName,
    required String email,
    required String phone,
    required String role,
    required String status,
    String? address,
    String? city,
    String? region,
    String? vehiclePlate,
    String? vehicleModel,
    String? driverStatus,
    String? garageId,
  }) async {
    try {
      final response = await _dio.put('/admin/users/$userId', data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'status': status,
        'address': address,
        'city': city,
        'region': region,
        'vehiclePlate': vehiclePlate,
        'vehicleModel': vehicleModel,
        'driverStatus': driverStatus,
        'garageId': garageId,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUserStatusAdmin(
      String userId, String status) async {
    try {
      final response = await _dio
          .patch('/admin/users/$userId/status', data: {'status': status});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteUserAdmin(String userId) async {
    try {
      final response = await _dio.delete('/admin/users/$userId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetUserPinAdmin(String userId) async {
    try {
      final response = await _dio.post('/admin/users/$userId/reset-pin');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Parcel>> getAllParcelsAdmin() async {
    try {
      final response = await _dio.get('/admin/parcels');
      final responseData = _handleResponse(response);
      final List<dynamic> parcelsData = responseData['parcels'] ?? [];
      return parcelsData
          .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getAllParcelsAdmin: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createGarageAdmin({
    required String name,
    required String city,
    required String region,
    String? address,
    String? phone,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.post('/admin/garages', data: {
        'name': name,
        'city': city,
        'region': region,
        'address': address,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateGarageAdmin({
    required String garageId,
    required String name,
    required String city,
    required String region,
    String? address,
    String? phone,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.put('/admin/garages/$garageId', data: {
        'name': name,
        'city': city,
        'region': region,
        'address': address,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteGarageAdmin(String garageId) async {
    try {
      final response = await _dio.delete('/admin/garages/$garageId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== RECHERCHE PUBLIQUE DE CHAUFFEURS ====================

  Future<List<User>> searchDriversPublic({String? query}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (query != null && query.isNotEmpty) queryParams['query'] = query;
      final response = await _dio.get('/public/drivers/search',
          queryParameters: queryParams);
      final responseData = _handleResponse(response);
      final List<dynamic> driversData = responseData['drivers'] ?? [];
      return driversData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur searchDriversPublic: $e');
      return [];
    }
  }

  Future<User?> getDriverByIdPublic(String driverId) async {
    try {
      final response = await _dio.get('/public/drivers/$driverId');
      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['driver'] != null) {
        return User.fromJson(responseData['driver']);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur getDriverByIdPublic: $e');
      return null;
    }
  }

  Future<List<User>> getDriversByGaragePublic(String garageId) async {
    try {
      final response = await _dio.get('/public/drivers/garage/$garageId');
      final responseData = _handleResponse(response);
      final List<dynamic> driversData = responseData['drivers'] ?? [];
      return driversData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getDriversByGaragePublic: $e');
      return [];
    }
  }

  // ==================== VÉHICULES ====================

  Future<Map<String, dynamic>> addVehicle({
    required String plateNumber,
    required String model,
    required String type,
    required int capacity,
    required String garageId,
  }) async {
    try {
      final response = await _dio.post('/vehicles', data: {
        'plateNumber': plateNumber,
        'model': model,
        'type': type,
        'capacity': capacity,
        'garageId': garageId,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getVehicles({String? garageId}) async {
    try {
      final queryParams =
          garageId != null ? {'garageId': garageId} : <String, dynamic>{};
      final response =
          await _dio.get('/vehicles', queryParameters: queryParams);
      final responseData = _handleResponse(response);
      final List<dynamic> vehiclesData = responseData['vehicles'] ?? [];
      return vehiclesData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Erreur getVehicles: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> assignVehicleToDriver(
      String vehicleId, String driverId) async {
    try {
      final response = await _dio
          .put('/vehicles/$vehicleId/assign', data: {'driverId': driverId});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateVehicleStatus(
      String vehicleId, bool isAvailable) async {
    try {
      final response = await _dio.patch('/vehicles/$vehicleId/status',
          data: {'isAvailable': isAvailable});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteVehicle(String vehicleId) async {
    try {
      final response = await _dio.delete('/vehicles/$vehicleId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== RAPPORTS ET EXPORTATIONS ====================

  Future<Map<String, dynamic>> getDailyReport({required DateTime date}) async {
    try {
      final response = await _dio.get('/super-admin/reports/daily',
          queryParameters: {'date': date.toIso8601String().split('T').first});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getYearlyReport({required int year}) async {
    try {
      final response = await _dio
          .get('/super-admin/reports/yearly', queryParameters: {'year': year});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> exportData(
      {required String type, String? format}) async {
    try {
      final response = await _dio.get('/super-admin/export',
          queryParameters: {'type': type, 'format': format ?? 'json'});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<String?> exportReport(
      {required String reportType,
      required String format,
      DateTime? startDate,
      DateTime? endDate}) async {
    try {
      final queryParams = <String, dynamic>{
        'reportType': reportType,
        'format': format
      };
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String().split('T').first;
      if (endDate != null)
        queryParams['endDate'] = endDate.toIso8601String().split('T').first;
      final response =
          await _dio.get('/reports/export', queryParameters: queryParams);
      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['url'] != null)
        return responseData['url'];
      return null;
    } catch (e) {
      debugPrint('❌ Erreur exportReport: $e');
      return null;
    }
  }

  // ==================== GÉOLOCALISATION ====================

  Future<Map<String, dynamic>> updateDriverLocation(
      {required double latitude, required double longitude}) async {
    try {
      final response = await _dio.post('/driver/location',
          data: {'latitude': latitude, 'longitude': longitude});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getDriverLocation(String driverId) async {
    try {
      final response = await _dio.get('/driver/$driverId/location');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getParcelLocation(String parcelId) async {
    try {
      final response = await _dio.get('/parcels/$parcelId/location');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== ÉVALUATIONS ====================

  Future<Map<String, dynamic>> submitRating(
      {required String parcelId, required int rating, String? comment}) async {
    try {
      final response = await _dio.post('/ratings',
          data: {'parcelId': parcelId, 'rating': rating, 'comment': comment});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getDriverRatings(String driverId) async {
    try {
      final response = await _dio.get('/ratings/driver/$driverId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== SUPPORT ====================

  Future<Map<String, dynamic>> sendSupportMessage(
      {required String subject,
      required String message,
      List<String>? attachments}) async {
    try {
      final response = await _dio.post('/support/messages', data: {
        'subject': subject,
        'message': message,
        'attachments': attachments
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getSupportMessages() async {
    try {
      final response = await _dio.get('/support/messages');
      final responseData = _handleResponse(response);
      final List<dynamic> messagesData = responseData['messages'] ?? [];
      return messagesData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Erreur getSupportMessages: $e');
      return [];
    }
  }

  // ==================== VÉRIFICATION D'IDENTITÉ ====================

  Future<Map<String, dynamic>> verifyIdentity(
      {required String nationalId,
      required String fullName,
      required DateTime birthDate}) async {
    try {
      final response = await _dio.post('/identity/verify', data: {
        'nationalId': nationalId,
        'fullName': fullName,
        'birthDate': birthDate.toIso8601String(),
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadIdentityDocument(
      File file, String type) async {
    try {
      final formData = FormData.fromMap(
          {'file': await MultipartFile.fromFile(file.path), 'type': type});
      final response = await _dio.post('/identity/upload', data: formData);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getIdentityStatus() async {
    try {
      final response = await _dio.get('/identity/status');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== PROMOTIONS ET COUPONS ====================

  Future<Map<String, dynamic>> validateCoupon(
      String code, double amount) async {
    try {
      final response = await _dio
          .post('/coupons/validate', data: {'code': code, 'amount': amount});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableCoupons() async {
    try {
      final response = await _dio.get('/coupons/available');
      final responseData = _handleResponse(response);
      final List<dynamic> couponsData = responseData['coupons'] ?? [];
      return couponsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Erreur getAvailableCoupons: $e');
      return [];
    }
  }

  // ==================== MESSAGERIE ====================

  Future<Map<String, dynamic>> sendMessage(
      {required String receiverId,
      required String message,
      String? parcelId}) async {
    try {
      final response = await _dio.post('/messages', data: {
        'receiverId': receiverId,
        'message': message,
        'parcelId': parcelId
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final response = await _dio.get('/messages/conversations');
      final responseData = _handleResponse(response);
      final List<dynamic> conversationsData =
          responseData['conversations'] ?? [];
      return conversationsData
          .map((json) => json as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur getConversations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String conversationId,
      {int page = 1}) async {
    try {
      final response = await _dio
          .get('/messages/$conversationId', queryParameters: {'page': page});
      final responseData = _handleResponse(response);
      final List<dynamic> messagesData = responseData['messages'] ?? [];
      return messagesData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Erreur getMessages: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> markMessageAsRead(String messageId) async {
    try {
      final response = await _dio.patch('/messages/$messageId/read');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== FAVORIS ====================

  Future<Map<String, dynamic>> addFavoriteGarage(String garageId) async {
    try {
      final response = await _dio.post('/favorites/garages/$garageId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> removeFavoriteGarage(String garageId) async {
    try {
      final response = await _dio.delete('/favorites/garages/$garageId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getFavoriteGarages() async {
    try {
      final response = await _dio.get('/favorites/garages');
      final responseData = _handleResponse(response);
      final List<dynamic> garagesData = responseData['garages'] ?? [];
      return garagesData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Erreur getFavoriteGarages: $e');
      return [];
    }
  }

  // ==================== ADRESSES ====================

  Future<Map<String, dynamic>> addAddress({
    required String label,
    required String address,
    required String city,
    required String region,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    try {
      final response = await _dio.post('/addresses', data: {
        'label': label,
        'address': address,
        'city': city,
        'region': region,
        'latitude': latitude,
        'longitude': longitude,
        'isDefault': isDefault,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getAddresses() async {
    try {
      final response = await _dio.get('/addresses');
      final responseData = _handleResponse(response);
      final List<dynamic> addressesData = responseData['addresses'] ?? [];
      return addressesData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Erreur getAddresses: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> updateAddress(
      String addressId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/addresses/$addressId', data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteAddress(String addressId) async {
    try {
      final response = await _dio.delete('/addresses/$addressId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setDefaultAddress(String addressId) async {
    try {
      final response = await _dio.patch('/addresses/$addressId/default');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== RECHERCHE ====================

  Future<Map<String, dynamic>> searchGlobal(String query,
      {int limit = 20}) async {
    try {
      final response = await _dio
          .get('/search', queryParameters: {'q': query, 'limit': limit});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> searchParcels(
      {required String query,
      String? status,
      DateTime? startDate,
      DateTime? endDate}) async {
    try {
      final queryParams = <String, dynamic>{'q': query};
      if (status != null) queryParams['status'] = status;
      if (startDate != null)
        queryParams['startDate'] = startDate.toIso8601String().split('T').first;
      if (endDate != null)
        queryParams['endDate'] = endDate.toIso8601String().split('T').first;
      final response =
          await _dio.get('/search/parcels', queryParameters: queryParams);
      final responseData = _handleResponse(response);
      final List<dynamic> parcelsData = responseData['parcels'] ?? [];
      return parcelsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Erreur searchParcels: $e');
      return [];
    }
  }

  // ==================== MARCHANDAGE (LIBRE SERVICE) ====================

  /// Récupérer tous les colis en libre service disponibles pour les chauffeurs
  Future<List<Parcel>> getFreeParcels() async {
    try {
      if (isMockMode) return MockData.freeParcels();

      debugPrint('🔓 Récupération des colis en libre service...');
      final response = await _dio.get('/public/parcels/free');
      final responseData = _handleResponse(response);

      if (responseData['success'] == true) {
        final List<dynamic> parcelsData = responseData['parcels'] ?? [];
        debugPrint('✅ ${parcelsData.length} colis en libre service trouvés');

        final parcels = parcelsData
            .map((parcelJson) =>
                Parcel.fromJson(parcelJson as Map<String, dynamic>))
            .toList();

        return parcels;
      }

      debugPrint('⚠️ Aucun colis en libre service trouvé');
      return [];
    } catch (e) {
      debugPrint('❌ Erreur getFreeParcels: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> makeBid(
      String parcelId, Map<String, dynamic> bidData) async {
    try {
      debugPrint('💰 Envoi d\'une offre pour le colis $parcelId');
      debugPrint('📤 bidData reçu: $bidData');

      final data = <String, dynamic>{
        'parcelId': parcelId,
        'price': bidData['price'],
        'message': bidData['message'] ?? '',
      };

      if (bidData['audioUrl'] != null &&
          bidData['audioUrl'].toString().isNotEmpty) {
        data['audioUrl'] = bidData['audioUrl'].toString();
        debugPrint('🎤 Audio URL ajouté à l\'offre: ${data['audioUrl']}');
      }

      if (bidData['audioFile'] != null && bidData['audioFile'] is XFile) {
        try {
          final audioFile = bidData['audioFile'] as XFile;
          debugPrint('🎤 Upload du fichier audio: ${audioFile.path}');

          final audioUrl = await uploadAudio(audioFile, parcelId);

          if (audioUrl != null && audioUrl.isNotEmpty) {
            data['audioUrl'] = audioUrl;
            debugPrint('✅ Audio uploadé avec succès: $audioUrl');
          } else {
            debugPrint('⚠️ Échec upload audio, URL vide');
          }
        } catch (e) {
          debugPrint('❌ Erreur upload audio: $e');
        }
      }

      if (bidData['audioBase64'] != null &&
          bidData['audioBase64'].toString().isNotEmpty) {
        try {
          final response = await _dio.post('/upload/parcel-audio', data: {
            'file': bidData['audioBase64'],
            'parcelId': parcelId,
            'filename': 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
          });
          final responseData = _handleResponse(response);
          if (responseData['success'] == true && responseData['url'] != null) {
            data['audioUrl'] = responseData['url'].toString();
            debugPrint('✅ Audio uploadé avec succès: ${data['audioUrl']}');
          }
        } catch (e) {
          debugPrint('❌ Erreur upload audio base64: $e');
        }
      }

      if (bidData['audioDuration'] != null) {
        data['audioDuration'] = bidData['audioDuration'];
      }

      debugPrint('📤 Données finales envoyées: $data');

      final response = await _dio.post('/driver/bids', data: data);
      final responseData = _handleResponse(response);
      debugPrint('✅ Offre envoyée: ${responseData['success']}');
      return responseData;
    } catch (e) {
      debugPrint('❌ Erreur makeBid: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Upload d'un audio pour une offre
  Future<String?> uploadBidAudio(XFile audio, String parcelId) async {
    try {
      debugPrint('🎤 Upload du message vocal pour l\'offre du colis $parcelId');
      final bytes = await audio.readAsBytes();
      final base64Audio = base64Encode(bytes);

      final response = await _dio.post('/upload/bid-audio', data: {
        'file': base64Audio,
        'parcelId': parcelId,
        'filename': audio.name,
      });

      final responseData = _handleResponse(response);
      if (responseData['success'] == true && responseData['url'] != null) {
        debugPrint('✅ Message vocal uploadé: ${responseData['url']}');
        return responseData['url'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur uploadBidAudio: $e');
      return null;
    }
  }

  /// Accepter une offre (client)
  Future<Map<String, dynamic>> acceptBid(String parcelId, String bidId) async {
    try {
      debugPrint('✅ Acceptation de l\'offre $bidId pour le colis $parcelId');
      final response =
          await _dio.post('/client/parcels/$parcelId/bids/$bidId/accept');
      final responseData = _handleResponse(response);
      debugPrint('✅ Offre acceptée: ${responseData['success']}');
      return responseData;
    } catch (e) {
      debugPrint('❌ Erreur acceptBid: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Refuser une offre (client)
  Future<Map<String, dynamic>> rejectBid(String parcelId, String bidId,
      {String? responseMessage}) async {
    try {
      debugPrint('❌ Refus de l\'offre $bidId pour le colis $parcelId');
      final data = <String, dynamic>{};
      if (responseMessage != null && responseMessage.isNotEmpty) {
        data['responseMessage'] = responseMessage;
      }
      final response = await _dio.post(
        '/client/parcels/$parcelId/bids/$bidId/reject',
        data: data.isEmpty ? null : data,
      );
      final responseData = _handleResponse(response);
      debugPrint('✅ Offre refusée: ${responseData['success']}');
      return responseData;
    } catch (e) {
      debugPrint('❌ Erreur rejectBid: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Mettre un colis en libre service (client)
  Future<Map<String, dynamic>> setParcelFreeForBidding(String parcelId,
      {double? proposedPrice}) async {
    try {
      debugPrint('🔓 Mise en libre service du colis $parcelId');
      final data = <String, dynamic>{'isFreeForBidding': true};
      if (proposedPrice != null) {
        data['proposedPrice'] = proposedPrice;
      }
      final response = await _dio
          .patch('/client/parcels/$parcelId/free-bidding', data: data);
      final responseData = _handleResponse(response);
      debugPrint('✅ Colis en libre service: ${responseData['success']}');
      return responseData;
    } catch (e) {
      debugPrint('❌ Erreur setParcelFreeForBidding: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Récupérer les offres d'un colis
  Future<List<Map<String, dynamic>>> getParcelBids(String parcelId) async {
    try {
      debugPrint('📊 Récupération des offres pour le colis $parcelId');
      final response = await _dio.get('/public/parcels/$parcelId/bids');
      final responseData = _handleResponse(response);

      if (responseData['success'] == true) {
        final List<dynamic> bidsData = responseData['bids'] ?? [];
        debugPrint('✅ ${bidsData.length} offres trouvées');
        return bidsData.map((json) => json as Map<String, dynamic>).toList();
      }

      return [];
    } catch (e) {
      debugPrint('❌ Erreur getParcelBids: $e');
      return [];
    }
  }

  /// Annuler un colis (client)
  Future<Map<String, dynamic>> cancelParcel(String parcelId,
      {String? reason}) async {
    try {
      debugPrint('❌ Annulation du colis $parcelId');
      final data = <String, dynamic>{};
      if (reason != null) {
        data['reason'] = reason;
      }
      final response =
          await _dio.post('/client/parcels/$parcelId/cancel', data: data);
      final responseData = _handleResponse(response);
      debugPrint('✅ Colis annulé: ${responseData['success']}');
      return responseData;
    } catch (e) {
      debugPrint('❌ Erreur cancelParcel: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Obtenir les statistiques de marchandage pour un client
  Future<Map<String, dynamic>> getBiddingStats() async {
    try {
      debugPrint('📊 Récupération des statistiques de marchandage');
      final response = await _dio.get('/client/bids/stats');
      final responseData = _handleResponse(response);
      return responseData;
    } catch (e) {
      debugPrint('❌ Erreur getBiddingStats: $e');
      return {'success': false, 'message': e.toString(), 'stats': {}};
    }
  }

  /// Négocier une offre (contre-offre)
  Future<Map<String, dynamic>> negotiateBid(
      String bidId, double counterPrice, String? message) async {
    try {
      debugPrint(
          '🤝 Négociation de l\'offre $bidId avec contre-offre $counterPrice');
      final response = await _dio.post('/client/bids/$bidId/negotiate', data: {
        'counterPrice': counterPrice,
        'message': message,
      });
      final responseData = _handleResponse(response);
      debugPrint('✅ Contre-offre envoyée: ${responseData['success']}');
      return responseData;
    } catch (e) {
      debugPrint('❌ Erreur negotiateBid: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Récupérer les offres reçues par un client
  Future<List<Map<String, dynamic>>> getClientReceivedBids(
      {String? status}) async {
    try {
      debugPrint('📥 Récupération des offres reçues par le client');
      final queryParams =
          status != null ? {'status': status} : <String, dynamic>{};
      final response =
          await _dio.get('/client/bids/received', queryParameters: queryParams);
      final responseData = _handleResponse(response);

      if (responseData['success'] == true) {
        final List<dynamic> bidsData = responseData['bids'] ?? [];
        return bidsData.map((json) => json as Map<String, dynamic>).toList();
      }

      return [];
    } catch (e) {
      debugPrint('❌ Erreur getClientReceivedBids: $e');
      return [];
    }
  }

  /// Récupérer les offres envoyées par un chauffeur
  Future<List<Map<String, dynamic>>> getDriverSentBids({String? status}) async {
    try {
      debugPrint('📤 Récupération des offres envoyées par le chauffeur');
      final queryParams =
          status != null ? {'status': status} : <String, dynamic>{};
      final response =
          await _dio.get('/driver/bids/sent', queryParameters: queryParams);
      final responseData = _handleResponse(response);

      if (responseData['success'] == true) {
        final List<dynamic> bidsData = responseData['bids'] ?? [];
        return bidsData.map((json) => json as Map<String, dynamic>).toList();
      }

      return [];
    } catch (e) {
      debugPrint('❌ Erreur getDriverSentBids: $e');
      return [];
    }
  }

  // ==================== GESTION DES POINTS (SCORE) ====================

  /// Récupérer le score de l'utilisateur connecté
  Future<Map<String, dynamic>> getUserScore() async {
    try {
      debugPrint('📊 Récupération du score utilisateur...');
      final response = await _dio.get('/score');

      // Certains backends/proxys renvoient une page HTML en 404. On évite de
      // tenter un jsonDecode dessus afin de conserver une erreur métier stable.
      if (response.data is String) {
        final body = (response.data as String).trimLeft();
        if (!body.startsWith('{') && !body.startsWith('[')) {
          return {
            'success': false,
            'message': 'Route /score indisponible (${response.statusCode})',
          };
        }
      }

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur getUserScore: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Récupérer le solde de points
  Future<Map<String, dynamic>> getBalance() async {
    try {
      debugPrint('💰 Récupération du solde...');
      final response = await _dio.get('/score/balance');
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur getBalance: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Récupérer l'historique des transactions
  Future<Map<String, dynamic>> getScoreHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      debugPrint('📜 Récupération de l\'historique des transactions...');
      final response = await _dio.get('/score/history', queryParameters: {
        'page': page,
        'limit': limit,
      });
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur getScoreHistory: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Acheter des points
  Future<Map<String, dynamic>> purchasePoints({
    required int amount,
    required String paymentMethod,
    String? paymentReference,
  }) async {
    try {
      debugPrint('🛒 Achat de $amount points...');
      final response = await _dio.post('/score/purchase', data: {
        'amount': amount,
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
      });
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur purchasePoints: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Débiter des points (utilisation interne)
  Future<Map<String, dynamic>> debitPoints({
    required String userId,
    required int amount,
    required String type,
    required String parcelId,
    required String description,
  }) async {
    try {
      debugPrint('➖ Débit de $amount points pour $userId...');
      final response = await _dio.post('/score/debit', data: {
        'userId': userId,
        'amount': amount,
        'type': type,
        'parcelId': parcelId,
        'description': description,
      });
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur debitPoints: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Créditer des points (utilisation interne)
  Future<Map<String, dynamic>> creditPoints({
    required String userId,
    required int amount,
    required String type,
    required String description,
    String? parcelId,
  }) async {
    try {
      debugPrint('➕ Crédit de $amount points pour $userId...');
      final response = await _dio.post('/score/credit', data: {
        'userId': userId,
        'amount': amount,
        'type': type,
        'parcelId': parcelId,
        'description': description,
      });
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur creditPoints: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Obtenir les statistiques des points (Admin)
  Future<Map<String, dynamic>> getScoreStats() async {
    try {
      debugPrint('📊 Récupération des statistiques des points...');
      final response = await _dio.get('/score/stats');
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur getScoreStats: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Rembourser une transaction (Admin)
  Future<Map<String, dynamic>> refundTransaction({
    required String userId,
    required String transactionId,
    String? reason,
  }) async {
    try {
      debugPrint('🔄 Remboursement de la transaction $transactionId...');
      final response = await _dio.post('/score/refund', data: {
        'userId': userId,
        'transactionId': transactionId,
        'reason': reason,
      });
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur refundTransaction: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

// ==================== ANNONCES (ADVERTISEMENTS) ====================

  /// Récupérer toutes les annonces (colis en libre service)
  Future<List<Parcel>> getAdvertisements({String? status}) async {
    try {
      debugPrint('📢 Récupération des annonces...');
      final queryParams =
          status != null ? {'status': status} : <String, dynamic>{};
      final response =
          await _dio.get('/advertisements', queryParameters: queryParams);
      final responseData = _handleResponse(response);

      if (responseData['success'] == true) {
        final List<dynamic> adsData = responseData['advertisements'] ?? [];
        debugPrint('✅ ${adsData.length} annonces trouvées');
        return adsData
            .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Erreur getAdvertisements: $e');
      return [];
    }
  }

  /// Récupérer les annonces de l'utilisateur connecté
  Future<List<Parcel>> getMyAdvertisements() async {
    try {
      debugPrint('📢 Récupération de mes annonces...');
      final response = await _dio.get('/advertisements/my');
      final responseData = _handleResponse(response);

      if (responseData['success'] == true) {
        final List<dynamic> adsData = responseData['advertisements'] ?? [];
        debugPrint('✅ ${adsData.length} annonces trouvées');
        return adsData
            .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Erreur getMyAdvertisements: $e');
      return [];
    }
  }

  /// Récupérer les annonces des chauffeurs
  Future<List<Parcel>> getDriverAdvertisements() async {
    try {
      debugPrint('🚚 Récupération des annonces des chauffeurs...');
      final response = await _dio.get('/advertisements/drivers');
      final responseData = _handleResponse(response);

      if (responseData['success'] == true) {
        final List<dynamic> adsData = responseData['advertisements'] ?? [];
        debugPrint('✅ ${adsData.length} annonces chauffeurs trouvées');
        return adsData
            .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Erreur getDriverAdvertisements: $e');
      return [];
    }
  }

  /// Créer une annonce (mettre un colis en libre service)
  Future<Map<String, dynamic>> createAdvertisement({
    required String parcelId,
    required double proposedPrice,
    String? description,
    DateTime? expiryDate,
  }) async {
    try {
      debugPrint('📢 Création d\'une annonce pour le colis $parcelId');
      final response = await _dio.post('/advertisements', data: {
        'parcelId': parcelId,
        'proposedPrice': proposedPrice,
        'description': description,
        'expiryDate': expiryDate?.toIso8601String(),
      });
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur createAdvertisement: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Mettre à jour une annonce
  Future<Map<String, dynamic>> updateAdvertisement({
    required String advertisementId,
    double? proposedPrice,
    String? description,
    DateTime? expiryDate,
    String? status,
  }) async {
    try {
      debugPrint('📢 Mise à jour de l\'annonce $advertisementId');
      final data = <String, dynamic>{};
      if (proposedPrice != null) data['proposedPrice'] = proposedPrice;
      if (description != null) data['description'] = description;
      if (expiryDate != null) data['expiryDate'] = expiryDate.toIso8601String();
      if (status != null) data['status'] = status;

      final response =
          await _dio.put('/advertisements/$advertisementId', data: data);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur updateAdvertisement: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Supprimer une annonce
  Future<Map<String, dynamic>> deleteAdvertisement(
      String advertisementId) async {
    try {
      debugPrint('🗑️ Suppression de l\'annonce $advertisementId');
      final response = await _dio.delete('/advertisements/$advertisementId');
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur deleteAdvertisement: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Récupérer les détails d'une annonce
  Future<Parcel?> getAdvertisementById(String advertisementId) async {
    try {
      debugPrint('📢 Récupération de l\'annonce $advertisementId');
      final response = await _dio.get('/advertisements/$advertisementId');
      final responseData = _handleResponse(response);

      if (responseData['success'] == true &&
          responseData['advertisement'] != null) {
        return Parcel.fromJson(
            responseData['advertisement'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur getAdvertisementById: $e');
      return null;
    }
  }

  /// Faire une offre sur une annonce (chauffeur)
  Future<Map<String, dynamic>> makeOffer({
    required String advertisementId,
    required double price,
    String? message,
    String? audioUrl,
  }) async {
    try {
      debugPrint('💰 Envoi d\'une offre pour l\'annonce $advertisementId');
      final response =
          await _dio.post('/advertisements/$advertisementId/offers', data: {
        'price': price,
        'message': message,
        'audioUrl': audioUrl,
      });
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur makeOffer: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Accepter une offre (client)
  Future<Map<String, dynamic>> acceptOffer({
    required String advertisementId,
    required String offerId,
  }) async {
    try {
      debugPrint(
          '✅ Acceptation de l\'offre $offerId pour l\'annonce $advertisementId');
      final response = await _dio
          .post('/advertisements/$advertisementId/offers/$offerId/accept');
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur acceptOffer: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Refuser une offre (client)
  Future<Map<String, dynamic>> rejectOffer({
    required String advertisementId,
    required String offerId,
    String? reason,
  }) async {
    try {
      debugPrint(
          '❌ Refus de l\'offre $offerId pour l\'annonce $advertisementId');
      final response = await _dio.post(
          '/advertisements/$advertisementId/offers/$offerId/reject',
          data: {'reason': reason});
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur rejectOffer: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Récupérer les offres d'une annonce
  Future<List<Map<String, dynamic>>> getOffers(String advertisementId) async {
    try {
      debugPrint('📊 Récupération des offres pour l\'annonce $advertisementId');
      final response =
          await _dio.get('/advertisements/$advertisementId/offers');
      final responseData = _handleResponse(response);

      if (responseData['success'] == true) {
        final List<dynamic> offersData = responseData['offers'] ?? [];
        return offersData.map((json) => json as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Erreur getOffers: $e');
      return [];
    }
  }

  /// Mettre fin à une annonce (client)
  Future<Map<String, dynamic>> closeAdvertisement(
      String advertisementId) async {
    try {
      debugPrint('🔒 Fermeture de l\'annonce $advertisementId');
      final response =
          await _dio.post('/advertisements/$advertisementId/close');
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur closeAdvertisement: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Récupérer les statistiques des annonces
  Future<Map<String, dynamic>> getAdvertisementStats() async {
    try {
      debugPrint('📊 Récupération des statistiques des annonces...');
      final response = await _dio.get('/advertisements/stats');
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Erreur getAdvertisementStats: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== WEBHOOKS ====================

  Future<Map<String, dynamic>> registerWebhook(
      {required String url, required List<String> events}) async {
    try {
      final response =
          await _dio.post('/webhooks', data: {'url': url, 'events': events});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getWebhooks() async {
    try {
      final response = await _dio.get('/webhooks');
      final responseData = _handleResponse(response);
      final List<dynamic> webhooksData = responseData['webhooks'] ?? [];
      return webhooksData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Erreur getWebhooks: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> deleteWebhook(String webhookId) async {
    try {
      final response = await _dio.delete('/webhooks/$webhookId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
