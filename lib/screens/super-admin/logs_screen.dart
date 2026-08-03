// lib/screens/super-admin/logs_screen.dart
//
// Journaux techniques — parité avec `ProColis-Web/src/features/shared/
// observability/LogsScreen.tsx`.
//
// Écran partagé par le super administrateur et le support technique. Ce dernier
// reçoit du serveur une vue réduite (ni message d'erreur, ni stack, ni
// contexte, ni `userId`) : le bandeau d'explication est piloté par le drapeau
// `redacted` renvoyé par l'API, jamais par le rôle lu côté client — c'est le
// serveur qui décide, et lui seul.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/observability.dart';
import '../../providers/observability_provider.dart';
import '../../services/api/observability_api.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/pc_components.dart';

/// Fenêtres proposées. Le serveur refuse au-delà de 14 jours ; on s'arrête donc
/// à 7 jours, la dernière valeur qui laisse une marge à la requête.
enum _LogRange {
  lastHour('1 h', Duration(hours: 1)),
  last6Hours('6 h', Duration(hours: 6)),
  last24Hours('24 h', Duration(days: 1)),
  last7Days('7 j', Duration(days: 7));

  final String label;
  final Duration duration;
  const _LogRange(this.label, this.duration);
}

class LogsScreen extends ConsumerStatefulWidget {
  /// En mode intégré, l'écran est rendu dans un onglet et n'affiche pas sa
  /// propre barre d'application.
  final bool embedded;

