/// Configuration de la commission Pro-Colis
/// Ces valeurs peuvent être modifiées dynamiquement via le backend
class CommissionConfig {
  final double percentage; // Pourcentage (ex: 5 pour 5%)
  final double minimum; // Commission minimum en FCFA
  final double maximum; // Commission maximum en FCFA

  const CommissionConfig({
    this.percentage = 5,
    this.minimum = 100,
    this.maximum = 500,
  });

  /// Charge depuis la config admin (API)
  factory CommissionConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CommissionConfig();
    return CommissionConfig(
      percentage: double.tryParse(map['commissionPercentage']?.toString() ?? '') ?? 5,
      minimum: double.tryParse(map['commissionMinimum']?.toString() ?? '') ?? 100,
      maximum: double.tryParse(map['commissionMaximum']?.toString() ?? '') ?? 500,
    );
  }

  Map<String, dynamic> toMap() => {
        'commissionPercentage': percentage,
        'commissionMinimum': minimum,
        'commissionMaximum': maximum,
      };
}

/// Service de calcul de commission Pro-Colis
/// Règles métier:
///   commission = montant_livraison × pourcentage
///   Si commission < minimum → minimum
///   Si commission > maximum → maximum
class CommissionService {
  static CommissionConfig _config = const CommissionConfig();
  static String _insufficientPolicy = 'warn'; // block | warn | debt

  /// Met à jour la configuration (appelé au démarrage ou depuis admin)
  static void configure(CommissionConfig config) {
    _config = config;
  }

  /// Met à jour la politique d'insuffisance
  static void setInsufficientPolicy(String policy) {
    if (['block', 'warn', 'debt'].contains(policy)) {
      _insufficientPolicy = policy;
    }
  }

  static String get insufficientPolicy => _insufficientPolicy;

  /// Calcule la commission pour un montant de livraison donné
  static double calculate(double deliveryAmount) {
    return _calculate(
      deliveryAmount,
      _config.percentage,
      _config.minimum,
      _config.maximum,
    );
  }

  /// Calcule avec paramètres explicites pour les tests
  static double _calculate(
    double amount,
    double percentage,
    double minimum,
    double maximum,
  ) {
    if (amount <= 0) return 0;
    double commission = amount * (percentage / 100);
    if (commission < minimum) commission = minimum;
    if (commission > maximum) commission = maximum;
    return commission;
  }

  /// Vérifie si un chauffeur peut accepter une livraison (solde suffisant pour la commission)
  static bool canAcceptDelivery({
    required double walletBalance,
    required double scoreBalance,
    required double deliveryAmount,
  }) {
    final commission = calculate(deliveryAmount);
    return (walletBalance + scoreBalance) >= commission;
  }

  /// Vérifie si wallet ET points sont nécessaires
  static bool requiresBothSources({
    required double walletBalance,
    required double scoreBalance,
    required double deliveryAmount,
  }) {
    final commission = calculate(deliveryAmount);
    return walletBalance < commission && (walletBalance + scoreBalance) >= commission;
  }

  /// Calcule la répartition du paiement entre wallet et points
  static Map<String, double> splitPayment({
    required double walletBalance,
    required double scoreBalance,
    required double deliveryAmount,
  }) {
    final commission = calculate(deliveryAmount);
    final fromWallet = walletBalance < commission ? walletBalance : commission;
    final remainder = commission - fromWallet;
    final fromPoints = remainder < scoreBalance ? remainder : scoreBalance;
    return {'fromWallet': fromWallet, 'fromPoints': fromPoints};
  }

  /// Calcule le nouveau solde après commission
  static double balanceAfterCommission({
    required double currentBalance,
    required double deliveryAmount,
  }) {
    final commission = calculate(deliveryAmount);
    return currentBalance - commission;
  }

  /// Politique configurée en cas d'insuffisance
  static String get insufficientFundsMessage {
    switch (_insufficientPolicy) {
      case 'block':
        return 'Solde insuffisant. Rechargez votre portefeuille ou vos points pour continuer.';
      case 'debt':
        return 'Attention : votre solde est insuffisant. La commission sera due.';
      default:
        return 'Solde insuffisant. Pensez à recharger votre portefeuille.';
    }
  }

  /// La livraison est-elle bloquée par la politique ?
  static bool get isDeliveryBlocked =>
      _insufficientPolicy == 'block';

  /// Configuration actuelle (lecture seule)
  static CommissionConfig get config => _config;
  static double get percentage => _config.percentage;
  static double get minimum => _config.minimum;
  static double get maximum => _config.maximum;
}

/// Exemples de calcul commentés directement dans le code
///
/// Livraison 1 000 FCFA → commission = 100 FCFA (minimum)
/// Livraison 5 000 FCFA → commission = 250 FCFA
/// Livraison 10 000 FCFA → commission = 500 FCFA (maximum)
/// Livraison 50 000 FCFA → commission = 500 FCFA (maximum)
