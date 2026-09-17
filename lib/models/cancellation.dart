// lib/models/cancellation.dart
//
// Représentation dynamique du résultat d'une annulation de colis.
//
// Aucune règle métier (montant, pourcentage, seuil, répartition) n'est définie
// ici : ce modèle ne fait que relire ce que le backend renvoie dans la réponse
// de `POST /client/parcels/:id/cancel` (ou dans le bloc `cancellation` d'un
// colis sérialisé). Toute valeur absente reste `null` et est simplement masquée
// à l'affichage — le mobile ne reconstitue jamais une donnée financière.
//
// Contrat attendu du backend (à implémenter côté serveur) :
// {
//   success: true,
//   message: "...",
//   parcel: { ... },
//   event: { ... },
//   cancellation: {
//     allowed: true | false,
//     penalized: true | false,
//     responsibleParty: "client" | "driver" | "shared" | null,
//     penalty: {
//       amount: "1500",            // FCFA
//       currency: "XOF",
//       label: "Pénalité ...",     // libellé fourni par le serveur
//       applied: true,
//       clientShare: "750",        // présent en cas de responsabilité partagée
//       driverShare: "750"
//     },
//     refund: {
//       initialAmount: "5000",
//       fees: "0",
//       paydunyaFee: "0",
//       penaltyAmount: "1500",
//       refundedAmount: "3500",
//       status: "pending" | "completed" | "failed"
//     },
//     clientDebt: { id: "<uuid>", amount: "1500", reference: "PD-XXX" }, // client
//     wallet: { before: "1000", deduction: "500", after: "500" },   // chauffeur
//     points: { before: 100, deduction: 50, after: 50 },             // chauffeur
//     debt:   { before: "0", created: "0", after: "0" }              // chauffeur
//   }
// }

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final parsed = double.tryParse(v.toString());
  return parsed;
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? _toStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

bool? _toBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  final s = v.toString().trim().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return null;
}

Map<String, dynamic>? _toMap(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

/// Partie désignée responsable de l'annulation par le backend.
enum CancellationParty {
  client('client'),
  driver('driver'),
  shared('shared'),
  exempt('exempt');

  final String value;
  const CancellationParty(this.value);

  static CancellationParty? tryParse(dynamic raw) {
    final v = _toStr(raw)?.toLowerCase();
    if (v == null) return null;
    for (final party in values) {
      if (party.value == v) return party;
    }
    return null;
  }
}

/// Motif d'annulation renvoyé par l'API (`reasons` du devis ou de la
/// configuration publique). Le mobile ne conserve ici que le couple
/// `value`/`label` pour l'affichage : le code `value` envoyé au backend vient
/// toujours de l'API, jamais d'une liste métier codée en dur.
class CancellationReason {
  final String value;
  final String label;

  const CancellationReason({required this.value, required this.label});

  factory CancellationReason.fromJson(dynamic json) {
    if (json is! Map) return const CancellationReason(value: '', label: '');
    return CancellationReason(
      value: _toStr(json['value']) ?? '',
      label: _toStr(json['label']) ?? _toStr(json['value']) ?? '',
    );
  }

  bool get isValid => value.isNotEmpty;
}

/// Bloc `clientDebt` : dette de pénalité du client décidée par le backend.
/// Le client n'a pas de wallet préfinancé ; la part de pénalité non couverte par
/// un remboursement devient une dette persistante (`ClientPenaltyDebt`), réglée
/// ensuite via PayDunya. Le mobile ne fait que relire ce que le backend expose
/// (`id`, `amount`, `reference`, et éventuellement `status` / `remaining`) — il
/// ne calcule jamais le reliquat ni le statut.
class CancellationClientDebt {
  /// UUID réel de la ligne `ClientPenaltyDebt` persistée. Sert de `debtId` lors
  /// du règlement via PayDunya. Jamais une valeur saisie par l'utilisateur.
  final String? id;

  final double? amount;
  final String? reference;

  /// Reliquat restant à régler, si le backend le fournit. Jamais recalculé
  /// localement (`remaining = amount - paid` est interdit côté mobile).
  final double? remaining;

  /// Statut de la dette (`pending` / `partially_paid` / `paid`), si fourni.
  final String? status;

  const CancellationClientDebt({
    this.id,
    this.amount,
    this.reference,
    this.remaining,
    this.status,
  });

  factory CancellationClientDebt.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CancellationClientDebt();
    return CancellationClientDebt(
      id: _toStr(json['id']),
      amount: _toDouble(json['amount']),
      reference: _toStr(json['reference']),
      remaining: _toDouble(json['remaining']),
      status: _toStr(json['status']),
    );
  }

  bool get hasDebt => amount != null && amount! > 0;

  /// La dette est-elle identifiable (UUID présent) et donc payable ?
  bool get hasId => id != null && id!.isNotEmpty;

  /// Montant à afficher comme « restant » : le reliquat fourni par le backend
  /// s'il existe, sinon le montant de dette exposé. Aucun calcul local.
  double? get displayedRemaining => remaining ?? amount;
}

