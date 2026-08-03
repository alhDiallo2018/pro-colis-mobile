// Contrat des journaux techniques et du journal d'audit.
//
// Les charges utiles reproduites ici sont celles de
// `ProColis-Api/specs/logs/observability.md` et de `serializeAuditLog`. Les cas
// « vue réduite » comptent autant que les cas complets : c'est la réponse que
// reçoit un support technique, et elle doit se lire sans planter ni mentir.

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/observability.dart';

void main() {
  group('LogLevel', () {
    test('reconnaît les huit niveaux normalisés de l\'API', () {
      const expected = [
        'debug',
        'info',
        'notice',
        'warning',
        'error',
        'critical',
        'alert',
        'emergency',
      ];
      expect(LogLevel.values.map((l) => l.value).toList(), expected);
    });

    test('un niveau inconnu retombe sur info sans écarter la ligne', () {
      expect(LogLevel.fromString('verbose'), LogLevel.info);
      expect(LogLevel.fromString(null), LogLevel.info);
    });

    test('seuls error et au-dessus appellent une action', () {
      final actionable =
          LogLevel.values.where((l) => l.isActionable).map((l) => l.value);
      expect(actionable, ['error', 'critical', 'alert', 'emergency']);
    });
  });

  group('LogEntry', () {
    final fullPayload = {
      'id': 'abc123',
      'timestamp': '2026-08-02T00:15:08.000Z',
      'severity': 'error',
      'source': 'api',
      'environment': 'production',
      'message': 'Unhandled API error',
      'requestId': '3f2a1c9e-0b44-4d1a-9f77-2c5e1a0b7d33',
      'route': '/api/v1/example',
      'method': 'GET',
      'statusCode': 500,
      'durationMs': 42,
      'userId': 'd0b2f0e4-1111-2222-3333-444455556666',
      'error': {
        'name': 'TypeError',
        'code': 'INTERNAL_ERROR',
        'message': 'Cannot read property',
        'stack': 'TypeError: ...\n  at handler',
      },
      'context': {'parcelId': 'p-1'},
    };

    test('lit une entrée complète', () {
      final entry = LogEntry.fromJson(fullPayload);
      expect(entry.severity, LogLevel.error);
      expect(entry.sourceLabel, 'API');
      expect(entry.statusCode, 500);
      expect(entry.error!.stack, contains('at handler'));
      expect(entry.redacted, isFalse);
      expect(entry.requestSummary, 'GET · /api/v1/example · 500 · 42 ms');
    });

    test('lit la vue réduite du support technique', () {
      // Ce que renvoie `redactEntryForSupport` : ni message d'erreur, ni stack,
      // ni contexte, ni userId — mais le type et le code sont conservés.
      final entry = LogEntry.fromJson({
        'id': 'abc123',
        'timestamp': '2026-08-02T00:15:08.000Z',
        'severity': 'critical',
        'source': 'postgres',
        'message': 'Unhandled API error',
        'error': {'name': 'TypeError', 'code': 'INTERNAL_ERROR'},
        'redacted': true,
      });

      expect(entry.redacted, isTrue);
      expect(entry.userId, isNull);
      expect(entry.context, isNull);
      expect(entry.error!.stack, isNull);
      expect(entry.error!.message, isNull);
      expect(entry.error!.shortLabel, 'TypeError · INTERNAL_ERROR');
      expect(entry.sourceLabel, 'PostgreSQL');
    });

    test('survit à une entrée minimale', () {
      final entry = LogEntry.fromJson({'id': 'x', 'message': ''});
      expect(entry.severity, LogLevel.info);
      expect(entry.timestamp, isNull);
      expect(entry.requestSummary, isEmpty);
      expect(entry.hasDetail, isFalse);
    });
  });

  group('ObservabilitySummary', () {
    test('agrège les compteurs et l\'état des services', () {
      final summary = ObservabilitySummary.fromJson({
        'from': '2026-08-02T00:00:00.000Z',
        'to': '2026-08-02T01:00:00.000Z',
        'total': 130,
        'byLevel': {'info': 100, 'error': 25, 'critical': 5},
        'bySource': {'api': 120, 'caddy': 10},
        'latestAt': '2026-08-02T00:59:00.000Z',
        'services': [
          {'service': 'api', 'status': 'healthy', 'checkedAt': '2026-08-02T01:00:00.000Z'},
          {'service': 'loki', 'status': 'unavailable', 'checkedAt': '2026-08-02T01:00:00.000Z'},
        ],
      });

      expect(summary.total, 130);
      expect(summary.actionableTotal, 30);
      expect(summary.topSource!.key, 'api');
      expect(summary.unavailableServices, 1);
      expect(summary.services.first.label, 'API');
      expect(summary.services.last.label, 'Collecte des journaux');
    });

    test('additionne les niveaux inconnus au lieu de les écraser', () {
      // Deux clés inconnues retombent toutes deux sur `info` : si l'une
      // écrasait l'autre, le total affiché serait faux.
      final summary = ObservabilitySummary.fromJson({
        'byLevel': {'verbose': 3, 'silly': 4, 'info': 1},
      });
      expect(summary.byLevel[LogLevel.info], 8);
    });

    test('un état de service inconnu est traité comme une panne', () {
      final health = ServiceHealth.fromJson({'service': 'api', 'status': 'degraded'});
      expect(health.status, ServiceStatus.unavailable);
    });
  });

  group('LogFilters', () {
    test('retire les filtres vides que l\'API rejetterait en 400', () {
      const filters = LogFilters(query: 'a', requestId: '   ');
      final query = filters.toQuery();
      expect(query.containsKey('q'), isFalse, reason: 'moins de 2 caractères');
      expect(query.containsKey('requestId'), isFalse);
      expect(query.containsKey('source'), isFalse);
      expect(query.containsKey('levels'), isFalse);
      expect(query['limit'], 50);
    });

    test('sérialise les niveaux en liste séparée par des virgules', () {
      const filters = LogFilters(
        source: LogSource.caddy,
        levels: {LogLevel.critical, LogLevel.error},
        query: 'timeout',
      );
      final query = filters.toQuery(cursor: 'abc');
      expect(query['source'], 'caddy');
      // Ordre stable, celui de l'enum : deux appels identiques doivent produire
      // la même URL, sinon les caches en amont se démultiplient.
      expect(query['levels'], 'error,critical');
      expect(query['q'], 'timeout');
      expect(query['cursor'], 'abc');
    });

    test('copyWith efface la source seulement sur demande explicite', () {
      const filters = LogFilters(source: LogSource.api);
      expect(filters.copyWith(query: 'x').source, LogSource.api);
      expect(filters.copyWith(clearSource: true).source, isNull);
    });
  });

  group('AuditLogEntry', () {
    test('lit une ligne complète de super administrateur', () {
      final entry = AuditLogEntry.fromJson({
        'id': 'log-1',
        'actorId': 'u-1',
        'actorRole': 'super_admin',
        'actor': {
          'id': 'u-1',
          'fullName': 'Awa Diop',
          'phone': '+221770000001',
          'role': 'super_admin',
        },
        'action': 'parcel.update',
        'entityType': 'parcel',
        'entityId': 'd0b2f0e4-1111-2222-3333-444455556666',
        'beforeData': {'weight': 3},
        'afterData': {'weight': 5},
        'hasChangeSnapshot': true,
        'ipAddress': '10.0.0.1',
        'requestId': 'req-1',
        'redacted': false,
        'createdAt': '2026-08-02T10:00:00.000Z',
      });

      expect(entry.actorLabel, 'Awa Diop');
      expect(entry.roleLabel, 'Super admin');
      expect(entry.actionLabel, 'Colis · mise à jour');
      expect(entry.hasVisibleSnapshot, isTrue);
      expect(entry.redacted, isFalse);
    });

    test('lit la ligne restreinte servie aux rôles support', () {
      // `serializeAuditLog(row, {detailed: false})` : les instantanés sont
      // absents, mais le serveur signale qu'ils existent.
      final entry = AuditLogEntry.fromJson({
        'id': 'log-2',
        'actorRole': 'admin',
        'action': 'user.delete',
        'entityType': 'user',
        'hasChangeSnapshot': true,
        'redacted': true,
        'createdAt': '2026-08-02T10:00:00.000Z',
      });

      expect(entry.redacted, isTrue);
      expect(entry.hasVisibleSnapshot, isFalse);
      expect(entry.hasChangeSnapshot, isTrue,
          reason: 'l\'écran doit pouvoir expliquer l\'absence');
      expect(entry.roleLabel, 'Admin zone');
      expect(entry.actionLabel, 'Utilisateur · suppression');
    });

    test('déduit hasChangeSnapshot des anciennes réponses sans le drapeau', () {
      final entry = AuditLogEntry.fromJson({
        'id': 'log-3',
        'action': 'zone.create',
        'entityType': 'zone',
        'afterData': {'name': 'Dakar'},
      });
      expect(entry.hasChangeSnapshot, isTrue);
    });

    test('une action sans acteur est attribuée au système', () {
      final entry = AuditLogEntry.fromJson({
        'id': 'log-4',
        'action': 'payment.paydunya.ipn',
        'entityType': 'payment',
      });
      expect(entry.roleLabel, 'Système');
      expect(entry.actorLabel, 'Système');
    });

    test('le ton distingue destruction, modification et création', () {
      PcToneOf(String action) => AuditLogEntry.fromJson({
            'id': 'x',
            'action': action,
            'entityType': 'x',
          }).tone;

      expect(PcToneOf('user.delete').name, 'red');
      expect(PcToneOf('parcel.update').name, 'amber');
      expect(PcToneOf('zone.create').name, 'green');
      expect(PcToneOf('user.login').name, 'neutral');
    });

    test('traduit les segments connus et laisse passer les autres', () {
      final entry = AuditLogEntry.fromJson({
        'id': 'x',
        'action': 'observability.export',
        'entityType': 'observability',
      });
      expect(entry.actionLabel, 'Observabilité · export');

      final unknown = AuditLogEntry.fromJson({
        'id': 'y',
        'action': 'widget.frobnicate',
        'entityType': 'widget',
      });
      expect(unknown.actionLabel, 'widget · frobnicate');
    });
  });
}
