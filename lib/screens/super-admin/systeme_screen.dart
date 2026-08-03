// lib/screens/super-admin/systeme_screen.dart
//
// Santé applicative et abonnements sortants — parité avec
// `ProColis-Web/src/features/superAdmin/SystemePage.tsx`.
//
// La sonde `/super-admin/system/health` répond **503** quand la base est
// injoignable : l'échec de la requête est donc lui-même l'information. On
// l'affiche en état dégradé, pas en écran d'erreur générique — d'où le
// `validateStatus` permissif du client Dio, qui laisse passer les 5xx.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/client.dart';
import '../../services/api/system_api.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/pc_components.dart';

class SystemeScreen extends ConsumerStatefulWidget {
  const SystemeScreen({super.key});

  @override
  ConsumerState<SystemeScreen> createState() => _SystemeScreenState();
}

class _SystemeScreenState extends ConsumerState<SystemeScreen> {
  final SystemApi _api = SystemApi(ApiClient());

  SystemHealth? _health;
  List<Webhook> _webhooks = const [];
  bool _loading = true;
  String? _webhooksError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Les deux lectures sont indépendantes : une base injoignable ne doit pas
    // empêcher de lire les webhooks, et inversement.
    SystemHealth? health;
    try {
      health = await _api.health();
    } catch (_) {
      health = const SystemHealth(status: 'degraded', database: 'unknown');
    }

    List<Webhook> webhooks = const [];
    String? webhooksError;
    try {
      webhooks = await _api.listWebhooks();
    } catch (e) {
      webhooksError =
          e is SystemApiException ? e.message : 'Webhooks indisponibles';
    }

    if (!mounted) return;
    setState(() {
      _health = health;
      _webhooks = webhooks;
      _webhooksError = webhooksError;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Système'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWebhookForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Webhook'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                children: [
                  _healthPanel(),
                  const SizedBox(height: 20),
                  _webhooksPanel(),
                ],
              ),
            ),
    );
  }

  Widget _healthPanel() {
    final health = _health ?? const SystemHealth();
    final healthy = health.isHealthy;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PcStatBox(
                icon: healthy
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                value: healthy ? 'OK' : 'Dégradé',
                label: 'État de l\'API',
                tone: healthy ? PcTone.green : PcTone.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PcStatBox(
                icon: Icons.storage_rounded,
                value: health.database == 'connected' ? 'Connectée' : 'KO',
                label: 'Base de données',
                tone: health.database == 'connected'
                    ? PcTone.green
                    : PcTone.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PcStatBox(
          icon: Icons.timer_rounded,
          value: health.uptimeLabel,
          label: 'Depuis le dernier démarrage',
          tone: PcTone.primary,
        ),
        if (health.timestamp != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Sonde du ${formatDateTime(health.timestamp)}',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _webhooksPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Abonnements sortants',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              PcBadge('${_webhooks.length}', tone: PcTone.neutral),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'L\'API poste les événements choisis vers ces adresses.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          if (_webhooksError != null)
            Text(_webhooksError!,
                style: TextStyle(fontSize: 12.5, color: AppTheme.error))
          else if (_webhooks.isEmpty)
            Text('Aucun webhook configuré.',
                style: TextStyle(fontSize: 13, color: AppTheme.slate500))
          else
            for (int i = 0; i < _webhooks.length; i++) ...[
              if (i > 0) const PcDivider(),
              _webhookRow(_webhooks[i]),
            ],
        ],
      ),
    );
  }

  Widget _webhookRow(Webhook webhook) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  webhook.url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final event in webhook.events)
                      PcBadge(event, tone: PcTone.primary),
                    if (webhook.hasSecret)
                      const PcBadge('signé',
                          tone: PcTone.green, icon: Icons.lock_rounded),
                    if (!webhook.isActive)
                      const PcBadge('inactif', tone: PcTone.red),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: AppTheme.error),
            tooltip: 'Supprimer',
            onPressed: () => _deleteWebhook(webhook),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWebhook(Webhook webhook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le webhook ?'),
        content: Text(
          'L\'API cessera de pousser des événements vers ${webhook.url}.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child:
                const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteWebhook(webhook.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(e is SystemApiException ? e.message : 'Suppression impossible');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openWebhookForm() async {
    final urlController = TextEditingController();
    final secretController = TextEditingController();
    final selected = <String>{};

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nouveau webhook',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL de destination',
                    hintText: 'https://exemple.com/hooks/procolis',
                  ),
                ),
                const SizedBox(height: 12),
                Text('Événements',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate500)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final event in SystemApi.eventChoices)
                      FilterChip(
                        label: Text(event),
                        selected: selected.contains(event),
                        onSelected: (on) => setSheetState(() {
                          if (on) {
                            selected.add(event);
                          } else {
                            selected.remove(event);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: secretController,
                  decoration: const InputDecoration(
                    labelText: 'Secret de signature (optionnel)',
                    // Le secret n'est jamais relu par l'API : le dire évite
                    // qu'on le cherche ensuite dans la liste.
                    helperText: 'Non relisible après enregistrement',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final url = urlController.text.trim();
                      if (!RegExp(r'^https?://\S+$', caseSensitive: false)
                          .hasMatch(url)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('URL http(s) valide requise')),
                        );
                        return;
                      }
                      if (selected.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Choisissez au moins un événement')),
                        );
                        return;
                      }
                      try {
                        await _api.createWebhook(
                          url: url,
                          events: selected.toList(),
                          secret: secretController.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(e is SystemApiException
                                ? e.message
                                : 'Création impossible'),
                          ),
                        );
                      }
                    },
                    child: const Text('Créer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    urlController.dispose();
    secretController.dispose();
    if (created == true) await _load();
  }
}
