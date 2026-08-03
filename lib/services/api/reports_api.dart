// lib/services/api/reports_api.dart
//
// Rapports de période, zone et plateforme.
//
// Port du client web `ProColis-Web/src/lib/api/reports.ts`. Les quatre routes
// de rapport partagent la forme `PeriodReport` ; l'export renvoie une liste de
// lignes brutes, que l'appelant met en forme.

import '../../models/report.dart';
import 'client.dart';

class ReportsApi {
  final ApiClient client;

  ReportsApi(this.client);

  Future<PeriodReport> _report(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await client.dio.get(path, queryParameters: query);
    final data = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || data['success'] == false) {
      throw ReportsApiException(
        data['message']?.toString() ?? 'Rapport indisponible',
        statusCode: status,
      );
    }
    // `ok()` étale les données à la racine, mais certains déploiements
    // imbriquent encore sous `data` : on accepte les deux, comme le web.
    final raw = (data['report'] as Map?) ??
        ((data['data'] as Map?)?['report'] as Map?) ??
        const {};
    return PeriodReport.fromJson(raw.cast<String, dynamic>());
  }

  Future<List<Map<String, dynamic>>> _rows(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await client.dio.get(path, queryParameters: query);
    final data = client.handle(res);
    final raw = data['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  /// Rapport journalier de la zone de l'admin connecté (série horaire).
  /// [date] au format `YYYY-MM-DD` ; sans elle, le serveur prend aujourd'hui.
  Future<PeriodReport> garageDaily({String? date}) => _report(
        '/garage-admin/reports/daily',
        query: {if (date != null) 'date': date},
      );

  /// Rapport mensuel de la zone (série par jour).
  Future<PeriodReport> garageMonthly({required int year, required int month}) =>
      _report(
        '/garage-admin/reports/monthly',
        query: {'year': year, 'month': month},
      );

  /// Rapport journalier plateforme (super admin / support).
  Future<PeriodReport> adminDaily({String? date}) => _report(
        '/super-admin/reports/daily',
        query: {if (date != null) 'date': date},
      );

  Future<PeriodReport> adminMonthly({required int year, required int month}) =>
      _report(
        '/super-admin/reports/monthly',
        query: {'year': year, 'month': month},
      );

  /// Export brut de la zone. L'API renvoie du JSON, pas un fichier.
  Future<List<Map<String, dynamic>>> garageExport() =>
      _rows('/garage-admin/reports/export');

  Future<List<Map<String, dynamic>>> adminExport({String type = 'parcels'}) =>
      _rows('/super-admin/export', query: {'type': type});
}

class ReportsApiException implements Exception {
  final String message;
  final int? statusCode;

  const ReportsApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
