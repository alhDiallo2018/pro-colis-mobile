import 'client.dart';

class ReferralRewards {
  final int totalInvites;
  final int confirmedInvites;
  final double bonusEarned;
  final double bonusAvailable;
  final String? currency;

  const ReferralRewards({
    this.totalInvites = 0,
    this.confirmedInvites = 0,
    this.bonusEarned = 0,
    this.bonusAvailable = 0,
    this.currency,
  });

  factory ReferralRewards.fromJson(Map<String, dynamic> json) =>
      ReferralRewards(
        totalInvites: json['totalInvites'] is num
            ? (json['totalInvites'] as num).toInt()
            : 0,
        confirmedInvites: json['confirmedInvites'] is num
            ? (json['confirmedInvites'] as num).toInt()
            : 0,
        bonusEarned: json['bonusEarned'] is num
            ? (json['bonusEarned'] as num).toDouble()
            : 0,
        bonusAvailable: json['bonusAvailable'] is num
            ? (json['bonusAvailable'] as num).toDouble()
            : 0,
        currency: json['currency']?.toString(),
      );
}

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

  /// Récupère les récompenses de parrainage accumulées. Retourne `null` si
  /// l'endpoint n'existe pas encore (404) — la carte n'affichera alors que
  /// le code sans section rewards.
  Future<ReferralRewards?> fetchRewards() async {
    try {
      final response = await client.dio.get('/me/referral-rewards');
      final body = response.data;
      if (body is! Map) return null;
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      return ReferralRewards.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
