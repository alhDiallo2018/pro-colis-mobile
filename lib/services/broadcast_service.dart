import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/broadcast.dart';

class BroadcastService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:18081/api/v1',
  );

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
      if (raw is! List) return [];
      return raw.map((b) => Broadcast.fromJson(b as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
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
    } catch (_) {}
  }

  Map<String, dynamic> _handleResponse(Response response) {
    if (response.data is String) return jsonDecode(response.data as String);
    if (response.data is Map) return Map<String, dynamic>.from(response.data as Map);
    return {};
  }
}
