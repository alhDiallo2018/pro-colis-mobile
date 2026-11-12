// lib/services/api/backups_api.dart
//
// Sauvegardes applicatives (super-admin). Expose les 4 opérations exposées
// par `src/modules/backups/backup.controller.js` :
//  - GET  /super-admin/backups              → liste + flag restoreEnabled
//  - POST /super-admin/backup               → démarre un dump (202 async)
//  - GET  /super-admin/backups/:id/download → octets bruts du dump
//  - POST /super-admin/restore              → restaure (207 async, req env)
//
// Le téléchargement renvoie un flux binaire : on force `ResponseType.bytes`
// pour éviter que Dio ne tente de décoder en JSON.

import 'package:dio/dio.dart';

import '../offline_access.dart';
import 'client.dart';

/// Un dump applicatif exposé par le backend. `fileName` est le nom logique
/// sur le volume de sauvegarde, pas une URL publique : seul l'endpoint
/// dédié `/backups/:id/download` peut en servir le contenu.
class BackupEntry {
  final String id;
  final String status;
  final String? fileName;
  final int? sizeBytes;
  final String requestedBy;
  final String? requesterName;
  final String? errorMessage;
  final DateTime? completedAt;
  final DateTime? createdAt;

  const BackupEntry({
    required this.id,
    required this.status,
    this.fileName,
    this.sizeBytes,
    required this.requestedBy,
    this.requesterName,
    this.errorMessage,
    this.completedAt,
    this.createdAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isRunning => status == 'running';
  bool get isFailed => status == 'failed';
  bool get isDownloadable => isCompleted && (fileName?.isNotEmpty ?? false);

  factory BackupEntry.fromJson(Map<String, dynamic> json) => BackupEntry(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'unknown',
        fileName: json['fileName']?.toString(),
        sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
        requestedBy: json['requestedBy']?.toString() ?? '',
        requesterName: json['requesterName']?.toString(),
        errorMessage: json['errorMessage']?.toString(),
        completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

class BackupsPage {
  final List<BackupEntry> backups;

  /// `BACKUP_ALLOW_RESTORE` côté serveur — l'UI doit masquer le bouton de
  /// restauration si false pour éviter un 403 systématique.
  final bool restoreEnabled;

  /// Politique de rétention (métadonnée libre : `days`, `maxCount`, …).
  final Map<String, dynamic> retention;

  const BackupsPage({
    this.backups = const [],
    this.restoreEnabled = false,
    this.retention = const {},
  });

  factory BackupsPage.fromJson(Map<String, dynamic> json) => BackupsPage(
        backups: (json['backups'] as List?)
                ?.whereType<Map>()
                .map((e) => BackupEntry.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        restoreEnabled: json['restoreEnabled'] == true,
        retention: (json['retention'] as Map?)?.cast<String, dynamic>() ??
            const {},
      );
}

class BackupsException implements Exception {
  final String message;
  final int? statusCode;

  const BackupsException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class BackupsApi {
  final ApiClient client;

  BackupsApi(this.client);

  Future<BackupsPage> list() async {
    final res = await client.dio.get('/super-admin/backups');
    final body = client.handle(res);
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    return BackupsPage.fromJson(data);
  }

  Future<BackupEntry> create() async {
    final res = await client.dio.post('/super-admin/backup');
    final body = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || body['success'] == false) {
      throw BackupsException(
        body['message']?.toString() ?? 'Lancement de la sauvegarde impossible',
        statusCode: status,
      );
    }
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final raw = (data['backup'] as Map?)?.cast<String, dynamic>() ?? const {};
    return BackupEntry.fromJson(raw);
  }

  /// Télécharge le dump sous forme d'octets. L'appelant est responsable de
  /// la persistance (fichier temporaire, partage, …). `ResponseType.bytes`
  /// contourne le JSON decoder par défaut de Dio.
  Future<List<int>> download(String backupId) async {
    final res = await client.dio.get<List<int>>(
      '/super-admin/backups/$backupId/download',
      options: Options(
        responseType: ResponseType.bytes,
        // Un dump peut dépasser le timeout standard : on laisse Dio patienter.
        receiveTimeout: const Duration(minutes: 15),
        // Un backup contient toute la base : jamais depuis le cache offline,
        // même si la whitelist évoluait plus tard.
        extra: {OfflineAccessInterceptor.onlineOnly: true},
      ),
    );
    final status = res.statusCode ?? 500;
    if (status >= 400 || res.data == null) {
      throw BackupsException(
        'Téléchargement refusé (HTTP $status)',
        statusCode: status,
      );
    }
    return res.data!;
  }

  /// Confirmation en dur côté serveur : `body.confirmation === 'RESTORE'`.
  Future<void> restore(String backupId) async {
    final res = await client.dio.post('/super-admin/restore', data: {
      'backupId': backupId,
      'confirmation': 'RESTORE',
    });
    final body = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || body['success'] == false) {
      throw BackupsException(
        body['message']?.toString() ?? 'Restauration impossible',
        statusCode: status,
      );
    }
  }
}
