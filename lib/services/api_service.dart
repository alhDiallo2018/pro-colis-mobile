// mobile/lib/services/api_service.dart
// Aligné sur l'API Web ProColis (React/TypeScript)

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/garage.dart';
import '../models/parcel.dart';
import '../models/user.dart';
import 'mock_data.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:18081/api/v1',
  );

  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();

  static const bool isMockMode = MockData.enabled;

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
          debugPrint('PUBLIC ${options.method} ${options.path}');
          return handler.next(options);
        }
        final token = await _storage.read(key: 'token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        if (response.statusCode == 401 &&
            !_isPublicRoute(response.requestOptions.path) &&
            response.requestOptions.extra['retriedAfterRefresh'] != true) {
          final refreshedToken = await _refreshAccessToken();
          if (refreshedToken != null && refreshedToken.isNotEmpty) {
            final retryOptions = response.requestOptions;
            retryOptions.extra['retriedAfterRefresh'] = true;
            retryOptions.headers['Authorization'] = 'Bearer $refreshedToken';
            final retryResponse =
                await _retryRequestWithToken(retryOptions, refreshedToken);
            return handler.resolve(retryResponse);
          }
          await clearToken();
        }
        return handler.next(response);
      },
      onError: (DioError error, handler) async {
        final statusCode = error.response?.statusCode;
        final path = error.requestOptions.path;
        if (statusCode == 401 && !_isPublicRoute(path)) {
          await clearToken();
        }
        return handler.next(error);
      },
    ));
  }

  static const Set<String> _publicRoutes = {
    '/auth/register',
    '/auth/login-with-pin',
    '/auth/refresh',
    '/public/',
    '/health',
  };

  bool _isPublicRoute(String path) =>
      _publicRoutes.any((route) => path.startsWith(route));

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
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
      if (response.statusCode == 200 && responseData['accessToken'] != null) {
        await _storeAuthTokens(responseData);
        return responseData['accessToken']?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Response<dynamic>> _retryRequestWithToken(
    RequestOptions requestOptions,
    String accessToken,
  ) async {
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

  Future<void> _storeAuthTokens(Map<String, dynamic> responseData) async {
    final accessToken = responseData['accessToken']?.toString();
    final refreshToken = responseData['refreshToken']?.toString();
    if (accessToken != null && accessToken.isNotEmpty) {
      await setToken(accessToken);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: 'refresh_token', value: refreshToken);
    }
  }

  Future<String?> getToken() async => await _storage.read(key: 'token');

  Future<void> setToken(String token) async {
    await _storage.write(key: 'token', value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'mock_user_id');
  }

  Map<String, dynamic> _handleResponse(Response response) {
    if (response.data is String) {
      return jsonDecode(response.data as String);
    }
    return response.data as Map<String, dynamic>;
  }

  Future<void> logout() async => await clearToken();

  // ==================== AUTH ====================

  Future<Map<String, dynamic>> loginWithPin(
      String pin, String identifier) async {
    try {
      if (isMockMode) {
        final user = MockData.findUserByIdentifier(identifier);
        if (user == null || pin != MockData.pin) {
          return {
            'success': false,
            'message': 'PIN incorrect. Mock PIN: ${MockData.pin}',
          };
        }
        await setToken('mock-token-${user.id}');
        await _storage.write(key: 'mock_user_id', value: user.id);
        return MockData.loginPayload(user);
      }
      final response = await _dio.post('/auth/login-with-pin', data: {
        'identifier': identifier,
        'pin': pin,
      });
      final responseData = _handleResponse(response);
      if (responseData['accessToken'] != null) {
        await _storeAuthTokens(responseData);
      }
      return responseData;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    try {
      if (isMockMode) {
        return {
          'success': true,
          'userId': 'mock-new-user',
          'user': {'id': 'mock-new-user', 'fullName': payload['fullName'], 'role': payload['role'] ?? 'client'},
        };
      }
      final response = await _dio.post('/auth/register', data: payload);
      final responseData = _handleResponse(response);
      if (responseData['accessToken'] != null) {
        await _storeAuthTokens(responseData);
      }
      return responseData;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

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
      if (responseData['user'] != null) {
        return User.fromJson(responseData['user']);
      }
      throw Exception('Utilisateur non trouvé');
    } catch (e) {
      rethrow;
    }
  }

  // ==================== PARCELS ====================

  Future<List<Parcel>> getMyParcels({String? status}) async {
    try {
      if (isMockMode) {
        final user = await getCurrentUser();
        final parcels = MockData.parcelsForUser(user);
        if (status == null || status.isEmpty) return parcels;
        return parcels.where((p) => p.status.value == status).toList();
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
      return [];
    }
  }

  Future<Parcel> getClientParcel(String parcelId) async {
    final response = await _dio.get('/client/parcels/$parcelId');
    final responseData = _handleResponse(response);
    if (responseData['parcel'] != null) {
      return Parcel.fromJson(responseData['parcel']);
    }
    throw Exception('Colis non trouvé');
  }

  Future<String> getDeliveryCode(String parcelId) async {
    final response = await _dio.get('/client/parcels/$parcelId/delivery-code');
    final responseData = _handleResponse(response);
    return responseData['code']?.toString() ?? '';
  }

  Future<Parcel> createParcel(Map<String, dynamic> data) async {
    try {
      if (isMockMode) {
        return MockData.parcels.first;
      }
      final response =
          await _dio.post('/client/parcels/create', data: data);
      final responseData = _handleResponse(response);
      if (responseData['parcel'] != null) {
        return Parcel.fromJson(responseData['parcel']);
      }
      throw Exception('Colis non créé');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelParcel(String parcelId,
      {String? reason}) async {
    try {
      final response =
          await _dio.post('/client/parcels/$parcelId/cancel', data: {
        if (reason != null) 'reason': reason,
      });
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Parcel>> getFreeParcels() async {
    try {
      if (isMockMode) return MockData.freeParcels();
      final response = await _dio.get('/public/parcels/free');
      final responseData = _handleResponse(response);
      final List<dynamic> parcelsData = responseData['parcels'] ?? [];
      return parcelsData
          .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Parcel> trackParcel(String trackingNumber) async {
    final response = await _dio.get('/public/parcels/track/$trackingNumber');
    final responseData = _handleResponse(response);
    if (responseData['parcel'] != null) {
      return Parcel.fromJson(responseData['parcel']);
    }
    throw Exception(responseData['message'] ?? 'Colis non trouvé');
  }

  Future<List<ParcelEvent>> getParcelTimeline(String parcelId) async {
    try {
      final response = await _dio.get('/parcels/$parcelId/timeline');
      final responseData = _handleResponse(response);
      final List<dynamic> eventsData =
          responseData['events'] ?? responseData['timeline'] ?? [];
      return eventsData.map((event) {
        final json = Map<String, dynamic>.from(event);
        return ParcelEvent(
          id: json['id']?.toString() ?? '',
          parcelId: json['parcelId']?.toString() ?? '',
          status: ParcelStatus.fromString(
              json['status']?.toString() ?? 'pending'),
          description: json['description']?.toString() ?? '',
          location: json['location']?.toString(),
          userId: json['userId']?.toString(),
          userName: json['userName']?.toString(),
          userRole: json['userRole']?.toString(),
          photoUrl: json['photoUrl']?.toString(),
          metadata: json['metadata'] is Map
              ? Map<String, dynamic>.from(json['metadata'])
              : {},
          timestamp: json['timestamp'] != null
              ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== BIDS ====================

  Future<Map<String, dynamic>> createBid(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/driver/bids', data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getClientReceivedBids() async {
    try {
      final response = await _dio.get('/client/bids/received');
      final responseData = _handleResponse(response);
      final List<dynamic> bidsData = responseData['bids'] ?? [];
      return bidsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getParcelBids(String parcelId) async {
    try {
      final response = await _dio.get('/public/parcels/$parcelId/bids');
      final responseData = _handleResponse(response);
      final List<dynamic> bidsData = responseData['bids'] ?? [];
      return bidsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> acceptBid(
      String parcelId, String bidId) async {
    try {
      final response =
          await _dio.post('/client/parcels/$parcelId/bids/$bidId/accept');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> rejectBid(String parcelId, String bidId,
      {String? responseMessage}) async {
    try {
      final response = await _dio.post(
        '/client/parcels/$parcelId/bids/$bidId/reject',
        data: responseMessage != null ? {'responseMessage': responseMessage} : null,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> negotiateBid(
      String bidId, Map<String, dynamic> data) async {
    try {
      final response =
          await _dio.post('/client/bids/$bidId/negotiate', data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== ADVERTISEMENTS ====================

  Future<Map<String, dynamic>> createAdvertisement(
      Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/advertisements', data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getAdvertisements(
      {Map<String, dynamic>? params}) async {
    try {
      final response =
          await _dio.get('/advertisements', queryParameters: params);
      final responseData = _handleResponse(response);
      final List<dynamic> adsData = responseData['advertisements'] ?? [];
      return adsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getAdvertisementDetail(
      String advertisementId) async {
    final response = await _dio.get('/advertisements/$advertisementId');
    final responseData = _handleResponse(response);
    return responseData['advertisement'] ?? responseData;
  }

  Future<List<Map<String, dynamic>>> getMyAdvertisements() async {
    try {
      final response = await _dio.get('/advertisements/my');
      final responseData = _handleResponse(response);
      final List<dynamic> adsData = responseData['advertisements'] ?? [];
      return adsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> closeAdvertisement(
      String advertisementId) async {
    try {
      final response =
          await _dio.post('/advertisements/$advertisementId/close');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createAdvertisementOffer(
      String advertisementId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
          '/advertisements/$advertisementId/offers',
          data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> acceptAdvertisementOffer(
      String advertisementId, String offerId) async {
    try {
      final response = await _dio
          .post('/advertisements/$advertisementId/offers/$offerId/accept');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> rejectAdvertisementOffer(
      String advertisementId, String offerId) async {
    try {
      final response = await _dio
          .post('/advertisements/$advertisementId/offers/$offerId/reject');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> negotiateAdvertisementOffer(
      String advertisementId, String offerId,
      Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
          '/advertisements/$advertisementId/offers/$offerId/negotiate',
          data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== DRIVER ====================

  Future<List<Parcel>> getDriverParcels() async {
    try {
      if (isMockMode) {
        final user = await getCurrentUser();
        return MockData.parcelsForUser(user)
            .where((p) => p.driverId == user.id)
            .toList();
      }
      final response = await _dio.get('/driver/parcels');
      final responseData = _handleResponse(response);
      final List<dynamic> parcelsData = responseData['parcels'] ?? [];
      return parcelsData
          .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDriverBidsSent() async {
    try {
      final response = await _dio.get('/driver/bids/sent');
      final responseData = _handleResponse(response);
      final List<dynamic> bidsData = responseData['bids'] ?? [];
      return bidsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  // Lifecycle steps: confirm, pickup, transit, arrived, out-for-delivery, deliver
  Future<Map<String, dynamic>> advanceParcel(
      String parcelId, String step, {String? location, String? otp}) async {
    try {
      final data = <String, dynamic>{};
      if (location != null) data['location'] = location;
      if (otp != null) data['otp'] = otp;
      final response = await _dio.put(
        '/driver/parcels/$parcelId/$step',
        data: data.isEmpty ? null : data,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> driverDeliver(
      String parcelId, Map<String, dynamic> data) async {
    try {
      final response =
          await _dio.put('/driver/parcels/$parcelId/deliver', data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== GARAGE ADMIN ====================

  Future<List<Parcel>> getGarageParcels({String? status}) async {
    try {
      if (isMockMode) {
        final user = await getCurrentUser();
        return MockData.parcelsForUser(user);
      }
      final response = await _dio.get('/garage-admin/parcels');
      final responseData = _handleResponse(response);
      final List<dynamic> parcelsData = responseData['parcels'] ?? [];
      return parcelsData
          .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
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

  Future<List<User>> getGarageColleagues(String garageId) async {
    try {
      final response = await _dio.get('/public/drivers/garage/$garageId');
      final responseData = _handleResponse(response);
      final List<dynamic> driversData = responseData['drivers'] ?? [];
      return driversData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== SUPER ADMIN ====================

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
      return [];
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
      return [];
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
      return [];
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

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final response = await _dio.get('/super-admin/stats');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAdminConfig() async {
    try {
      final response = await _dio.get('/super-admin/config');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateAdminConfig(
      Map<String, dynamic> config) async {
    try {
      final response = await _dio.put('/super-admin/config', data: config);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== GARAGES (PUBLIC) ====================

  Future<List<Garage>> getAllGarages() async {
    try {
      final response = await _dio.get('/public/garages');
      final responseData = _handleResponse(response);
      final List<dynamic> garagesData = responseData['garages'] ?? [];
      return garagesData
          .map((json) => Garage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== USERS / PROFILE ====================

  Future<Map<String, dynamic>> updateProfile(
      UserRole role, Map<String, dynamic> data) async {
    try {
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
      final response = await _dio.put(endpoint, data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changePin(
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

  Future<Map<String, dynamic>> updateDriverStatus(String status) async {
    try {
      final response = await _dio.put('/driver/profile',
          data: {'driverStatus': status});
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== VEHICLES ====================

  Future<Map<String, dynamic>?> getDriverVehicle() async {
    try {
      final response = await _dio.get('/driver/vehicle');
      final responseData = _handleResponse(response);
      if (responseData['vehicle'] != null) {
        return responseData['vehicle'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> upsertVehicle(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/driver/vehicle', data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== MESSAGES ====================

  Future<List<Map<String, dynamic>>> getMessagesThread(
      String peerId, {String? parcelId}) async {
    try {
      final response = await _dio.get('/messages/thread',
          queryParameters: {
            'peerId': peerId,
            if (parcelId != null) 'parcelId': parcelId,
          });
      final responseData = _handleResponse(response);
      final List<dynamic> messagesData = responseData['messages'] ?? [];
      return messagesData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> sendMessage(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/messages', data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final response = await _dio.get('/messages/conversations');
      final responseData = _handleResponse(response);
      final List<dynamic> convsData =
          responseData['conversations'] ?? responseData['messages'] ?? [];
      return convsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== NOTIFICATIONS ====================

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 20}) async {
    try {
      final response =
          await _dio.get('/notifications', queryParameters: {'limit': limit});
      final responseData = _handleResponse(response);
      final List<dynamic> notifsData = responseData['notifications'] ?? [];
      return notifsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> getUnreadNotificationsCount() async {
    try {
      if (isMockMode) return 3;
      final response = await _dio.get('/notifications/unread-count');
      final responseData = _handleResponse(response);
      return responseData['unreadCount'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final response =
          await _dio.patch('/notifications/$notificationId/read');
      return _handleResponse(response)['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAllNotificationsAsRead() async {
    try {
      final response = await _dio.post('/notifications/read-all');
      return _handleResponse(response)['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ==================== PAYMENTS ====================

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final response = await _dio.get('/payments/history');
      final responseData = _handleResponse(response);
      final List<dynamic> paymentsData = responseData['payments'] ?? [];
      return paymentsData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== SCORE / POINTS ====================

  Future<double> getScoreBalance() async {
    try {
      final response = await _dio.get('/score/balance');
      final responseData = _handleResponse(response);
      final double? balance = responseData['balance']?.toDouble();
      return balance ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getScoreHistory() async {
    try {
      final response = await _dio.get('/score/history');
      final responseData = _handleResponse(response);
      final List<dynamic> txData =
          responseData['transactions'] ?? responseData['history'] ?? [];
      return txData.map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> purchasePoints(
      Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/score/purchase', data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== UPLOADS ====================

  /// Upload a file as multipart/form-data. Returns the file URL.
  Future<String?> uploadFile({
    required XFile file,
    required String mediaType, // 'photo', 'video', 'audio'
    String? parcelId,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
        'mediaType': mediaType,
        if (parcelId != null) 'parcelId': parcelId,
      });
      final response = await _dio.post('/upload', data: formData);
      final responseData = _handleResponse(response);
      if (responseData['url'] != null) {
        return responseData['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Upload chat audio blob. Returns the file URL.
  Future<String?> uploadChatAudio(XFile file) async {
    return uploadFile(file: file, mediaType: 'audio');
  }

  // ==================== PUBLIC DRIVERS ====================

  Future<List<User>> searchDriversPublic({String? query}) async {
    try {
      final queryParams =
          query != null ? {'query': query} : <String, dynamic>{};
      final response = await _dio.get('/public/drivers/search',
          queryParameters: queryParams);
      final responseData = _handleResponse(response);
      final List<dynamic> driversData = responseData['drivers'] ?? [];
      return driversData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Parcel>> getAllParcels({String? status}) async {
    try {
      if (isMockMode) return MockData.parcels;
      final queryParams =
          status != null ? {'status': status} : <String, dynamic>{};
      final response =
          await _dio.get('/super-admin/parcels', queryParameters: queryParams);
      final responseData = _handleResponse(response);
      final List<dynamic> parcelsData = responseData['parcels'] ?? [];
      return parcelsData
          .map((json) => Parcel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== PARCEL DETAIL (role-based) ====================

  /// Récupère un colis par son ID selon le rôle courant.
  Future<Parcel?> getParcelById(String parcelId) async {
    try {
      final currentUser = await getCurrentUser();
      String endpoint;
      switch (currentUser.role) {
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
      if (responseData['parcel'] != null) {
        return Parcel.fromJson(responseData['parcel']);
      }
      if (responseData['id'] != null) {
        return Parcel.fromJson(responseData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== SUPER ADMIN CRUD ====================

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
      final response =
          await _dio.put('/super-admin/users/$userId', data: {
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

  Future<Map<String, dynamic>> deleteUserSuperAdmin(String userId) async {
    try {
      final response = await _dio.delete('/super-admin/users/$userId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetUserPinAdmin(String userId) async {
    try {
      final response =
          await _dio.post('/super-admin/users/$userId/reset-pin');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
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
      final response =
          await _dio.put('/super-admin/garages/$garageId', data: {
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

  Future<Map<String, dynamic>> deleteGarageSuperAdmin(
      String garageId) async {
    try {
      final response = await _dio.delete('/super-admin/garages/$garageId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<User>> getAllDriversSuperAdmin() async {
    try {
      if (isMockMode) return MockData.drivers;
      final response = await _dio.get('/super-admin/users');
      final responseData = _handleResponse(response);
      final List<dynamic> usersData = responseData['users'] ?? [];
      return usersData
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .where((u) => u.role == UserRole.driver)
          .toList();
    } catch (e) {
      return [];
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

  Future<Map<String, dynamic>> deleteParcelAdmin(String parcelId) async {
    try {
      final response = await _dio.delete('/garage-admin/parcels/$parcelId');
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadAndUpdateProfilePhoto(
      XFile file) async {
    try {
      final photoUrl =
          await uploadFile(file: file, mediaType: 'photo');
      if (photoUrl == null) {
        return {'success': false, 'message': 'Erreur upload'};
      }
      final currentUser = await getCurrentUser();
      return await updateProfile(currentUser.role, {'profilePhoto': photoUrl});
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateProfileByRole(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
