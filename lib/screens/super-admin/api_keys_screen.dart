// lib/screens/super-admin/api_keys_screen.dart
//
// Panneau super-admin de gestion des clés API partenaires e-commerce.
// Expose les 5 opérations : list / create / rotate / update scopes+webhook
// / deactivate. Le secret généré par le backend ne descend qu'une seule
// fois — on l'affiche dans une boîte modale que l'opérateur peut copier.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/api/admin_api_keys_api.dart';
import '../../services/api/client.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

class ApiKeysScreen extends ConsumerStatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  ConsumerState<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends ConsumerState<ApiKeysScreen> {
  late final AdminApiKeysApi _api = AdminApiKeysApi(ApiClient());

  List<ApiKey> _keys = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keys = await _api.list();
      if (!mounted) return;
      setState(() {
        _keys = keys;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<ApiKeyWithSecret>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateApiKeySheet(api: _api),
    );
    if (created != null) {
      await _showSecretDialog(created, isRotation: false);
      await _load();
    }
  }

  Future<void> _rotate(ApiKey key) async {
    final confirm = await _confirm(
      title: 'Faire tourner la clé ?',
      body:
          'Le secret actuel de « ${key.partnerName} » sera révoqué immédiatement. '
          'Le nouveau secret ne s\'affichera qu\'une seule fois.',
      confirmLabel: 'Faire tourner',
      destructive: false,
    );
    if (confirm != true) return;
    try {
      final rotated = await _api.rotate(key.keyId);
      if (!mounted) return;
      await _showSecretDialog(rotated, isRotation: true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deactivate(ApiKey key) async {
    final confirm = await _confirm(
      title: 'Désactiver la clé ?',
      body:
          'Tout appel API du partenaire « ${key.partnerName} » sera refusé '
          'à partir de maintenant. L\'historique reste consultable.',
      confirmLabel: 'Désactiver',
      destructive: true,
    );
    if (confirm != true) return;
    try {
      await _api.deactivate(key.keyId);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppTheme.red400)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _showSecretDialog(ApiKeyWithSecret result,
      {required bool isRotation}) async {
    final secret = result.secretOnce;
    if (secret == null || secret.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isRotation ? 'Nouveau secret' : 'Clé créée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Copiez ce secret maintenant — il ne s\'affichera plus. '
                'Transmettez-le au partenaire par un canal sécurisé.',
                style: AppFonts.manrope(
                    fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            _SecretBlock(label: 'Clé API', value: secret),
            if ((result.webhookSecretOnce ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              _SecretBlock(
                  label: 'Secret webhook', value: result.webhookSecretOnce!),
            ],
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('J\'ai copié')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        // Retour robuste : pop si la pile existe, sinon on redirige
        // explicitement vers le dashboard — évite une impasse quand
        // l'écran est atteint via `context.go`.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Clés API partenaires'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _openCreate,
        icon: const Icon(Icons.vpn_key_rounded),
        label: const Text('Nouvelle clé'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  tone: AppTheme.red400,
                  title: 'Erreur',
                  message: _error,
                  action: PcButton('Réessayer', onPressed: _load),
                )
              : _keys.isEmpty
                  ? const EmptyState(
                      icon: Icons.vpn_key_outlined,
                      title: 'Aucune clé API',
                      message:
                          'Créez une clé pour qu\'un partenaire e-commerce puisse émettre des colis via l\'API publique.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(18),
                        itemCount: _keys.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _keyTile(_keys[i]),
                      ),
                    ),
    );
  }

  Widget _keyTile(ApiKey key) {
    final df = DateFormat('d MMM y · HH:mm', 'fr');
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(key.partnerName,
                  style: AppFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            _statusChip(active: key.active),
          ]),
          const SizedBox(height: 4),
          Text('ID : ${key.keyId}',
              style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: ['monospace'],
                  fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: key.scopes.isEmpty
                ? [
                    _scopeChip('aucun scope', emphasize: true),
                  ]
                : key.scopes.map((s) => _scopeChip(s)).toList(),
          ),
          if (key.webhookUrl != null && key.webhookUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.webhook_rounded,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(key.webhookUrl!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.manrope(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ),
              if (key.hasWebhookSecret)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.lock_rounded,
                      size: 14, color: AppTheme.successColor),
                ),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.history_rounded,
                size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
                key.lastUsedAt != null
                    ? 'Dernier appel ${df.format(key.lastUsedAt!.toLocal())}'
                    : 'Jamais utilisée',
                style: AppFonts.manrope(
                    fontSize: 11, color: AppTheme.textSecondary)),
            const Spacer(),
            if (key.active)
              TextButton.icon(
                onPressed: () => _rotate(key),
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Rotation'),
              ),
            if (key.active)
              TextButton.icon(
                onPressed: () => _deactivate(key),
                icon: Icon(Icons.block_rounded,
                    size: 16, color: AppTheme.red400),
                label: Text('Désactiver',
                    style: TextStyle(color: AppTheme.red400)),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _statusChip({required bool active}) {
    final color = active ? AppTheme.successColor : AppTheme.slate500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999)),
      child: Text(active ? 'Active' : 'Désactivée',
          style: AppFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _scopeChip(String scope, {bool emphasize = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: emphasize
              ? AppTheme.amber500.withValues(alpha: 0.14)
              : AppTheme.slate100,
          borderRadius: BorderRadius.circular(999)),
      child: Text(scope,
          style: AppFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: emphasize ? AppTheme.amber500 : AppTheme.textPrimary)),
    );
  }
}

class _SecretBlock extends StatelessWidget {
  final String label;
  final String value;

  const _SecretBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppTheme.slate100,
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(
              child: SelectableText(value,
                  style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: ['monospace'],
                      fontSize: 12)),
            ),
            IconButton(
              tooltip: 'Copier',
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copié')));
              },
            ),
          ]),
        ),
      ],
    );
  }
}