  const LogsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();
  _LogRange _range = _LogRange.lastHour;

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
      ref.read(logListProvider.notifier).loadMore();
    }
  }

  /// Recalcule la fenêtre à chaque application de filtre : sur un écran de
  /// supervision, « la dernière heure » doit rester la dernière heure, pas
  /// l'heure qui précédait l'ouverture de l'écran.
  void _updateFilters(LogFilters Function(LogFilters) transform) {
    final now = DateTime.now();
    final current = ref.read(logFiltersProvider);
    ref.read(logFiltersProvider.notifier).state = transform(current).copyWith(
      from: now.subtract(_range.duration),
      to: now,
    );
  }

  Future<void> _refresh() async {
    _updateFilters((f) => f);
    // `logFiltersProvider` reconstruit le notifier et le résumé : le simple fait
    // de réécrire les bornes suffit à tout relancer.
    await ref.read(logListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(logListProvider);
    final summary = ref.watch(observabilitySummaryProvider);

    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summary.when(
                  loading: () => const _SummarySkeleton(),
                  error: (error, _) => _SummaryError(error: error),
                  data: (data) => _SummaryCards(summary: data),
                ),
                summary.maybeWhen(
                  data: (data) => _ServiceStrip(services: data.services),
                  orElse: () => const SizedBox.shrink(),
                ),
                if (state.isRedacted) const _RedactedBanner(),
                _filters(state),
              ],
            ),
          ),
          if (state.isLoading)
            const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          if (state.error != null && state.entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(
                error: state.error!,
                onRetry: () => ref.read(logListProvider.notifier).refresh(),
              ),
            )
          else if (state.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: PcEmptyState(
                icon: Icons.fact_check_rounded,
                title: 'Aucune entrée',
                message:
                    'Rien n\'a été journalisé sur cette période avec ces filtres.',
                tone: PcTone.green,
              ),
            )
          else
            SliverList.separated(
              itemCount: state.entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => Padding(
                padding: EdgeInsets.fromLTRB(12, i == 0 ? 4 : 0, 12, 0),
                child: _LogTile(entry: state.entries[i]),
              ),
            ),
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          // Une erreur survenue en chargeant la page suivante ne doit pas
          // effacer les entrées déjà lues : elle s'affiche en pied de liste.
          if (state.error != null && state.entries.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _InlineError(
                  message: state.error!.message,
                  onRetry: () => ref.read(logListProvider.notifier).loadMore(),
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
        title: const Text('Journaux techniques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _refresh,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _filters(LogListState state) {
    final filters = ref.watch(logFiltersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Rechercher dans les journaux ou un request ID',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _search.clear();
                        _updateFilters((f) =>
                            f.copyWith(query: '', requestId: ''));
                        setState(() {});
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: _applySearch,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final range in _LogRange.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(range.label),
                    selected: _range == range,
                    onSelected: (_) {
                      setState(() => _range = range);
                      _updateFilters((f) => f);
                    },
                  ),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              _sourceChip(null, 'Toutes sources', filters),
              for (final source in LogSource.values)
                _sourceChip(source, source.label, filters),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              for (final level in LogLevel.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(level.label),
                    selected: filters.levels.contains(level),
                    onSelected: (selected) {
                      final levels = {...filters.levels};
                      if (selected) {
                        levels.add(level);
                      } else {
                        levels.remove(level);
                      }
                      _updateFilters((f) => f.copyWith(levels: levels));
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sourceChip(LogSource? source, String label, LogFilters filters) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: filters.source == source,
        onSelected: (_) => _updateFilters(
          (f) => source == null
              ? f.copyWith(clearSource: true)
              : f.copyWith(source: source),
        ),
      ),
    );
  }

  /// Un identifiant de requête se reconnaît à sa forme : le router vers `q`
  /// donnerait zéro résultat, alors que `requestId` est un filtre exact.
  void _applySearch(String value) {
    final trimmed = value.trim();
    final looksLikeRequestId =
        RegExp(r'^[0-9a-fA-F-]{8,128}$').hasMatch(trimmed) &&
            trimmed.contains('-');
    _updateFilters(
      (f) => looksLikeRequestId
          ? f.copyWith(requestId: trimmed, query: '')
          : f.copyWith(query: trimmed, requestId: ''),
    );
  }
}

// ============================================================
// Synthèse
// ============================================================

class _SummaryCards extends StatelessWidget {
  final ObservabilitySummary summary;

  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final top = summary.topSource;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: PcStatBox(
              icon: Icons.receipt_long_rounded,
              value: formatAmount(summary.total),
              label: 'Événements',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PcStatBox(
              icon: Icons.error_outline_rounded,
              value: formatAmount(summary.actionableTotal),
              label: 'Erreurs',
              tone: summary.actionableTotal > 0 ? PcTone.red : PcTone.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PcStatBox(
              icon: Icons.dns_rounded,
              value: top == null ? '—' : LogSource.labelOf(top.key),
              label: 'Source principale',
              tone: PcTone.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
}

class _SummaryError extends StatelessWidget {
  final Object error;

  const _SummaryError({required this.error});

  @override
  Widget build(BuildContext context) {
    final message = error is ObservabilityApiException
        ? (error as ObservabilityApiException).message
        : 'Résumé indisponible';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: _Banner(
        icon: Icons.info_outline_rounded,
        color: AppTheme.amber700,
        title: 'Synthèse indisponible',
        message: message,
      ),
    );
  }
}

/// Bandeau d'état des services supervisés par Prometheus.
class _ServiceStrip extends StatelessWidget {
  final List<ServiceHealth> services;

  const _ServiceStrip({required this.services});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          for (final service in services)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PcBadge(
                service.label,
                tone: service.status.tone,
                icon: service.status == ServiceStatus.healthy
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
              ),
            ),
        ],
      ),
    );
  }
}

