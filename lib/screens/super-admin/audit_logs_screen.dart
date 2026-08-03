// lib/screens/super-admin/audit_logs_screen.dart
//
// Journal d'audit métier — parité avec `ProColis-Web/src/features/shared/
// observability/AuditLogsScreen.tsx`.
//
// Écran partagé par le super administrateur, le support transverse et le
// support technique. Hors super administrateur, l'API retire les instantanés
// avant/après et pose `redacted: true` : la ligne dit alors qui a fait quoi,
// quand et depuis où, sans le détail des valeurs métier.
//
// À ne pas confondre avec les journaux techniques (`logs_screen.dart`) : ici,
// ce sont des actions fonctionnelles d'utilisateurs, stockées en base, pas des
// traces d'exécution.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/observability.dart';
import '../../providers/observability_provider.dart';
import '../../services/api/observability_api.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/pc_components.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  /// En mode intégré, l'écran est rendu dans un onglet et n'affiche pas sa
  /// propre barre d'application.
  final bool embedded;

  const AuditLogsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  /// Rôles proposés au filtre, alignés sur `ROLE_OPTIONS` du web.
  static const Map<String, String> _roles = {
    '': 'Tous les auteurs',
    'super_admin': 'Super admin',
    'support': 'Support',
    'support_technique': 'Support technique',
    'support_commercial': 'Support commercial',
    'admin': 'Admin zone',
    'driver': 'Chauffeur',
    'client': 'Client',
  };

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) {
      ref.read(auditLogsProvider.notifier).loadMore();
    }
  }

  void _updateFilters(AuditFilters Function(AuditFilters) transform) {
    final current = ref.read(auditFiltersProvider);
    ref.read(auditFiltersProvider.notifier).state = transform(current);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditLogsProvider);
    final filters = ref.watch(auditFiltersProvider);

    final body = RefreshIndicator(
      onRefresh: () => ref.read(auditLogsProvider.notifier).refresh(),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isRedacted) const _RedactedNotice(),
                _filterBar(filters),
                if (state.total > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
                    child: Text(
                      '${formatAmount(state.total)} action'
                      '${state.total > 1 ? 's' : ''} enregistrée'
                      '${state.total > 1 ? 's' : ''}',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          if (state.isLoading)
            const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2)),
          if (state.error != null && state.entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _AuditErrorState(
                error: state.error!,
                onRetry: () => ref.read(auditLogsProvider.notifier).refresh(),
              ),
            )
          else if (state.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: PcEmptyState(
                icon: Icons.history_rounded,
                title: 'Aucune action',
                message: 'Aucune action ne correspond à ces filtres.',
              ),
            )
          else
            SliverList.separated(
              itemCount: state.entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => Padding(
                padding: EdgeInsets.fromLTRB(12, i == 0 ? 4 : 0, 12, 0),
                child: _AuditTile(entry: state.entries[i]),
              ),
            ),
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (state.error != null && state.entries.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(state.error!.message,
                            style: TextStyle(
                                fontSize: 12.5, color: AppTheme.error)),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(auditLogsProvider.notifier).loadMore(),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Journal d\'audit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: () => ref.read(auditLogsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _filterBar(AuditFilters filters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              // La recherche serveur porte sur l'action et le type d'entité :
              // le dire évite de chercher un nom d'utilisateur sans résultat.
              hintText: 'Rechercher une action ou un type d\'entité',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _search.clear();
                        _updateFilters((f) => f.copyWith(search: ''));
                        setState(() {});
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (value) =>
                _updateFilters((f) => f.copyWith(search: value.trim())),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              for (final entry in _roles.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: filters.actorRole == entry.key,
                    onSelected: (_) =>
                        _updateFilters((f) => f.copyWith(actorRole: entry.key)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Les instantanés sont masqués par le serveur pour les rôles support.
class _RedactedNotice extends StatelessWidget {
  const _RedactedNotice();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.teal600.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppTheme.teal600.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_rounded, size: 18, color: AppTheme.teal600),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vue restreinte',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.teal600)),
                    const SizedBox(height: 2),
                    Text(
                      'Le détail des valeurs modifiées est réservé au super '
                      'administrateur. Qui a fait quoi, quand et depuis quelle '
                      'adresse reste visible.',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _AuditTile extends StatefulWidget {
  final AuditLogEntry entry;

  const _AuditTile({required this.entry});

  @override
  State<_AuditTile> createState() => _AuditTileState();
}

class _AuditTileState extends State<_AuditTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: PcBadge(entry.actionLabel, tone: entry.tone),
                      ),
                      const Spacer(),
                      Text(
                        formatDateTime(entry.createdAt),
                        style: AppTheme.mono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.slate500),
                      ),
                      Icon(
                        _open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: AppTheme.slate500,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.actorLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      entry.roleLabel,
                      entry.entityType,
                      if (entry.entityId != null)
                        '${entry.entityId!.substring(
                          0,
                          entry.entityId!.length < 8
                              ? entry.entityId!.length
                              : 8,
                        )}…',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.slate500),
                  ),
                ],
              ),
            ),
          ),
          if (_open) _detail(entry),
        ],
      ),
    );
  }

  Widget _detail(AuditLogEntry entry) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PcDivider(),
          const SizedBox(height: 8),
          _field('Action', entry.action, monospace: true),
          if (entry.actor?.phone != null)
            _field('Téléphone', entry.actor!.phone!, monospace: true),
          if (entry.entityId != null)
            _field('Entité', '${entry.entityType} · ${entry.entityId}',
                monospace: true),
          if (entry.ipAddress != null)
            _field('Adresse IP', entry.ipAddress!, monospace: true),
          if (entry.requestId != null)
            _field('Request ID', entry.requestId!, monospace: true),
          if (entry.userAgent != null) _field('Client', entry.userAgent!),
          if (entry.hasVisibleSnapshot) ...[
            if (entry.beforeData != null && entry.beforeData!.isNotEmpty)
              _snapshot('Avant', entry.beforeData!),
            if (entry.afterData != null && entry.afterData!.isNotEmpty)
              _snapshot('Après', entry.afterData!),
          ] else if (entry.hasChangeSnapshot)
            // Le serveur signale l'instantané sans l'exposer : on l'explique,
            // au lieu de laisser croire que l'action n'a rien modifié.
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Cette action porte un instantané avant/après, non exposé à '
                'votre rôle.',
                style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.slate500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, String value, {bool monospace = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate500)),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: monospace
                    ? AppTheme.mono(fontSize: 11.5, fontWeight: FontWeight.w500)
                    : const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      );

  Widget _snapshot(String label, Map<String, dynamic> data) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppTheme.slate500)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  data.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n'),
                  style: AppTheme.mono(
                      fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      );
}

class _AuditErrorState extends StatelessWidget {
  final ObservabilityApiException error;
  final VoidCallback onRetry;

  const _AuditErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (error.isForbidden) {
      return const PcEmptyState(
        icon: Icons.lock_rounded,
        title: 'Accès refusé',
        message: 'Votre rôle ne donne pas accès au journal d\'audit.',
      );
    }
    return PcEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Journal indisponible',
      message: error.message,
      tone: PcTone.red,
      action: PcButton('Réessayer', onPressed: onRetry),
    );
  }
}