/// Bloc `penalty` : la pénalité décidée par le serveur, éventuellement
/// répartie entre client et chauffeur (jamais supposée 50/50 côté mobile).
class CancellationPenalty {
  final double? amount;
  final String? currency;
  final String? label;
  final bool? applied;
  final double? clientShare;
  final double? driverShare;

  const CancellationPenalty({
    this.amount,
    this.currency,
    this.label,
    this.applied,
    this.clientShare,
    this.driverShare,
  });

  factory CancellationPenalty.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CancellationPenalty();
    return CancellationPenalty(
      amount: _toDouble(json['amount'] ?? json['value']),
      currency: _toStr(json['currency']),
      label: _toStr(json['label']),
      applied: _toBool(json['applied']),
      clientShare: _toDouble(json['clientShare'] ?? json['client_share']),
      driverShare: _toDouble(json['driverShare'] ?? json['driver_share']),
    );
  }

  bool get hasValue =>
      amount != null || clientShare != null || driverShare != null;

  bool get hasClientShare => clientShare != null;
  bool get hasDriverShare => driverShare != null;
}

/// Bloc `refund` : détail du remboursement. `penaltyAmount` et les frais sont
/// distincts — le mobile ne les somme jamais lui-même.
class CancellationRefund {
  final double? initialAmount;
  final double? fees;
  final double? paydunyaFee;
  final double? penaltyAmount;
  final double? refundedAmount;
  final String? status;

  const CancellationRefund({
    this.initialAmount,
    this.fees,
    this.paydunyaFee,
    this.penaltyAmount,
    this.refundedAmount,
    this.status,
  });

  factory CancellationRefund.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CancellationRefund();
    return CancellationRefund(
      initialAmount: _toDouble(json['initialAmount'] ?? json['initial_amount']),
      fees: _toDouble(json['fees']),
      paydunyaFee: _toDouble(json['paydunyaFee'] ?? json['paydunya_fee']),
      penaltyAmount: _toDouble(json['penaltyAmount'] ?? json['penalty_amount']),
      refundedAmount:
          _toDouble(json['refundedAmount'] ?? json['refunded_amount']),
      status: _toStr(json['status']),
    );
  }

  bool get hasValue => initialAmount != null || refundedAmount != null;
}

/// Effet sur le portefeuille (FCFA) du chauffeur.
class CancellationWalletEffect {
  final double? before;
  final double? deduction;
  final double? after;

  const CancellationWalletEffect({this.before, this.deduction, this.after});

  factory CancellationWalletEffect.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CancellationWalletEffect();
    return CancellationWalletEffect(
      before: _toDouble(json['before']),
      deduction: _toDouble(json['deduction']),
      after: _toDouble(json['after']),
    );
  }

  bool get hasEffect =>
      before != null || deduction != null || after != null;
}

/// Effet sur les points du chauffeur.
class CancellationPointsEffect {
  final int? before;
  final int? deduction;
  final int? after;

  const CancellationPointsEffect({this.before, this.deduction, this.after});

  factory CancellationPointsEffect.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CancellationPointsEffect();
    return CancellationPointsEffect(
      before: _toInt(json['before']),
      deduction: _toInt(json['deduction']),
      after: _toInt(json['after']),
    );
  }

  bool get hasEffect =>
      before != null || deduction != null || after != null;
}

/// Effet sur la dette du chauffeur (FCFA).
class CancellationDebtEffect {
  final double? before;
  final double? created;
  final double? after;

  const CancellationDebtEffect({this.before, this.created, this.after});

  factory CancellationDebtEffect.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CancellationDebtEffect();
    return CancellationDebtEffect(
      before: _toDouble(json['before']),
      created: _toDouble(json['created'] ?? json['amount']),
      after: _toDouble(json['after']),
    );
  }

  bool get hasEffect => before != null || created != null || after != null;
}

/// Résultat complet d'une annulation, tel que renvoyé par le backend.
class CancellationResult {
  final bool? allowed;
  final bool? penalized;
  final bool? exempt;
  final String? responsiblePartyRaw;
  final CancellationPenalty penalty;
  final CancellationRefund refund;
  final CancellationClientDebt clientDebt;
  final CancellationWalletEffect wallet;
  final CancellationPointsEffect points;
  final CancellationDebtEffect debt;
  final String? message;

  const CancellationResult({
    this.allowed,
    this.penalized,
    this.exempt,
    this.responsiblePartyRaw,
    this.penalty = const CancellationPenalty(),
    this.refund = const CancellationRefund(),
    this.clientDebt = const CancellationClientDebt(),
    this.wallet = const CancellationWalletEffect(),
    this.points = const CancellationPointsEffect(),
    this.debt = const CancellationDebtEffect(),
    this.message,
  });

