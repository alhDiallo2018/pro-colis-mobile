// mobile/lib/models/payment.dart
import 'package:flutter/material.dart';

enum PaymentMethod {
  wave('wave', 'Wave', Icons.waves),
  freeMoney('freemMoney', 'freeMoney', Icons.money),
  orangeMoney('orange_money', 'Orange Money', Icons.phone_android),
  card('card', 'Carte Bancaire', Icons.credit_card),
  cash('cash', 'Espèces', Icons.money);

  final String value;
  final String label;
  final IconData icon;
  const PaymentMethod(this.value, this.label, this.icon);

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentMethod.cash,
    );
  }

  bool get isCash => this == PaymentMethod.cash;

  /// Canal implicite de la méthode : seules les espèces échappent à la
  /// plateforme, tout le reste est encaissé par elle.
  PaymentChannel get channel =>
      isCash ? PaymentChannel.cash : PaymentChannel.platform;

  /// Méthodes disponibles lorsque le règlement passe par la plateforme.
  static List<PaymentMethod> get platformMethods =>
      values.where((m) => !m.isCash).toList();
}

/// Canal de règlement d'une course, choisi avant la livraison.
///
/// - `cash` : l'argent passe de la main à la main (l'expéditeur au ramassage ou
///   le destinataire à la livraison). La plateforme n'encaisse rien : c'est le
///   chauffeur qui lui doit ensuite la commission, et il doit déclarer
///   l'encaissement pour que la course soit réconciliée.
/// - `platform` : la plateforme encaisse (mobile money / carte via PayDunya)
///   puis reverse au chauffeur le montant net de commission.
enum PaymentChannel {
  cash(
    'cash',
    'Espèces',
    'De la main à la main, hors plateforme',
    Icons.payments_rounded,
  ),
  platform(
    'platform',
    'Via la plateforme',
    'Mobile money ou carte, encaissé par ProColis',
    Icons.account_balance_wallet_rounded,
  );

  final String value;
  final String label;
  final String hint;
  final IconData icon;
  const PaymentChannel(this.value, this.label, this.hint, this.icon);

  bool get isCash => this == PaymentChannel.cash;
  bool get isPlatform => this == PaymentChannel.platform;

  /// Méthode par défaut associée au canal : `cash` d'un côté, et de l'autre on
  /// laisse l'API/PayDunya arbitrer l'opérateur exact (`card` par défaut).
  PaymentMethod get defaultMethod =>
      isCash ? PaymentMethod.cash : PaymentMethod.card;

  /// Tolère le canal (`cash` / `platform` et leurs alias) mais aussi une simple
  /// méthode de paiement (`wave`, `orange_money`…), afin de rester compatible
  /// avec les colis créés avant l'introduction du canal.
  static PaymentChannel? tryParse(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    switch (value) {
      case 'cash':
      case 'especes':
      case 'espèces':
      case 'espece':
        return PaymentChannel.cash;
      case 'platform':
      case 'plateforme':
      case 'online':
      case 'en_ligne':
      case 'enligne':
        return PaymentChannel.platform;
    }
    for (final method in PaymentMethod.values) {
      if (method.value.toLowerCase() == value) return method.channel;
    }
    return null;
  }

  static PaymentChannel fromString(dynamic raw) =>
      tryParse(raw) ?? PaymentChannel.cash;

  /// Liste de canaux acceptés telle que renvoyée par l'API (tableau de chaînes),
  /// dédoublonnée et ordonnée comme l'enum. Une valeur inconnue est ignorée.
  static List<PaymentChannel> listFrom(dynamic raw) {
    if (raw is! Iterable) return const [];
    final parsed = <PaymentChannel>{};
    for (final item in raw) {
      final channel = tryParse(item);
      if (channel != null) parsed.add(channel);
    }
    return values.where(parsed.contains).toList();
  }

  static List<String> toValues(Iterable<PaymentChannel> channels) =>
      channels.map((c) => c.value).toList();
}

/// En espèces, à quel moment du transport le chauffeur encaisse — et donc
/// auprès de qui. Détermine l'étape à laquelle il doit déclarer l'encaissement.
enum CashCollectionPoint {
  senderPickup(
    'sender_pickup',
    'Expéditeur au ramassage',
    'L’expéditeur règle en confiant le colis',
    Icons.upload_rounded,
  ),
  receiverDelivery(
    'receiver_delivery',
    'Destinataire à la livraison',
    'Le destinataire règle en recevant le colis',
    Icons.download_rounded,
  );

