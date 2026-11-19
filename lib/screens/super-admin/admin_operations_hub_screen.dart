// lib/screens/super-admin/admin_operations_hub_screen.dart
//
// ADM-1 + OPS-3 + OPS-4 — Hub super_admin agrégé en 6 onglets :
//   1. Métriques pilote 14j
//   2. Health intégrations
//   3. Webhooks sortants
//   4. Arrêts atteints (stop events)
//   5. Correspondances récentes
//   6. Fraude (scores live + alertes persistées)
//
// Chaque onglet consomme son provider dédié.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/admin_operations_provider.dart';
import '../../services/api/admin_operations_api.dart';
import '../../services/api/fraud_api.dart';
import '../../services/api/client.dart';
import '../../theme/app_theme.dart';

class AdminOperationsHubScreen extends ConsumerWidget {
  const AdminOperationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
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
              Tab(icon: Icon(Icons.gavel), text: 'Fraude'),
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
            _FraudTab(),
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
      'ok' => AppTheme.green500,
      'degraded' => AppTheme.amber500,
      'fail' => AppTheme.red400,
      _ => AppTheme.slate400,
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
            color: configured ? AppTheme.successColor : AppTheme.amber500,
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
        color: configured ? AppTheme.successColor : AppTheme.amber500,
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
                'delivered' => AppTheme.green500,
                'failed' => AppTheme.red400,
                'pending' => AppTheme.amber500,
                _ => AppTheme.slate400,
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
                'completed' => AppTheme.green500,
                'cancelled' => AppTheme.red400,
                'pending_pickup' => AppTheme.amber500,
                _ => AppTheme.slate400,
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

// ─────────────────────────────────────────────────────────────────────
// Onglet 6 — Fraude : scores live + alertes persistées (web parité)
// ─────────────────────────────────────────────────────────────────────
class _FraudTab extends StatefulWidget {
  const _FraudTab();

  @override
  State<_FraudTab> createState() => _FraudTabState();
}

enum _FraudView { scores, open, resolved }

class _FraudTabState extends State<_FraudTab> {
  late final FraudApi _api;
  _FraudView _view = _FraudView.scores;
  Future<List<FraudScore>>? _scoresFuture;
  Future<List<FraudAlert>>? _openFuture;
  Future<List<FraudAlert>>? _resolvedFuture;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _api = FraudApi(ApiClient());
    _scoresFuture = _api.fetchScores();
    _openFuture = _api.fetchAlerts(status: 'open');
    _resolvedFuture = _api.fetchAlerts(status: 'resolved');
  }

  void _reload() {
    setState(() {
      _scoresFuture = _api.fetchScores();
      _openFuture = _api.fetchAlerts(status: 'open');
      _resolvedFuture = _api.fetchAlerts(status: 'resolved');
    });
  }

  Future<void> _refreshAlerts() async {
    setState(() => _refreshing = true);
    try {
      final result = await _api.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rafraîchissement : ${result.scanned} scannés · '
            '${result.created} nouvelles alertes · ${result.skipped} ignorés.',
          ),
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du rafraîchissement : $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _resolveAlert(FraudAlert alert) async {
    final controller = TextEditingController(text: alert.notes ?? '');
    final notes = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Résoudre l’alerte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.user?.fullName ?? alert.userId,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Notes (motif de résolution)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Résoudre'),
          ),
        ],
      ),
    );
    if (notes == null) return;
    try {
      await _api.resolveAlert(alert.id, notes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerte résolue.')),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<_FraudView>(
                  segments: const [
                    ButtonSegment(value: _FraudView.scores, label: Text('Scores')),
                    ButtonSegment(value: _FraudView.open, label: Text('Ouvertes')),
                    ButtonSegment(value: _FraudView.resolved, label: Text('Résolues')),
                  ],
                  selected: {_view},
                  onSelectionChanged: (s) => setState(() => _view = s.first),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Rafraîchir les alertes',
                onPressed: _refreshing ? null : _refreshAlerts,
                icon: _refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _reload(),
            child: switch (_view) {
              _FraudView.scores => _ScoresList(future: _scoresFuture),
              _FraudView.open => _AlertsList(
                  future: _openFuture,
                  showResolve: true,
                  onResolve: _resolveAlert,
                  emptyLabel: 'Aucune alerte ouverte.',
                ),
              _FraudView.resolved => _AlertsList(
                  future: _resolvedFuture,
                  showResolve: false,
                  onResolve: _resolveAlert,
                  emptyLabel: 'Aucune alerte résolue.',
                ),
            },
          ),
        ),
      ],
    );
  }
}

class _ScoresList extends StatelessWidget {
  final Future<List<FraudScore>>? future;
  const _ScoresList({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FraudScore>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ListView(padding: const EdgeInsets.all(24), children: [Text('Erreur : ${snap.error}')]);
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: const [Text('Aucun score à afficher.')],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final s = rows[i];
            return Card(
              child: ListTile(
                leading: _levelDot(s.level),
                title: Text('${s.name} · ${fraudLevelLabel(s.level)}'),
                subtitle: Text(
                  '${s.role} · ${s.phone}${s.flags.isEmpty ? '' : '\n${s.flags.join(" · ")}'}',
                  style: const TextStyle(fontSize: 12.5),
                ),
                trailing: Text(
                  '${s.score}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _levelColor(s.level),
                  ),
                ),
                isThreeLine: s.flags.isNotEmpty,
              ),
            );
          },
        );
      },
    );
  }
}

class _AlertsList extends StatelessWidget {
  final Future<List<FraudAlert>>? future;
  final bool showResolve;
  final void Function(FraudAlert) onResolve;
  final String emptyLabel;

  const _AlertsList({
    required this.future,
    required this.showResolve,
    required this.onResolve,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FraudAlert>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ListView(padding: const EdgeInsets.all(24), children: [Text('Erreur : ${snap.error}')]);
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [Text(emptyLabel)],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final a = rows[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _levelDot(a.level),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.user?.fullName ?? a.userId,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${a.user?.role ?? '-'} · ${a.user?.phone ?? ''}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${a.score} · ${fraudLevelLabel(a.level)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _levelColor(a.level),
                          ),
                        ),
                      ],
                    ),
                    if (a.flags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: a.flags
                            .map((f) => Chip(
                                  label: Text(f, style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ))
                            .toList(),
                      ),
                    ],
                    if (a.notes != null && a.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.slate50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          a.notes!,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                    if (a.resolvedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Résolue le ${_shortDate(a.resolvedAt)} par ${a.resolvedBy?.fullName ?? '—'}',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.slate500),
                      ),
                    ],
                    if (showResolve) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => onResolve(a),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Résoudre'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _shortDate(DateTime? dt) {
  if (dt == null) return '-';
  final local = dt.toLocal();
  return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

Widget _levelDot(FraudLevel level) {
  return Icon(Icons.circle, size: 14, color: _levelColor(level));
}

Color _levelColor(FraudLevel level) {
  switch (level) {
    case FraudLevel.high:
      return AppTheme.red400;
    case FraudLevel.medium:
      return AppTheme.amber500;
    case FraudLevel.low:
      return AppTheme.amber500;
    case FraudLevel.safe:
      return AppTheme.slate400;
  }
}
