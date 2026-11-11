import 'client.dart';

/// Résultat renvoyé par le backend après appel à l'assistant IA.
///
/// Le backend garantit toujours un `answerText` affichable, même en cas
/// d'erreur (dégradation gracieuse). `draft` et `trackingNumber` peuvent
/// être null selon l'intention détectée.
class AiAssistantResult {
  final String intent;
  final AiParcelDraft? draft;
  final String? trackingNumber;
  final String answerText;
  final bool configured;

  const AiAssistantResult({
    required this.intent,
    required this.answerText,
    required this.configured,
    this.draft,
    this.trackingNumber,
  });

  bool get isCreateParcel => intent == 'create_parcel' && draft != null;
  bool get isTrackParcel => intent == 'track_parcel' && trackingNumber != null;

  factory AiAssistantResult.fromResponse(Map<String, dynamic> body) {
    final data = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : <String, dynamic>{};
    final rawResult = data['result'] is Map
        ? Map<String, dynamic>.from(data['result'] as Map)
        : <String, dynamic>{};
    return AiAssistantResult(
      intent: rawResult['intent']?.toString() ?? 'unknown',
      answerText: rawResult['answerText']?.toString() ?? '',
      draft: AiParcelDraft.fromJson(rawResult['draft']),
      trackingNumber: rawResult['trackingNumber']?.toString(),
      configured: data['configured'] == true,
    );
  }
}

/// Représente l'extrait structuré d'une intention de création de colis.
/// Tous les champs sont optionnels : le mobile prend ce qu'il peut, le
/// reste est demandé à l'utilisateur dans le formulaire pré-rempli.
class AiParcelDraft {
  final String? senderCity;
  final String? receiverCity;
  final String? receiverName;
  final String? receiverPhone;
  final double? weightKg;
  final String? type;
  final bool isUrgent;
  final String? notes;

  const AiParcelDraft({
    this.senderCity,
    this.receiverCity,
    this.receiverName,
    this.receiverPhone,
    this.weightKg,
    this.type,
    this.isUrgent = false,
    this.notes,
  });

  static AiParcelDraft? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    String? asString(dynamic v) {
      if (v is String && v.isNotEmpty) return v;
      return null;
    }

    return AiParcelDraft(
      senderCity: asString(json['senderCity']),
      receiverCity: asString(json['receiverCity']),
      receiverName: asString(json['receiverName']),
      receiverPhone: asString(json['receiverPhone']),
      weightKg: asDouble(json['weightKg']),
      type: asString(json['type']),
      isUrgent: json['isUrgent'] == true,
      notes: asString(json['notes']),
    );
  }
}

/// Client de l'endpoint `POST /ai/assistant`. Jamais d'exception vers l'UI :
/// en cas d'erreur réseau, renvoie un résultat fallback avec `answerText`
/// d'erreur courtois pour que l'utilisateur ne soit pas bloqué.
class AiAssistantApi {
  final ApiClient client;
  AiAssistantApi(this.client);

  Future<AiAssistantResult> ask({required String message, String? city}) async {
    try {
      final response = await client.dio.post(
        '/ai/assistant',
        data: {
          'message': message,
          if (city != null && city.isNotEmpty) 'city': city,
        },
      );
      final data = response.data;
      if (data is Map) {
        return AiAssistantResult.fromResponse(Map<String, dynamic>.from(data));
      }
      return _fallback();
    } catch (_) {
      return _fallback();
    }
  }

  AiAssistantResult _fallback() => const AiAssistantResult(
        intent: 'unknown',
        answerText:
            "L'assistant est indisponible pour le moment. Vous pouvez créer un colis depuis l'onglet « Envoyer ».",
        configured: false,
      );
}
