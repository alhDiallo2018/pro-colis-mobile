import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/broadcast.dart';

class BroadcastService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:18081/api/v1',
  );

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

  Future<List<Broadcast>> fetchActiveBroadcasts() async {
    try {
      final token = await _token;
      final response = await _dio.get(
        '/super-admin/config',
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      final data = _handleResponse(response);
      final config = data['config'] as Map<String, dynamic>? ?? (data['data'] as Map<String, dynamic>? ?? {});
      final raw = config['broadcasts'];
      if (raw is List && raw.isNotEmpty) {
        final broadcasts = raw.map((b) => Broadcast.fromJson(b as Map<String, dynamic>)).toList();
        _cacheBroadcasts(broadcasts);
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
      await _dio.put(
        '/super-admin/config',
        data: {'broadcasts': broadcasts.map((b) => b.toJson()).toList()},
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      _cacheBroadcasts(broadcasts);
    } catch (_) {}
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
      return list.map((e) => Broadcast.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _handleResponse(Response response) {
    if (response.data is String) return jsonDecode(response.data as String);
    if (response.data is Map) return Map<String, dynamic>.from(response.data as Map);
    return {};
  }
}
