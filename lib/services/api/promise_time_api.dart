import 'client.dart';

/// Un créneau de livraison proposé par le backend (promise-time windows).
class PromiseSlot {
  final String id;
  final String slotId;
  final String label;
  final int dayOffset;
  final DateTime startAt;
  final DateTime endAt;

  const PromiseSlot({
    required this.id,
    required this.slotId,
    required this.label,
    required this.dayOffset,
    required this.startAt,
    required this.endAt,
  });

  static PromiseSlot? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final startAt = DateTime.tryParse(json['startAt']?.toString() ?? '');
    final endAt = DateTime.tryParse(json['endAt']?.toString() ?? '');
    if (startAt == null || endAt == null) return null;
    return PromiseSlot(
      id: json['id']?.toString() ?? '',
      slotId: json['slotId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      dayOffset: (json['dayOffset'] is num) ? (json['dayOffset'] as num).toInt() : 0,
      startAt: startAt.toLocal(),
      endAt: endAt.toLocal(),
    );
  }

  /// Libellé jour humain : « Aujourd'hui », « Demain », ou DD/MM.
  String humanDayLabel() {
    if (dayOffset == 0) return "Aujourd'hui";
    if (dayOffset == 1) return 'Demain';
    final d = startAt;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }
}

/// Client de `GET /parcels/promise-slots`. Retourne toujours une liste
/// (vide en cas d'erreur réseau) — jamais d'exception vers l'UI.
class PromiseTimeApi {
  final ApiClient client;
  PromiseTimeApi(this.client);

  Future<List<PromiseSlot>> fetchSlots({double? estimatedTripHours}) async {
    try {
      final response = await client.dio.get(
        '/parcels/promise-slots',
        queryParameters: {
          if (estimatedTripHours != null) 'estimatedTripHours': estimatedTripHours,
        },
      );
      final body = response.data;
      if (body is! Map) return const [];
      final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : null;
      final raw = data?['slots'];
      if (raw is! List) return const [];
      return raw
          .map(PromiseSlot.fromJson)
          .whereType<PromiseSlot>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