  final String value;
  final String label;
  final String hint;
  final IconData icon;
  const CashCollectionPoint(this.value, this.label, this.hint, this.icon);

  bool get isAtPickup => this == CashCollectionPoint.senderPickup;
  bool get isAtDelivery => this == CashCollectionPoint.receiverDelivery;

  /// Qui remet l'argent, pour les libellés courts.
  String get payerLabel => isAtPickup ? 'Expéditeur' : 'Destinataire';

  static CashCollectionPoint? tryParse(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    switch (value) {
      case 'sender_pickup':
      case 'sender':
      case 'pickup':
      case 'expediteur':
        return CashCollectionPoint.senderPickup;
      case 'receiver_delivery':
      case 'receiver':
      case 'delivery':
      case 'destinataire':
        return CashCollectionPoint.receiverDelivery;
    }
    return null;
  }
}

enum PaymentStatus {
  pending('pending', 'En attente', 'À encaisser', Colors.orange),
  processing('processing', 'En cours', 'Encaissement déclaré', Colors.blue),
  completed('completed', 'Payé', 'Encaissement validé', Colors.green),
  failed('failed', 'Échoué', 'Encaissement rejeté', Colors.red),
  refunded('refunded', 'Remboursé', 'Remboursé', Colors.purple);

  final String value;
  final String label;

  /// Libellé à utiliser pour un règlement en espèces, où « en cours » veut dire
  /// « déclaré par le chauffeur, en attente de validation ».
  final String cashLabel;
  final Color color;
  const PaymentStatus(this.value, this.label, this.cashLabel, this.color);

  static PaymentStatus fromString(dynamic raw) {
    final value = raw?.toString();
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}

class Payment {
  final String id;
  final String userId;
  final String? userName;
  final String? parcelId;
  final String? trackingNumber;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? transactionId;
  final String? phoneNumber;
  final String? reference;
  final Map<String, dynamic>? metadata;
  final String? receiptUrl;
  final String? validatedBy;
  final DateTime? validatedAt;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  /// Canal de règlement. Dérivé de [method] quand l'API ne le renvoie pas.
  final PaymentChannel channel;

  /// Renseigné uniquement en espèces : à quelle étape l'argent a été (ou doit
  /// être) remis au chauffeur.
  final CashCollectionPoint? cashCollectionPoint;

  // Déclaration d'encaissement espèces faite par le chauffeur. Ces champs
  // peuvent arriver à plat ou dans `metadata` selon l'endpoint appelé.
  final String? declaredBy;
  final String? declaredByName;
  final DateTime? declaredAt;
  final String? declarationNote;
  final String? declarationProofUrl;

  Payment({
    required this.id,
    required this.userId,
    this.userName,
    this.parcelId,
    this.trackingNumber,
    required this.amount,
    this.currency = 'XOF',
    required this.method,
    required this.status,
    this.transactionId,
    this.phoneNumber,
    this.reference,
    this.metadata,
    this.receiptUrl,
    this.validatedBy,
    this.validatedAt,
    required this.createdAt,
    this.completedAt,
    this.updatedAt,
    PaymentChannel? channel,
    this.cashCollectionPoint,
    this.declaredBy,
    this.declaredByName,
    this.declaredAt,
    this.declarationNote,
    this.declarationProofUrl,
  }) : channel = channel ?? method.channel;

