// lib/services/api/disputes_api.dart
//
// Gestion formelle des litiges liés à un colis. Workflow côté backend :
//   open → in_review → (resolved | rejected)
//
// Les appels retournent null ou une liste vide si l'endpoint n'est pas
// encore exposé (404) — l'UI gère ces cas en affichant un état vide.

import 'client.dart';

class Dispute {
  final String id;
  final String parcelId;
  final String? parcelTrackingNumber;
  final String status;
  final String category;
  final String? subject;
  final String description;
  final double? claimedAmount;
  final String? currency;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final List<String> attachments;
  final List<DisputeEvent> events;

  const Dispute({
    required this.id,
    required this.parcelId,
    required this.status,
    required this.category,
    required this.description,
    this.parcelTrackingNumber,
    this.subject,
    this.claimedAmount,
    this.currency,
    this.createdAt,
    this.resolvedAt,
    this.resolutionNote,
    this.attachments = const [],
    this.events = const [],
  });

  bool get isOpen => status == 'open' || status == 'in_review';
  bool get isResolved => status == 'resolved';
  bool get isRejected => status == 'rejected';

  factory Dispute.fromJson(Map<String, dynamic> json) => Dispute(
        id: json['id']?.toString() ?? '',
        parcelId: json['parcelId']?.toString() ?? '',
        parcelTrackingNumber: json['parcelTrackingNumber']?.toString(),
        status: json['status']?.toString() ?? 'open',
        category: json['category']?.toString() ?? 'other',
        subject: json['subject']?.toString(),
        description: json['description']?.toString() ?? '',
        claimedAmount: json['claimedAmount'] is num
            ? (json['claimedAmount'] as num).toDouble()
            : null,
        currency: json['currency']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        resolvedAt: DateTime.tryParse(json['resolvedAt']?.toString() ?? ''),
        resolutionNote: json['resolutionNote']?.toString(),
        attachments: (json['attachments'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        events: (json['events'] as List?)
                ?.whereType<Map>()
                .map((e) => DisputeEvent.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

class DisputeEvent {
  final String id;
  final String type;
  final String? actorName;
  final String? message;
  final DateTime? occurredAt;

  const DisputeEvent({
    required this.id,
    required this.type,
    this.actorName,
    this.message,
    this.occurredAt,
  });

  factory DisputeEvent.fromJson(Map<String, dynamic> json) => DisputeEvent(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'comment',
        actorName: json['actorName']?.toString(),
        message: json['message']?.toString(),
        occurredAt: DateTime.tryParse(json['occurredAt']?.toString() ?? ''),
      );
}

class DisputesApi {
  final ApiClient client;
  DisputesApi(this.client);

  Future<List<Dispute>> listMine({String? status}) async {
    try {
      final res = await client.dio.get(
        '/me/disputes',
        queryParameters: {if (status != null) 'status': status},
      );
      final body = client.handle(res);
      final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
      final list = (data['disputes'] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => Dispute.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Dispute?> get(String disputeId) async {
    try {
      final res = await client.dio.get('/disputes/$disputeId');
      final body = client.handle(res);
      final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
      final dispute = (data['dispute'] as Map?)?.cast<String, dynamic>();
      if (dispute == null) return null;
      return Dispute.fromJson(dispute);
    } catch (_) {
      return null;
    }
  }

  Future<Dispute?> open({
    required String parcelId,
    required String category,
    required String description,
    String? subject,
    double? claimedAmount,
    List<String> attachments = const [],
  }) async {
    try {
      final res = await client.dio.post(
        '/parcels/$parcelId/disputes',
        data: {
          'category': category,
          'description': description,
          if (subject != null) 'subject': subject,
          if (claimedAmount != null) 'claimedAmount': claimedAmount,
          if (attachments.isNotEmpty) 'attachments': attachments,
        },
      );
      final body = client.handle(res);
      final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
      final dispute = (data['dispute'] as Map?)?.cast<String, dynamic>();
      if (dispute == null) return null;
      return Dispute.fromJson(dispute);
    } catch (_) {
      return null;
    }
  }

  Future<Dispute?> comment(String disputeId, String message) async {
    try {
      final res = await client.dio.post(
        '/disputes/$disputeId/comments',
        data: {'message': message},
      );
      final body = client.handle(res);
      final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
      final dispute = (data['dispute'] as Map?)?.cast<String, dynamic>();
      if (dispute == null) return null;
      return Dispute.fromJson(dispute);
    } catch (_) {
      return null;
    }
  }
}
