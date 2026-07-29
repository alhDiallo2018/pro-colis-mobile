import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/broadcast.dart';

class BroadcastService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  static const String _cacheKey = 'procolis-broadcasts';

  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  BroadcastService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              headers: {'Content-Type': 'application/json'},
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (status) => status! < 500,
            ));

  Future<String?> get _token async {
    return await _storage.read(key: 'token');
  }

  /// Les annonces sont lues sur un endpoint public : `/super-admin/config`
  /// reste réservé au super-admin et ne doit servir qu'à l'écriture.
  Future<List<Broadcast>> fetchActiveBroadcasts() async {
    try {
      final token = await _token;
      final response = await _dio.get(
        '/public/broadcasts',
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      final data = _handleResponse(response);
      final config = data['config'] as Map<String, dynamic>? ??
          (data['data'] as Map<String, dynamic>? ?? {});
      final raw = data['broadcasts'] ?? config['broadcasts'];
      if (raw is List) {
        final broadcasts = raw
            .whereType<Map>()
            .map((b) => Broadcast.fromJson(Map<String, dynamic>.from(b)))
            .toList();
        await _cacheBroadcasts(broadcasts);
        return broadcasts;
      }
    } catch (_) {}

    return _loadCachedBroadcasts();
  }

  Future<List<Broadcast>> adminLoadBroadcasts() async {
    return fetchActiveBroadcasts();
  }

  Future<void> adminSaveBroadcasts(List<Broadcast> broadcasts) async {
    try {
      final token = await _token;
      final response = await _dio.put(
        '/super-admin/config',
        data: {'broadcasts': broadcasts.map((b) => b.toJson()).toList()},
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      if (response.statusCode == null || response.statusCode! >= 400) {
        throw StateError(
          'Échec de la sauvegarde des bandeaux (${response.statusCode}).',
        );
      }
      await _cacheBroadcasts(broadcasts);
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _cacheBroadcasts(List<Broadcast> broadcasts) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final encoded = jsonEncode(broadcasts.map((b) => b.toJson()).toList());
      await sp.setString(_cacheKey, encoded);
    } catch (_) {}
  }

  Future<List<Broadcast>> _loadCachedBroadcasts() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final encoded = sp.getString(_cacheKey);
      if (encoded == null || encoded.isEmpty) return [];
      final list = jsonDecode(encoded) as List<dynamic>;
      return list
          .map((e) => Broadcast.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _handleResponse(Response response) {
    if (response.data is String) return jsonDecode(response.data as String);
    if (response.data is Map)
      return Map<String, dynamic>.from(response.data as Map);
    return {};
  }
}
