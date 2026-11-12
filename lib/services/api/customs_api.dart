// lib/services/api/customs_api.dart
//
// Phase 5 — Déclarations douanières (SCP-040) : CRUD + sign.

import 'package:dio/dio.dart';

import 'client.dart';

class ParcelCustoms {
  final String id;
  final String parcelId;
  final String originCountry;
  final String destinationCountry;
  final String contentsDescription;
  final String? hsCode;
  final double declaredValue;
  final String declaredCurrency;
  final double? weightKg;
  final int quantity;
  final String? category;
  final String purpose;
  final bool isDangerous;
  final List<String> documentsUrls;
  final DateTime? signedAt;
  final String? signedById;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ParcelCustoms({
    required this.id,
    required this.parcelId,
    required this.originCountry,
    required this.destinationCountry,
    required this.contentsDescription,
    this.hsCode,
    required this.declaredValue,
    this.declaredCurrency = 'XOF',
    this.weightKg,
    this.quantity = 1,
    this.category,
    this.purpose = 'personal',
    this.isDangerous = false,
    this.documentsUrls = const [],
    this.signedAt,
    this.signedById,
    this.createdAt,
    this.updatedAt,
  });

  bool get isSigned => signedAt != null;

  factory ParcelCustoms.fromJson(Map<String, dynamic> json) => ParcelCustoms(
        id: json['id']?.toString() ?? '',
        parcelId: json['parcelId']?.toString() ?? '',
        originCountry: json['originCountry']?.toString() ?? '',
        destinationCountry: json['destinationCountry']?.toString() ?? '',
        contentsDescription: json['contentsDescription']?.toString() ?? '',
        hsCode: json['hsCode']?.toString(),
        declaredValue: (json['declaredValue'] as num?)?.toDouble() ?? 0,
        declaredCurrency: json['declaredCurrency']?.toString() ?? 'XOF',
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        category: json['category']?.toString(),
        purpose: json['purpose']?.toString() ?? 'personal',
        isDangerous: json['isDangerous'] == true,
        documentsUrls: (json['documentsUrls'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        signedAt: DateTime.tryParse(json['signedAt']?.toString() ?? ''),
        signedById: json['signedById']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );
}

class CustomsApi {
  final ApiClient client;

  CustomsApi(this.client);

  Future<ParcelCustoms?> get(String parcelId) async {
    final res = await client.dio.get('/parcels/$parcelId/customs');
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final c = (payload['customs'] as Map?)?.cast<String, dynamic>();
    if (c == null) return null;
    return ParcelCustoms.fromJson(c);
  }

  Future<ParcelCustoms> createOrUpdate(String parcelId, Map<String, dynamic> body,
      {bool existing = false}) async {
    final method = existing ? 'PUT' : 'POST';
    final res = await client.dio.request(
      '/parcels/$parcelId/customs',
      data: body,
      options: Options(method: method),
    );
    final parsed = client.handle(res);
    final payload = (parsed['data'] as Map?)?.cast<String, dynamic>() ?? parsed;
    final c = (payload['customs'] as Map?)?.cast<String, dynamic>() ?? {};
    return ParcelCustoms.fromJson(c);
  }

  Future<ParcelCustoms> sign(String parcelId) async {
    final res = await client.dio.post('/parcels/$parcelId/customs/sign');
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final c = (payload['customs'] as Map?)?.cast<String, dynamic>() ?? {};
    return ParcelCustoms.fromJson(c);
  }
}
