import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:18081/api/v1',
  );

  static String get mediaBaseUrl {
    String b = baseUrl;
    if (b.endsWith('/api/v1')) return b.substring(0, b.length - '/api/v1'.length);
    if (b.endsWith('/api/v1/')) return b.substring(0, b.length - '/api/v1/'.length);
    if (b.endsWith('/api')) return b.substring(0, b.length - '/api'.length);
    return b;
  }

  static String resolveMediaUrl(String url) {
    if (url.startsWith('http')) return url;
    final base = mediaBaseUrl;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }

  final Dio dio;
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  ApiClient({Dio? dioOverride})
      : dio = dioOverride ?? Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status! < 500,
        )) {
    _setupInterceptors();
  }

  static const Set<String> publicRoutes = {
    '/auth/register',
    '/auth/login-with-pin',
    '/auth/refresh',
    '/public/',
    '/health',
  };

  bool isPublicRoute(String path) =>
      publicRoutes.any((route) => path.startsWith(route));

  void _setupInterceptors() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!isPublicRoute(options.path)) {
          final token = await storage.read(key: 'token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            !isPublicRoute(error.requestOptions.path)) {
          await storage.delete(key: 'token');
          await storage.delete(key: 'refresh_token');
        }
        return handler.next(error);
      },
      onResponse: (response, handler) async {
        if (response.statusCode == 401 &&
            !isPublicRoute(response.requestOptions.path) &&
            response.requestOptions.extra['retried'] != true) {
          final rt = await storage.read(key: 'refresh_token');
          if (rt != null && rt.isNotEmpty) {
            final res = await _refresh(rt);
            if (res != null) {
              response.requestOptions.extra['retried'] = true;
              response.requestOptions.headers['Authorization'] = 'Bearer $res';
              try {
                final retryDio = Dio(BaseOptions(
                  baseUrl: baseUrl,
                  connectTimeout: const Duration(seconds: 30),
                ));
                final retry = await retryDio.fetch(response.requestOptions);
                return handler.resolve(retry);
              } catch (_) {}
            }
          }
          await _clearTokens();
        }
        return handler.next(response);
      },
    ));
  }

  Future<String?> _refresh(String refreshToken) async {
    try {
      final rd = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 30),
      ));
      final res = await rd.post('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = _decode(res);
      final at = data['accessToken']?.toString();
      if (at != null) {
        await storage.write(key: 'token', value: at);
        final nrt = data['refreshToken']?.toString();
        if (nrt != null) await storage.write(key: 'refresh_token', value: nrt);
      }
      return at;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearTokens() async {
    await storage.delete(key: 'token');
    await storage.delete(key: 'refresh_token');
  }

  double toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String mediaUrl(String url) => ApiClient.resolveMediaUrl(url);

  Map<String, dynamic> _decode(Response response) {
    if (response.data is String) return jsonDecode(response.data as String);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Map<String, dynamic> handle(Response response) => _decode(response);
}
