// lib/models/score.dart
class Score {
  final String userId;
  final int points;
  final int totalEarned;
  final int totalSpent;
  final DateTime lastUpdated;
  final List<ScoreTransaction> transactions;

  Score({
    required this.userId,
    this.points = 0,
    this.totalEarned = 0,
    this.totalSpent = 0,
    DateTime? lastUpdated,
    this.transactions = const [],
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory Score.fromJson(Map<String, dynamic> json) {
    return Score(
      userId: json['userId']?.toString() ?? '',
      points: json['points'] ?? 0,
      totalEarned: json['totalEarned'] ?? 0,
      totalSpent: json['totalSpent'] ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
      transactions: (json['transactions'] as List?)
              ?.map((t) => ScoreTransaction.fromJson(t))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'points': points,
      'totalEarned': totalEarned,
      'totalSpent': totalSpent,
      'lastUpdated': lastUpdated.toIso8601String(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
  }

  Score copyWith({
    String? userId,
    int? points,
    int? totalEarned,
    int? totalSpent,
    DateTime? lastUpdated,
    List<ScoreTransaction>? transactions,
  }) {
    return Score(
      userId: userId ?? this.userId,
      points: points ?? this.points,
      totalEarned: totalEarned ?? this.totalEarned,
      totalSpent: totalSpent ?? this.totalSpent,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      transactions: transactions ?? this.transactions,
    );
  }
}

class ScoreTransaction {
  final String id;
  final String userId;
  final int amount;
  final String type;
  final String? parcelId;
  final DateTime timestamp;
  final String description;
  final String status;
  final Map<String, dynamic>? metadata;

  ScoreTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    this.parcelId,
    DateTime? timestamp,
    required this.description,
    this.status = 'completed',
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ScoreTransaction.fromJson(Map<String, dynamic> json) {
    return ScoreTransaction(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      amount: json['amount'] ?? 0,
      type: json['type']?.toString() ?? '',
      parcelId: json['parcelId']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'completed',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'type': type,
      'parcelId': parcelId,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'status': status,
      'metadata': metadata,
    };
  }
}