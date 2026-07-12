import 'dart:convert';

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

enum WalletTransactionType {
  deposit('DEPOSIT', 'Recharge'),
  commission('COMMISSION', 'Commission'),
  refund('REFUND', 'Remboursement'),
  adjustment('ADJUSTMENT', 'Ajustement'),
  bonus('BONUS', 'Bonus');

  final String value;
  final String label;
  const WalletTransactionType(this.value, this.label);

  static WalletTransactionType fromString(String v) =>
      WalletTransactionType.values.firstWhere((e) => e.value == v,
          orElse: () => WalletTransactionType.adjustment);
}

/// Transaction du portefeuille chauffeur
class WalletTransaction {
  final String id;
  final String userId;
  final String walletId;
  final double amount; // positif = crédit, négatif = débit
  final WalletTransactionType type;
  final String? parcelId;
  final String? trackingNumber;
  final String description;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.walletId,
    required this.amount,
    required this.type,
    this.parcelId,
    this.trackingNumber,
    required this.description,
    required this.createdAt,
    this.metadata,
  });

  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;
  String get formattedAmount =>
      '${amount > 0 ? '+' : ''}${amount.toStringAsFixed(0)} FCFA';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      walletId: json['walletId']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      type: json['type'] != null
          ? WalletTransactionType.fromString(json['type'].toString())
          : WalletTransactionType.adjustment,
      parcelId: json['parcelId']?.toString(),
      trackingNumber: json['trackingNumber']?.toString(),
      description: json['description']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'walletId': walletId,
        'amount': amount,
        'type': type.value,
        if (parcelId != null) 'parcelId': parcelId,
        if (trackingNumber != null) 'trackingNumber': trackingNumber,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  WalletTransaction copyWith({
    String? id,
    String? userId,
    String? walletId,
    double? amount,
    WalletTransactionType? type,
    String? parcelId,
    String? trackingNumber,
    String? description,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      walletId: walletId ?? this.walletId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      parcelId: parcelId ?? this.parcelId,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletTransaction && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Portefeuille crédit FCFA du chauffeur
class Wallet {
  final String id;
  final String userId;
  final double balance; // Solde actuel en crédits FCFA
  final double totalDeposited; // Total rechargé
  final double totalConsumed; // Total commissions payées
  final double totalRefunded; // Total remboursé
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WalletTransaction> transactions;

  const Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    this.totalDeposited = 0,
    this.totalConsumed = 0,
    this.totalRefunded = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.transactions = const [],
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    final txs = json['transactions'] as List<dynamic>?;
    return Wallet(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      balance: _toDouble(json['balance']),
      totalDeposited: _toDouble(json['totalDeposited']),
      totalConsumed: _toDouble(json['totalConsumed']),
      totalRefunded: _toDouble(json['totalRefunded']),
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
      transactions: txs != null
          ? txs
              .map((t) =>
                  WalletTransaction.fromJson(t as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'balance': balance,
        'totalDeposited': totalDeposited,
        'totalConsumed': totalConsumed,
        'totalRefunded': totalRefunded,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };

  Wallet copyWith({
    String? id,
    String? userId,
    double? balance,
    double? totalDeposited,
    double? totalConsumed,
    double? totalRefunded,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<WalletTransaction>? transactions,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      totalDeposited: totalDeposited ?? this.totalDeposited,
      totalConsumed: totalConsumed ?? this.totalConsumed,
      totalRefunded: totalRefunded ?? this.totalRefunded,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      transactions: transactions ?? this.transactions,
    );
  }

  // Helpers métier
  bool get hasBalance => balance > 0;

  /// Vérifie si le chauffeur peut accepter une livraison au montant donné
  bool canAcceptDelivery(double deliveryAmount, double commissionPercentage,
      double minCommission, double maxCommission) {
    if (!isActive) return false;
    final commission =
        _calcCommission(deliveryAmount, commissionPercentage, minCommission, maxCommission);
    return balance >= commission;
  }

  double get requiredCommissionForDelivery {
    // Pour ce helper on prend la commission max possible (conservateur)
    return 500;
  }

  static double _calcCommission(double amount, double pct, double min, double max) {
    double c = amount * (pct / 100);
    if (c < min) c = min;
    if (c > max) c = max;
    return c;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wallet && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