  factory Payment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return null;
      }
    }

    final metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : null;

    // La déclaration d'encaissement peut être renvoyée à plat ou rangée dans
    // `metadata` : on accepte les deux formes.
    dynamic field(String key) => json[key] ?? metadata?[key];

    final method = json['method'] != null
        ? PaymentMethod.fromString(json['method'].toString())
        : PaymentMethod.cash;

    return Payment(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString(),
      parcelId: json['parcelId']?.toString(),
      trackingNumber: json['trackingNumber']?.toString(),
      // Prisma sérialise les Decimal en chaînes afin de ne pas perdre de
      // précision. Accepter aussi les nombres garde le modèle compatible avec
      // les données locales et les anciennes réponses.
      amount: json['amount'] is num
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      currency: json['currency'] ?? 'XOF',
      method: method,
      status: PaymentStatus.fromString(json['status']),
      transactionId: json['transactionId']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      reference: json['reference']?.toString(),
      metadata: metadata,
      receiptUrl: json['receiptUrl']?.toString(),
      validatedBy: json['validatedBy']?.toString(),
      validatedAt: parseDateTime(json['validatedAt']),
      createdAt: parseDateTime(json['createdAt']) ?? DateTime.now(),
      completedAt: parseDateTime(json['completedAt']),
      updatedAt: parseDateTime(json['updatedAt']),
      channel:
          PaymentChannel.tryParse(json['channel'] ?? metadata?['channel']) ??
              method.channel,
      cashCollectionPoint:
          CashCollectionPoint.tryParse(field('cashCollectionPoint')),
      declaredBy: field('declaredBy')?.toString(),
      declaredByName: field('declaredByName')?.toString(),
      declaredAt: parseDateTime(field('declaredAt')),
      declarationNote: field('declarationNote')?.toString(),
      declarationProofUrl: field('declarationProofUrl')?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'parcelId': parcelId,
        'trackingNumber': trackingNumber,
        'amount': amount,
        'currency': currency,
        'method': method.value,
        'status': status.value,
        'transactionId': transactionId,
        'phoneNumber': phoneNumber,
        'reference': reference,
        'metadata': metadata,
        'receiptUrl': receiptUrl,
        'validatedBy': validatedBy,
        'validatedAt': validatedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'channel': channel.value,
        'cashCollectionPoint': cashCollectionPoint?.value,
        'declaredBy': declaredBy,
        'declaredByName': declaredByName,
        'declaredAt': declaredAt?.toIso8601String(),
        'declarationNote': declarationNote,
        'declarationProofUrl': declarationProofUrl,
      };

  bool get isCompleted => status == PaymentStatus.completed;
  bool get isPending => status == PaymentStatus.pending;
  bool get isFailed => status == PaymentStatus.failed;
  bool get isRefunded => status == PaymentStatus.refunded;

  /// Règlement en espèces : rien n'a transité par la plateforme.
  bool get isCash => channel.isCash || method.isCash;

  /// Le chauffeur a déclaré avoir reçu l'argent, mais un admin doit encore
  /// réconcilier l'encaissement.
  bool get isCashDeclared => isCash && status == PaymentStatus.processing;

  /// À afficher dans la file de validation admin.
  bool get awaitsCashValidation => isCashDeclared && validatedAt == null;

  /// Libellé de statut adapté au canal (« Encaissement déclaré » plutôt que
  /// « En cours » pour les espèces).
  String get statusLabel => isCash ? status.cashLabel : status.label;

  String get formattedAmount => '${amount.toStringAsFixed(0)} FCFA';

  Payment copyWith({
    String? id,
    String? userId,
    String? userName,
    String? parcelId,
    String? trackingNumber,
    double? amount,
    String? currency,
    PaymentMethod? method,
    PaymentStatus? status,
    String? transactionId,
    String? phoneNumber,
    String? reference,
    Map<String, dynamic>? metadata,
    String? receiptUrl,
    String? validatedBy,
    DateTime? validatedAt,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? updatedAt,
    PaymentChannel? channel,
    CashCollectionPoint? cashCollectionPoint,
    String? declaredBy,
    String? declaredByName,
    DateTime? declaredAt,
    String? declarationNote,
    String? declarationProofUrl,
  }) {
    return Payment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      parcelId: parcelId ?? this.parcelId,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      method: method ?? this.method,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      reference: reference ?? this.reference,
      metadata: metadata ?? this.metadata,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      validatedBy: validatedBy ?? this.validatedBy,
      validatedAt: validatedAt ?? this.validatedAt,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      channel: channel ?? this.channel,
      cashCollectionPoint: cashCollectionPoint ?? this.cashCollectionPoint,
      declaredBy: declaredBy ?? this.declaredBy,
      declaredByName: declaredByName ?? this.declaredByName,
      declaredAt: declaredAt ?? this.declaredAt,
      declarationNote: declarationNote ?? this.declarationNote,
      declarationProofUrl: declarationProofUrl ?? this.declarationProofUrl,
    );
  }
}