/// Vue réduite : le serveur a retiré le détail technique.
class _RedactedBanner extends StatelessWidget {
  const _RedactedBanner();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: _Banner(
          icon: Icons.shield_rounded,
          color: AppTheme.teal600,
          title: 'Vue restreinte',
          message:
              'Le détail technique (message d\'erreur, trace, contexte et '
              'utilisateur concerné) est réservé au super administrateur. Le '
              'type et le code d\'erreur restent affichés pour le triage.',
        ),
      );
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(message,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ============================================================
// Ligne de journal
// ============================================================

class _LogTile extends StatefulWidget {
  final LogEntry entry;

  const _LogTile({required this.entry});

  @override
  State<_LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<_LogTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final request = entry.requestSummary;

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
            onTap: entry.hasDetail ? () => setState(() => _open = !_open) : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PcBadge(entry.severity.label, tone: entry.severity.tone),
                      const SizedBox(width: 8),
                      Text(entry.sourceLabel,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary)),
                      const Spacer(),
                      Text(
                        formatDateTime(entry.timestamp),
                        style: AppTheme.mono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.slate500),
                      ),
                      if (entry.hasDetail)
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
                    entry.message.isEmpty ? '(sans message)' : entry.message,
                    maxLines: _open ? null : 2,
                    overflow: _open ? null : TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, height: 1.35),
                  ),
                  if (request.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      request,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.slate500),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_open) _detail(entry),
        ],
      ),
    );
  }

  Widget _detail(LogEntry entry) {
    final error = entry.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PcDivider(),
          const SizedBox(height: 8),
          if (entry.requestId != null)
            _field('Request ID', entry.requestId!, monospace: true),
          if (entry.environment != null)
            _field('Environnement', entry.environment!),
          if (entry.userId != null)
            _field('Utilisateur', entry.userId!, monospace: true),
          if (error != null && !error.isEmpty) ...[
            if (error.shortLabel.isNotEmpty)
              _field('Erreur', error.shortLabel, monospace: true),
            if (error.message != null) _field('Message', error.message!),
            if (error.stack != null) _block('Trace', error.stack!),
          ],
          if (entry.context != null && entry.context!.isNotEmpty)
            _block('Contexte', _prettyJson(entry.context!)),
          if (entry.redacted)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Trace, contexte et utilisateur masqués par le serveur.',
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
              width: 96,
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

  Widget _block(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate500)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 240),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  value,
                  style: AppTheme.mono(
                      fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      );
}

/// Rendu lisible d'un contexte. Une paire par ligne plutôt qu'un encodage
/// JSON : le contexte du logger peut contenir une valeur non sérialisable, et
/// `jsonEncode` lèverait alors au lieu d'afficher la ligne.
String _prettyJson(Map<String, dynamic> data) {
  final buffer = StringBuffer();
  data.forEach((key, value) => buffer.writeln('$key: $value'));
  return buffer.toString().trimRight();
}

// ============================================================
// Erreurs
// ============================================================

class _ErrorState extends StatelessWidget {
  final ObservabilityApiException error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Chaque cause appelle un message et une action différents : proposer
    // « Réessayer » sur un 403 ferait tourner l'utilisateur en rond.
    late final IconData icon;
    late final String title;
    late final String message;
    if (error.isForbidden) {
      icon = Icons.lock_rounded;
      title = 'Accès refusé';
      message = 'Votre rôle ne donne pas accès aux journaux techniques.';
    } else if (error.isUnavailable) {
      icon = Icons.cloud_off_rounded;
      title = 'Supervision injoignable';
      message =
          'La collecte des journaux ne répond pas. L\'application, elle, '
          'fonctionne normalement.';
    } else if (error.isRateLimited) {
      icon = Icons.timer_rounded;
      title = 'Trop de consultations';
      message = 'Patientez une minute avant de relancer la recherche.';
    } else if (error.isInvalidQuery) {
      icon = Icons.filter_alt_off_rounded;
      title = 'Filtres refusés';
      message = error.message;
    } else {
      icon = Icons.error_outline_rounded;
      title = 'Journaux indisponibles';
      message = error.message;
    }

    return PcEmptyState(
      icon: icon,
      title: title,
      message: message,
      tone: error.isForbidden ? PcTone.neutral : PcTone.red,
      action: error.isForbidden
          ? null
          : PcButton('Réessayer', onPressed: onRetry),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.error)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      );
}
