import 'dart:convert';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../auth_session.dart';
import '../offline_access.dart';

class ApiClient {
  static const String baseUrl = AppConfig.apiBaseUrl;

  static String get mediaBaseUrl => AppConfig.mediaBaseUrl;

  static String resolveMediaUrl(String url) => AppConfig.resolveMediaUrl(url);

  final Dio dio;

  ApiClient({Dio? dioOverride})
      : dio = dioOverride ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              headers: {'Content-Type': 'application/json'},
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (status) => (status ?? 200) < 500,
            )) {
    // Un Dio injecté appartient à son appelant. `ApiService` lui a déjà
    // installé l'authentification et le refresh : ajouter une seconde chaîne
    // déclencherait deux renouvellements concurrents sur chaque 401.
    if (dioOverride == null) {
      _setupInterceptors();
    }
  }

  void _setupInterceptors() {
    dio.interceptors.add(SessionAuthInterceptor(dio));
    dio.interceptors.add(OfflineAccessInterceptor());
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
