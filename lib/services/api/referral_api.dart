import 'client.dart';

/// Client de `GET /me/referral-code`. Retourne `null` en cas d'erreur
/// réseau — l'UI masquera simplement la carte parrainage.
class ReferralApi {
  final ApiClient client;
  ReferralApi(this.client);

  Future<String?> fetchMyReferralCode() async {
    try {
      final response = await client.dio.get('/me/referral-code');
      final body = response.data;
      if (body is! Map) return null;
      final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : null;
      final code = data?['referralCode'];
      if (code is String && code.isNotEmpty) return code;
      return null;
    } catch (_) {
      return null;
    }
  }
}