class _CreateApiKeySheet extends StatefulWidget {
  final AdminApiKeysApi api;
  const _CreateApiKeySheet({required this.api});

  @override
  State<_CreateApiKeySheet> createState() => _CreateApiKeySheetState();
}

class _CreateApiKeySheetState extends State<_CreateApiKeySheet> {
  final _form = GlobalKey<FormState>();
  final _partnerName = TextEditingController();
  final _webhookUrl = TextEditingController();
  final _webhookSecret = TextEditingController();
  final Set<String> _scopes = {'parcel.read'};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _partnerName.dispose();
    _webhookUrl.dispose();
    _webhookSecret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.create(
        partnerName: _partnerName.text.trim(),
        scopes: _scopes.toList(),
        webhookUrl: _webhookUrl.text.trim().isEmpty
            ? null
            : _webhookUrl.text.trim(),
        webhookSecret: _webhookSecret.text.trim().isEmpty
            ? null
            : _webhookSecret.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.slate300,
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Nouvelle clé API',
                    style: AppFonts.plusJakartaSans(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _partnerName,
                  decoration: const InputDecoration(
                      labelText: 'Nom du partenaire',
                      hintText: 'Ex. BoutiqueOnline SA'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 14),
                Text('Scopes',
                    style: AppFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children:
                      AdminApiKeysApi.scopeChoices.map((s) {
                    final selected = _scopes.contains(s);
                    return FilterChip(
                      selected: selected,
                      label: Text(s),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _scopes.add(s);
                        } else {
                          _scopes.remove(s);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _webhookUrl,
                  decoration: const InputDecoration(
                    labelText: 'Webhook (optionnel)',
                    hintText: 'https://partenaire.example/webhook',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _webhookSecret,
                  decoration: const InputDecoration(
                    labelText: 'Secret webhook (optionnel, auto si vide)',
                  ),
                  obscureText: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: TextStyle(color: AppTheme.red400, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                PcButton(
                  'Créer la clé',
                  block: true,
                  loading: _busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
