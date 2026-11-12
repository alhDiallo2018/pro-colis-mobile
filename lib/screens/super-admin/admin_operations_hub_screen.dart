// lib/screens/super-admin/admin_operations_hub_screen.dart
//
// ADM-1 + OPS-3 + OPS-4 — Hub super_admin agrégé en 5 onglets :
//   1. Métriques pilote 14j
//   2. Health intégrations
//   3. Webhooks sortants
//   4. Arrêts atteints (stop events)
//   5. Correspondances récentes
//
// Chaque onglet consomme son provider dédié.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/admin_operations_provider.dart';
import '../../services/api/admin_operations_api.dart';

class AdminOperationsHubScreen extends ConsumerWidget {
  const AdminOperationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Opérations admin'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.insights), text: 'Pilote 14j'),
              Tab(icon: Icon(Icons.health_and_safety), text: 'Intégrations'),
              Tab(icon: Icon(Icons.webhook), text: 'Webhooks'),
              Tab(icon: Icon(Icons.flag), text: 'Arrêts'),
              Tab(icon: Icon(Icons.swap_horiz), text: 'Handovers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _Pilot14dTab(),
            _IntegrationsHealthTab(),
            _WebhooksTab(),
            _StopEventsTab(),
            _HandoversTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Onglet 1 — Métriques pilote 14j
// ─────────────────────────────────────────────────────────────────────
class _Pilot14dTab extends ConsumerWidget {
  const _Pilot14dTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminPilot14dProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminPilot14dProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [Text('Erreur : $err')],
        ),
        data: (m) => _renderMetrics(context, m),
      ),
    );
  }

  Widget _renderMetrics(BuildContext context, Pilot14dMetrics metrics) {
    final raw = metrics.raw;
    final window = (raw['window'] as Map?)?.cast<String, dynamic>() ?? {};
    final sections = <_MapSection>[
      _MapSection('Colis par statut', raw['parcels']),
      _MapSection('Correspondances par statut', raw['handovers']),
      _MapSection('Webhooks par statut', raw['webhooks']),
      _MapSection('WhatsApp par statut', raw['whatsapp']),
      _MapSection('Anomalies par type', raw['anomalies']),
      _MapSection('Lots B2B par statut', raw['shipmentBatches']),
    ];
    final scalars = <MapEntry<String, String>>[
      MapEntry('Arrêts atteints', '${raw['stopEvents'] ?? 0}'),
      MapEntry('Offres acceptées', '${raw['offersAccepted'] ?? 0}'),
      MapEntry('Déclarations signées', '${raw['customsSigned'] ?? 0}'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fenêtre : ${window['days'] ?? 14} jours',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Du ${_short(window['from'])} au ${_short(window['to'])}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final s in scalars)
                  ListTile(
                    dense: true,
                    title: Text(s.key),
                    trailing: Text(s.value,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
              ],
            ),
          ),
        ),
        for (final sec in sections)
          if (sec.data is Map && (sec.data as Map).isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sec.title,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    for (final e in (sec.data as Map).entries)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.key.toString()),
                        trailing: Text('${e.value}'),
                      ),
                  ],
                ),
              ),
            ),
          ],
      ],
    );
  }

  String _short(dynamic iso) {
    final dt = DateTime.tryParse(iso?.toString() ?? '');
    if (dt == null) return '-';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _MapSection {
  final String title;
  final dynamic data;
  const _MapSection(this.title, this.data);
}

// ─────────────────────────────────────────────────────────────────────
// Onglet 2 — Health intégrations
// ─────────────────────────────────────────────────────────────────────
class _IntegrationsHealthTab extends ConsumerWidget {
  const _IntegrationsHealthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(integrationsHealthProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(integrationsHealthProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [Text('Erreur : $err')],
        ),
        data: (h) => _renderHealth(context, h),
      ),
    );
  }

  Widget _renderHealth(BuildContext context, IntegrationsHealth h) {
    final color = switch (h.status) {
      'ok' => Colors.green,
      'degraded' => Colors.orange,
      'fail' => Colors.red,
      _ => Colors.grey,
    };
    final integrations = h.integrations;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: color.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.circle, color: color, size: 20),
                const SizedBox(width: 8),
                Text('Statut global : ${h.status.toUpperCase()}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in integrations.entries)
          _integrationRow(context, entry.key, entry.value),
      ],
    );
  }

  Widget _integrationRow(BuildContext context, String key, dynamic value) {
    // Carriers est une liste, les autres sont des objets { configured, missing }.
    if (value is List) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(key, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final item in value.whereType<Map>()) _carrierRow(context, item.cast<String, dynamic>()),
            ],
          ),
        ),
      );
    }
    if (value is Map) {
      final configured = value['configured'] == true;
      final missing = (value['missing'] as List?)?.whereType<String>().toList() ?? const [];
      return Card(
        child: ListTile(
          leading: Icon(
            configured ? Icons.check_circle : Icons.warning_amber,
            color: configured ? Colors.green : Colors.orange,
          ),
          title: Text(key),
          subtitle: configured
              ? const Text('Configuré')
              : Text('Manque : ${missing.join(", ")}'),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _carrierRow(BuildContext context, Map<String, dynamic> c) {
    final configured = c['configured'] == true;
    final missing = (c['missing'] as List?)?.whereType<String>().toList() ?? const [];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        configured ? Icons.check_circle : Icons.warning_amber,
        color: configured ? Colors.green : Colors.orange,
        size: 20,
      ),
      title: Text(c['carrier']?.toString() ?? ''),
      subtitle: configured ? null : Text('Manque : ${missing.join(", ")}'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Onglet 3 — Webhooks sortants récents
// ─────────────────────────────────────────────────────────────────────
class _WebhooksTab extends ConsumerWidget {
  const _WebhooksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminRecentWebhooksProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminRecentWebhooksProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ListView(padding: const EdgeInsets.all(24), children: [Text('Erreur : $err')]),
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(padding: const EdgeInsets.all(24), children: const [Text('Aucun webhook récent.')]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final r = rows[i];
              final color = switch (r.status) {
                'delivered' => Colors.green,
                'failed' => Colors.red,
                'pending' => Colors.orange,
                _ => Colors.grey,
              };
              return Card(
                child: ListTile(
                  leading: Icon(Icons.circle, color: color, size: 14),
                  title: Text('${r.partnerName} · ${r.eventType}'),
                  subtitle: Text(
                    'Statut : ${r.status} · tentatives ${r.attempts}'
                    '${r.lastStatusCode != null ? ' · HTTP ${r.lastStatusCode}' : ''}',
                  ),
                  trailing: Text(_short(r.createdAt)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _short(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Onglet 4 — Arrêts atteints
// ─────────────────────────────────────────────────────────────────────
class _StopEventsTab extends ConsumerWidget {
  const _StopEventsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminRecentStopEventsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminRecentStopEventsProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ListView(padding: const EdgeInsets.all(24), children: [Text('Erreur : $err')]),
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(padding: const EdgeInsets.all(24), children: const [Text('Aucun arrêt récent.')]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final r = rows[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${r.stopOrder}')),
                  title: Text(r.stopLabel ?? 'Arrêt ${r.stopOrder}'),
                  subtitle: Text(
                    'Trajet ${r.advertisementId.substring(0, 8)}… · ${r.distanceMeters} m / ${r.radiusMeters} m',
                  ),
                  trailing: Text(_short(r.reachedAt)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _short(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Onglet 5 — Handovers récents
// ─────────────────────────────────────────────────────────────────────
class _HandoversTab extends ConsumerWidget {
  const _HandoversTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminRecentHandoversProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminRecentHandoversProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ListView(padding: const EdgeInsets.all(24), children: [Text('Erreur : $err')]),
        data: (rows) {
          if (rows.isEmpty) {
            return ListView(padding: const EdgeInsets.all(24), children: const [Text('Aucune correspondance récente.')]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final h = rows[i];
              final color = switch (h.status) {
                'completed' => Colors.green,
                'cancelled' => Colors.red,
                'pending_pickup' => Colors.orange,
                _ => Colors.grey,
              };
              return Card(
                child: ListTile(
                  leading: Icon(Icons.swap_horiz, color: color),
                  title: Text(h.trackingNumber ?? h.parcelId.substring(0, 8)),
                  subtitle: Text(
                    'Statut : ${h.status}'
                    '${h.cancellationReason != null ? ' · ${h.cancellationReason}' : ''}',
                  ),
                  trailing: Text(_short(h.initiatedAt)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _short(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