  /// Construit le résultat à partir de la réponse complète de l'API
  /// (`Map` issue de `ApiService.cancelParcel`). Localise le bloc
  /// `cancellation` (ou les blocs à plat) de façon tolérante.
  factory CancellationResult.fromResponse(Map<String, dynamic> response) {
    final cancellation =
        _toMap(response['cancellation']) ?? _toMap(response['result']);

    if (cancellation != null) {
      return CancellationResult._fromCancellation(cancellation,
          fallbackMessage: _toStr(response['message']));
    }

    // Repli : le backend n'ayant pas encore le bloc `cancellation`, relire les
    // éventuels blocs à plat pour rester compatible avec un contrat futur.
    return CancellationResult._fromCancellation(response,
        fallbackMessage: _toStr(response['message']));
  }

  factory CancellationResult._fromCancellation(
    Map<String, dynamic> json, {
    String? fallbackMessage,
  }) {
    return CancellationResult(
      allowed: _toBool(json['allowed']),
      penalized: _toBool(json['penalized']),
      exempt: _toBool(json['exempt']),
      responsiblePartyRaw: _toStr(json['responsibleParty'] ??
          json['responsible_party'] ??
          json['responsible']),
      penalty: CancellationPenalty.fromJson(_toMap(json['penalty'])),
      refund: CancellationRefund.fromJson(_toMap(json['refund'])),
      clientDebt: CancellationClientDebt.fromJson(_toMap(json['clientDebt'])),
      wallet: CancellationWalletEffect.fromJson(_toMap(json['wallet'])),
      points: CancellationPointsEffect.fromJson(_toMap(json['points'])),
      debt: CancellationDebtEffect.fromJson(_toMap(json['debt'])),
      message: _toStr(json['message']) ?? fallbackMessage,
    );
  }

  CancellationParty? get party =>
      CancellationParty.tryParse(responsiblePartyRaw);

  bool get isClientResponsible => party == CancellationParty.client;
  bool get isDriverResponsible => party == CancellationParty.driver;
  bool get isSharedResponsibility => party == CancellationParty.shared;

  /// L'utilisateur est-il exonéré de toute pénalité ? Vrai lorsque le backend
  /// l'indique explicitement (`exempt: true` ou `responsibleParty: "exempt"`).
  bool get isExempt => exempt == true || party == CancellationParty.exempt;

  bool get hasPenalty => penalty.hasValue && penalized != false;
  bool get hasRefund =>
      (refund.refundedAmount != null && refund.refundedAmount! > 0) ||
      (refund.initialAmount != null && refund.initialAmount! > 0);
  bool get hasClientDebt => clientDebt.hasDebt;
  bool get hasWalletEffect => wallet.deduction != null && wallet.deduction! > 0;
  bool get hasPointsEffect => points.deduction != null && points.deduction! > 0;
  bool get hasDebtEffect => debt.created != null && debt.created! > 0;

  /// Montant de pénalité applicable au client, selon la responsabilité
  /// désignée par le backend. Aucune répartition n'est supposée : sans
  /// information claire (ou montant nul), `null`.
  double? get penaltyForClient {
    final share = penalty.clientShare;
    if (share != null && share > 0) return share;
    if (isClientResponsible) {
      final amount = penalty.amount;
      if (amount != null && amount > 0) return amount;
    }
    return null;
  }

  /// Montant de pénalité applicable au chauffeur.
  double? get penaltyForDriver {
    final share = penalty.driverShare;
    if (share != null && share > 0) return share;
    if (isDriverResponsible) {
      final amount = penalty.amount;
      if (amount != null && amount > 0) return amount;
    }
    return null;
  }

  /// Y a-t-il une conséquence financière visible pour le client ?
  bool get hasClientImpact {
    final amount = penaltyForClient;
    return hasRefund || hasClientDebt || (amount != null && amount > 0);
  }

  /// Y a-t-il une conséquence visible pour le chauffeur ?
  bool get hasDriverImpact {
    final amount = penaltyForDriver;
    return (amount != null && amount > 0) ||
        hasWalletEffect ||
        hasPointsEffect ||
        hasDebtEffect;
  }

  /// Le résultat transporte-t-il une information exploitable à afficher ?
  bool get hasAnyEffect => hasClientImpact || hasDriverImpact;
}

/// Issue d'une opération d'annulation : le résultat parsé en cas de succès,
/// sinon un message et un code d'erreur compréhensibles pour l'utilisateur.
class CancellationOutcome {
  final CancellationResult? result;
  final String? errorMessage;
  final String? errorCode;

  const CancellationOutcome({this.result, this.errorMessage, this.errorCode});

  bool get isSuccess => result != null;
}
