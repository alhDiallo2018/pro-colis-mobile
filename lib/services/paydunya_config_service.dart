import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PaydunyaConfig {
  final String masterKey;
  final String privateKey;
  final String token;
  final String mode;
  final String storeName;
  final bool configured;

  const PaydunyaConfig({
    this.masterKey = '',
    this.privateKey = '',
    this.token = '',
    this.mode = 'test',
    this.storeName = '',
    this.configured = false,
  });

  factory PaydunyaConfig.fromJson(Map<String, dynamic> json) {
    return PaydunyaConfig(
      masterKey: json['masterKey']?.toString() ?? '',
      privateKey: json['privateKey']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'test',
      storeName: json['storeName']?.toString() ?? '',
      configured: json['configured'] == true,
    );
  }
}

class PaydunyaConfigService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:18081/api/v1',
  );

  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  PaydunyaConfigService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              headers: {'Content-Type': 'application/json'},
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (status) => status! < 500,
            ));

  Future<PaydunyaConfig?> getPaydunyaConfig() async {
    try {
      final token = await _storage.read(key: 'token');
      final response = await _dio.get(
        '/admin/payments/paydunya-config',
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      final rd = _handleResponse(response);
      final config = rd['config'] as Map<String, dynamic>?;
      if (config != null) return PaydunyaConfig.fromJson(config);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<PaydunyaConfig?> updatePaydunyaConfig(Map<String, dynamic> config) async {
    try {
      final token = await _storage.read(key: 'token');
      final response = await _dio.put(
        '/admin/payments/paydunya-config',
        data: config,
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      final rd = _handleResponse(response);
      final c = rd['config'] as Map<String, dynamic>?;
      if (c != null) return PaydunyaConfig.fromJson(c);
      return null;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> _handleResponse(Response response) {
    if (response.data is String) return jsonDecode(response.data as String);
    if (response.data is Map) return Map<String, dynamic>.from(response.data as Map);
    return {};
  }
}
