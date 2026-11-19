// lib/screens/driver/backhaul_suggestions_screen.dart
//
// Suggestions de colis « backhaul » — consomme `/drivers/backhaul-matches/:id`.
// Parité avec `features/driver/BackhaulSuggestionsDialog.tsx` côté web.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/api/client.dart';
import '../../services/api/consolidation_api.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

class BackhaulSuggestionsScreen extends ConsumerStatefulWidget {
  final String advertisementId;
  final String? routeLabel;

  const BackhaulSuggestionsScreen({
    super.key,
    required this.advertisementId,
    this.routeLabel,
  });

  @override
  ConsumerState<BackhaulSuggestionsScreen> createState() =>
      _BackhaulSuggestionsScreenState();
}

class _BackhaulSuggestionsScreenState
    extends ConsumerState<BackhaulSuggestionsScreen> {
  late final ConsolidationApi _api;
  late Future<BackhaulResponse> _future;
  bool _showRejected = false;
  final Set<String> _sending = {};

  @override
  void initState() {
    super.initState();
    _api = ConsolidationApi(ApiClient());
    _future = _api.fetchBackhaulMatches(widget.advertisementId);
  }

  void _reload() {
    setState(() {
      _future = _api.fetchBackhaulMatches(widget.advertisementId);
    });
  }

  Future<void> _submitOffer(BackhaulMatch match) async {
    final price = await _promptPrice(match);
    if (price == null) return;
    setState(() => _sending.add(match.id));
    try {
      final result = await ApiService().createBid({
        'parcelId': match.id,
        'price': price,
      });
      if (!mounted) return;
      final ok = result['success'] != false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Offre envoyée au client.'
                : (result['message']?.toString() ??
                    "Erreur lors de l'envoi de l'offre."),
          ),
          backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending.remove(match.id));
    }
  }

  Future<num?> _promptPrice(BackhaulMatch match) async {
    final controller = TextEditingController(
      text: match.price != null ? match.price!.round().toString() : '',
    );
    return showDialog<num?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Proposer une offre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              match.trackingNumber ?? match.id,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prix (FCFA)',
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
            onPressed: () {
              final raw = controller.text.replaceAll(',', '.').trim();
              final n = num.tryParse(raw);
              if (n == null || n <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Prix invalide.')),
                );
                return;
              }
              Navigator.of(ctx).pop(n);
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggestions de colis'),
      ),
      body: SafeArea(
        child: FutureBuilder<BackhaulResponse>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 36, color: AppTheme.errorColor),
                      const SizedBox(height: 12),
                      Text(
                        'Impossible de charger les suggestions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.slate600),
                      ),
                      const SizedBox(height: 16),
                      PcButton(
                        'Réessayer',
                        onPressed: _reload,
                        icon: Icons.refresh_rounded,
                        variant: PcButtonVariant.secondary,
                      ),
                    ],
                  ),
                ),
              );
            }
            final data = snap.data ?? const BackhaulResponse(matches: [], rejected: []);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.routeLabel ?? 'Annonce en cours',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Colis compatibles avec votre trajet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Proposez une offre : le client la reçoit directement.',
                  style: TextStyle(fontSize: 13, color: AppTheme.slate600),
                ),
                const SizedBox(height: 16),
                if (data.matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Aucun colis compatible pour le moment.',
                        style: TextStyle(color: AppTheme.slate500),
                      ),
                    ),
                  )
                else
                  for (final m in data.matches)
                    _MatchCard(
                      match: m,
                      sending: _sending.contains(m.id),
                      onOffer: () => _submitOffer(m),
                    ),
                if (data.rejected.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => setState(() => _showRejected = !_showRejected),
                    icon: Icon(_showRejected
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded),
                    label: Text(
                      '${_showRejected ? "Masquer" : "Afficher"} les colis non compatibles (${data.rejected.length})',
                    ),
                  ),
                  if (_showRejected)
                    for (final r in data.rejected) _RejectedTile(match: r),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final BackhaulMatch match;
  final bool sending;
  final VoidCallback onOffer;

  const _MatchCard({
    required this.match,
    required this.sending,
    required this.onOffer,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PcCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    match.trackingNumber ?? match.id.substring(0, 8),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (match.score != null)
                  PcBadge('Score ${match.score}', tone: PcTone.green),
              ],
            ),
            if (match.senderName != null) ...[
              const SizedBox(height: 4),
              Text(
                match.senderName!,
                style: TextStyle(fontSize: 13, color: AppTheme.slate600),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _chip(Icons.scale_rounded, '${match.weightKg.toStringAsFixed(1)} kg'),
                if (match.price != null)
                  _chip(Icons.payments_rounded,
                      '${fmt.format(match.price!.round())} FCFA'),
                if (match.detourKm != null)
                  _chip(Icons.alt_route_rounded,
                      '${match.detourKm!.toStringAsFixed(1)} km détour'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: PcButton(
                sending ? 'Envoi…' : 'Proposer une offre',
                onPressed: sending ? null : onOffer,
                icon: Icons.send_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.slate500),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12.5, color: AppTheme.slate700)),
      ],
    );
  }
}

class _RejectedTile extends StatelessWidget {
  final BackhaulMatch match;
  const _RejectedTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final labels = match.reasons
        .map((r) => kBackhaulReasonLabels[r] ?? r)
        .join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.block_rounded, size: 14, color: AppTheme.errorColor),
          const SizedBox(width: 8),
          Text(
            match.trackingNumber ?? match.id.substring(0, 8),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              labels,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppTheme.slate500),
            ),
          ),
        ],
      ),
    );
  }
}
