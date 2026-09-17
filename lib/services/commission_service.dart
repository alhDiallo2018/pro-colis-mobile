/// Configuration de la commission Pro-Colis
/// Ces valeurs proviennent de la configuration administrée (`/public/config`)
/// et sont appliquées via [CommissionService.configure]. Aucune valeur métier
/// n'est codée en dur : tant que la configuration n'est pas chargée, les
/// paramètres restent à 0 (aucune commission inventée).
class CommissionConfig {
  final double percentage; // Pourcentage (ex: 5 pour 5%)
  final double minimum; // Commission minimum en FCFA
  final double maximum; // Commission maximum en FCFA

  const CommissionConfig({
    this.percentage = 0,
    this.minimum = 0,
    this.maximum = 0,
  });

  /// Charge depuis la config admin (API)
  factory CommissionConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CommissionConfig();
    return CommissionConfig(
      percentage: double.tryParse(map['percentage']?.toString() ?? '') ?? 0,
      minimum: double.tryParse(map['minAmount']?.toString() ?? '') ?? 0,
      maximum: double.tryParse(map['maxAmount']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'percentage': percentage,
        'minAmount': minimum,
        'maxAmount': maximum,
      };
}

/// Service de calcul de commission Pro-Colis
/// Règles métier:
///   commission = montant_livraison × pourcentage
///   Si commission < minimum → minimum
///   Si commission > maximum → maximum
class CommissionService {
  static CommissionConfig _config = const CommissionConfig();
  // Règle configurée (`commission.insufficient_rule`) : block | warn | debt.
  // La valeur de référence vient de la configuration distante via
  // [configure] / [setInsufficientPolicy].
  static String _insufficientPolicy = 'block'; // block | warn | debt

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

  /// Règle configurée en cas de solde insuffisant (`commission.insufficient_rule`).
  static String get insufficientPolicy => _insufficientPolicy;

  /// La commission est désormais toujours comptabilisée en dette (`commissionDebt`)
  /// lorsqu'une livraison déjà acceptée est finalisée sans ressources suffisantes.
  /// Le backend reste seul juge (plafond `commission.debtLimit`) ; le mobile ne
  /// bloque donc plus le paiement sur la seule base de `insufficient_rule`.
  static bool get allowsDebt => true;

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

  static double get percentage => _config.percentage;
  static double get minimum => _config.minimum;
  static double get maximum => _config.maximum;
}
