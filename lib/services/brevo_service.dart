import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BrevoEmailParams {
  final String to;
  final String? toName;
  final String subject;
  final String htmlContent;
  final String? textContent;
  final List<String>? cc;
  final List<String>? bcc;
  final int? templateId;
  final Map<String, String>? params;

  const BrevoEmailParams({
    required this.to,
    this.toName,
    required this.subject,
    required this.htmlContent,
    this.textContent,
    this.cc,
    this.bcc,
    this.templateId,
    this.params,
  });

  Map<String, dynamic> toJson() => {
        'to': to,
        if (toName != null) 'toName': toName,
        'subject': subject,
        'htmlContent': htmlContent,
        if (textContent != null) 'textContent': textContent,
        if (cc != null) 'cc': cc,
        if (bcc != null) 'bcc': bcc,
        if (templateId != null) 'templateId': templateId,
        if (params != null) 'params': params,
      };
}

class BrevoSmsParams {
  final String to;
  final String content;
  final String? senderName;

  const BrevoSmsParams({
    required this.to,
    required this.content,
    this.senderName,
  });

  Map<String, dynamic> toJson() => {
        'to': to,
        'content': content,
        if (senderName != null) 'senderName': senderName,
      };
}

class BrevoConfig {
  final String provider;
  final String apiKey;
  final String senderEmail;
  final String senderName;
  final String smsSender;

  const BrevoConfig({
    this.provider = 'brevo',
    this.apiKey = '',
    required this.senderEmail,
    required this.senderName,
    required this.smsSender,
  });

  factory BrevoConfig.fromJson(Map<String, dynamic> json) {
    return BrevoConfig(
      provider: json['provider']?.toString() ?? 'brevo',
      apiKey: json['apiKey']?.toString() ?? '',
      senderEmail: json['senderEmail']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      smsSender: json['smsSender']?.toString() ?? '',
    );
  }
}

class SendResult {
  final bool success;
  final String? messageId;
  final String? error;

  const SendResult({required this.success, this.messageId, this.error});

  factory SendResult.fromJson(Map<String, dynamic> json) {
    return SendResult(
      success: json['success'] == true,
      messageId: json['messageId']?.toString(),
      error: json['error']?.toString(),
    );
  }
}

class BrevoService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:18081/api/v1',
  );

  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  BrevoService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              headers: {'Content-Type': 'application/json'},
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (status) => status! < 500,
            ));

  Future<SendResult> sendEmail(BrevoEmailParams params) async {
    try {
      final token = await _storage.read(key: 'token');
      final response = await _dio.post(
        '/notifications/email/send',
        data: params.toJson(),
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      final rd = _handleResponse(response);
      return SendResult.fromJson(rd);
    } catch (e) {
      return SendResult(success: false, error: e.toString());
    }
  }

  Future<SendResult> sendSms(BrevoSmsParams params) async {
    try {
      final token = await _storage.read(key: 'token');
      final response = await _dio.post(
        '/notifications/sms/send',
        data: params.toJson(),
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      final rd = _handleResponse(response);
      return SendResult.fromJson(rd);
    } catch (e) {
      return SendResult(success: false, error: e.toString());
    }
  }

  Future<SendResult> sendBulkEmail({
    required List<Map<String, String>> recipients,
    required String subject,
    required String htmlContent,
  }) async {
    try {
      final token = await _storage.read(key: 'token');
      final response = await _dio.post(
        '/notifications/email/send-bulk',
        data: {
          'recipients': recipients,
          'subject': subject,
          'htmlContent': htmlContent,
        },
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      final rd = _handleResponse(response);
      return SendResult.fromJson(rd);
    } catch (e) {
      return SendResult(success: false, error: e.toString());
    }
  }

  Future<BrevoConfig?> getBrevoConfig() async {
    try {
      final token = await _storage.read(key: 'token');
      final response = await _dio.get(
        '/admin/notifications/brevo-config',
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      final rd = _handleResponse(response);
      final config = rd['config'] as Map<String, dynamic>?;
      if (config != null) return BrevoConfig.fromJson(config);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<BrevoConfig?> updateBrevoConfig(Map<String, dynamic> config) async {
    try {
      final token = await _storage.read(key: 'token');
      final response = await _dio.put(
        '/admin/notifications/brevo-config',
        data: config,
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      final rd = _handleResponse(response);
      final c = rd['config'] as Map<String, dynamic>?;
      if (c != null) return BrevoConfig.fromJson(c);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<SendResult> testBrevoConnection(String testEmail) async {
    try {
      final token = await _storage.read(key: 'token');
      final response = await _dio.post(
        '/admin/notifications/brevo-test',
        data: {'email': testEmail},
        options: Options(headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        }),
      );
      final rd = _handleResponse(response);
      return SendResult.fromJson(rd);
    } catch (e) {
      return SendResult(success: false, error: e.toString());
    }
  }

  Map<String, dynamic> _handleResponse(Response response) {
    if (response.data is String) return jsonDecode(response.data as String);
    if (response.data is Map) return Map<String, dynamic>.from(response.data as Map);
    return {};
  }
}
