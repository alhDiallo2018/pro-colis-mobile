// lib/models/report.dart
//
// Rapports de période (zone et plateforme).
//
// Contrat : `buildPeriodReport` dans `ProColis-Api/src/modules/mobile/
// mobile.controller.js`, exposé par `/garage-admin/reports/daily|monthly` et
// `/super-admin/reports/daily|monthly`. Même forme pour les quatre routes, d'où
// un seul modèle.
//
// Ces chiffres sont calculés par le serveur sur la totalité de la période. Les
// recalculer côté client à partir d'une liste de colis paginée donnerait des
// totaux faux dès que la période dépasse une page — c'est précisément l'erreur
// que ce modèle remplace.

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

/// Un point de la série : heure du jour (`bucket: hour`) ou date ISO
/// (`bucket: day`).
class ReportPoint {
  final String key;
  final int created;
  final int delivered;
  final double revenue;

  const ReportPoint({
    required this.key,
    this.created = 0,
    this.delivered = 0,
    this.revenue = 0,
  });

  factory ReportPoint.fromJson(Map<String, dynamic> json) => ReportPoint(
        key: json['key']?.toString() ?? '',
        created: _toInt(json['created']),
        delivered: _toInt(json['delivered']),
        revenue: _toDouble(json['revenue']),
      );
}

class ReportTotals {
  final int created;
  final int delivered;
  final int cancelled;

  /// Pourcentage entier calculé par le serveur : livraisons de la période
  /// rapportées aux colis qui y sont nés.
  final int deliveryRate;
  final double revenue;
  final double deliveredAmount;

  const ReportTotals({
    this.created = 0,
    this.delivered = 0,
    this.cancelled = 0,
    this.deliveryRate = 0,
    this.revenue = 0,
    this.deliveredAmount = 0,
  });

  factory ReportTotals.fromJson(Map<String, dynamic> json) => ReportTotals(
        created: _toInt(json['created']),
        delivered: _toInt(json['delivered']),
        cancelled: _toInt(json['cancelled']),
        deliveryRate: _toInt(json['deliveryRate']),
        revenue: _toDouble(json['revenue']),
        deliveredAmount: _toDouble(json['deliveredAmount']),
      );
}

class TopDriver {
  final String driverId;
  final String? fullName;
  final int delivered;

  const TopDriver({
    required this.driverId,
    this.fullName,
    this.delivered = 0,
  });

  factory TopDriver.fromJson(Map<String, dynamic> json) => TopDriver(
        driverId: json['driverId']?.toString() ?? '',
        fullName: json['fullName']?.toString(),
        delivered: _toInt(json['delivered']),
      );

  /// Le serveur renvoie `null` quand le compte a été supprimé depuis.
  String get label =>
      (fullName == null || fullName!.isEmpty) ? 'Chauffeur supprimé' : fullName!;
}

class PeriodReport {
  /// Jour couvert (rapport journalier uniquement), au format `YYYY-MM-DD`.
  final String? date;
  final int? year;
  final int? month;
  final DateTime? from;
  final DateTime? to;

  /// `hour` pour un rapport journalier, `day` pour un rapport mensuel.
  final String bucket;
  final ReportTotals totals;
  final Map<String, int> parcelsByStatus;
  final List<ReportPoint> series;
  final List<TopDriver> topDrivers;

  const PeriodReport({
    this.date,
    this.year,
    this.month,
    this.from,
    this.to,
    this.bucket = 'day',
    this.totals = const ReportTotals(),
    this.parcelsByStatus = const {},
    this.series = const [],
    this.topDrivers = const [],
  });

  factory PeriodReport.fromJson(Map<String, dynamic> json) {
    final byStatus = <String, int>{};
    final rawStatus = json['parcelsByStatus'];
    if (rawStatus is Map) {
      rawStatus.forEach((key, value) {
        byStatus[key.toString()] = _toInt(value);
      });
    }

    List<T> list<T>(dynamic raw, T Function(Map<String, dynamic>) build) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => build(e.cast<String, dynamic>()))
          .toList();
    }

    return PeriodReport(
      date: json['date']?.toString(),
      year: json['year'] == null ? null : _toInt(json['year']),
      month: json['month'] == null ? null : _toInt(json['month']),
      from: DateTime.tryParse(json['from']?.toString() ?? ''),
      to: DateTime.tryParse(json['to']?.toString() ?? ''),
      bucket: json['bucket']?.toString() ?? 'day',
      totals: ReportTotals.fromJson(
        (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      parcelsByStatus: byStatus,
      series: list(json['series'], ReportPoint.fromJson),
      topDrivers: list(json['topDrivers'], TopDriver.fromJson),
    );
  }

  bool get isEmpty =>
      totals.created == 0 && totals.delivered == 0 && totals.cancelled == 0;

  /// Plus haute barre de la série, pour dimensionner un graphe.
  int get peakCreated =>
      series.fold(0, (max, p) => p.created > max ? p.created : max);
}
