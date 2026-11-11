// lib/screens/super-admin/pilot_metrics_screen.dart
//
// Lecture `GET /super-admin/pilot-metrics` : snapshot agrégé des KPI du
// pilote (parrainages, assurance, clés API, et bientôt WhatsApp /
// anomalies / SLA / IA). Les sections optionnelles non alimentées par le
// backend s'affichent en état « en attente », pas en erreur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/api/client.dart';
import '../../services/api/pilot_metrics_api.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

class PilotMetricsScreen extends ConsumerStatefulWidget {
  const PilotMetricsScreen({super.key});

  @override
  ConsumerState<PilotMetricsScreen> createState() =>
      _PilotMetricsScreenState();
}

class _PilotMetricsScreenState extends ConsumerState<PilotMetricsScreen> {
  late final PilotMetricsApi _api = PilotMetricsApi(ApiClient());

  PilotMetrics? _metrics;
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
      final data = await _api.fetch();
      if (!mounted) return;
      setState(() {
        _metrics = data;
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

  String _pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)} %';

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Métriques pilote'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
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
              : metrics == null
                  ? const EmptyState(
                      icon: Icons.insights_rounded,
                      title: 'Aucune donnée',
                      message: 'Les métriques ne sont pas disponibles.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          _computedAtBanner(metrics),
                          const SizedBox(height: 14),
                          _referralsSection(metrics),
                          const SizedBox(height: 14),
                          _insuranceSection(metrics),
                          const SizedBox(height: 14),
                          _apiKeysSection(metrics),
                          const SizedBox(height: 14),
                          _whatsAppSection(metrics),
                          const SizedBox(height: 14),
                          _aiAssistantSection(metrics),
                          const SizedBox(height: 14),
                          _anomaliesSection(metrics),
                          const SizedBox(height: 14),
                          _slaSection(metrics),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
    );
  }

  Widget _computedAtBanner(PilotMetrics m) {
    final ts = m.computedAt;
    final label = ts == null
        ? 'Snapshot temps réel'
        : 'Snapshot ${DateFormat('d MMM · HH:mm', 'fr').format(ts.toLocal())}';
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(Icons.schedule_rounded, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: AppFonts.manrope(
                  fontSize: 13, color: AppTheme.textSecondary)),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String title, IconData icon,
      {String? subtitle, bool pending = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              if (subtitle != null)
                Text(subtitle,
                    style: AppFonts.manrope(
                        fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        if (pending)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppTheme.amber500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999)),
            child: Text('En attente',
                style: AppFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.amber500)),
          ),
      ]),
    );
  }

  Widget _referralsSection(PilotMetrics m) {
    final r = m.referrals;
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Parrainages', Icons.card_giftcard_rounded,
              subtitle: 'Programme de recrutement'),
          _metricsRow([
            _Metric('Total', '${r.total}', AppTheme.primary),
            _Metric('En attente', '${r.pending}', AppTheme.amber500),
            _Metric('Déclenchés', '${r.triggered}', AppTheme.successColor),
            _Metric('Conversion', _pct(r.conversionPercent), AppTheme.teal500),
          ]),
        ],
      ),
    );
  }

  Widget _insuranceSection(PilotMetrics m) {
    final i = m.insurance;
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Assurance colis', Icons.verified_user_rounded),
          _metricsRow([
            _Metric('Actives', '${i.active}', AppTheme.successColor),
            _Metric('Sinistres', '${i.claimed}', AppTheme.red400),
            _Metric('Annulées', '${i.cancelled}', AppTheme.slate500),
            _Metric('Taux sinistre', _pct(i.claimRatePercent), AppTheme.amber500),
          ]),
        ],
      ),
    );
  }

  Widget _apiKeysSection(PilotMetrics m) {
    final k = m.apiKeys;
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Clés API partenaires', Icons.vpn_key_rounded),
          _metricsRow([
            _Metric('Actives', '${k.active}', AppTheme.successColor),
            _Metric('Total', '${k.total}', AppTheme.primary),
          ]),
        ],
      ),
    );
  }

  Widget _whatsAppSection(PilotMetrics m) {
    final w = m.whatsapp;
    if (w == null) {
      return PcCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader('Notifications WhatsApp',
                Icons.chat_bubble_outline_rounded,
                subtitle: 'Nécessite callback Meta activé', pending: true),
            Text(
                'Les compteurs seront alimentés quand le webhook de statut Meta sera branché.',
                style: AppFonts.manrope(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
              'Notifications WhatsApp', Icons.chat_bubble_outline_rounded),
          _metricsRow([
            _Metric('Envoyés', '${w.sent}', AppTheme.primary),
            _Metric('Livrés', '${w.delivered}', AppTheme.successColor),
            _Metric('Lus', '${w.read}', AppTheme.teal500),
          ]),
          const SizedBox(height: 8),
          _metricsRow([
            _Metric('Taux livré', _pct(w.deliveryRatePercent), AppTheme.teal500),
            _Metric('Taux lu', _pct(w.readRatePercent), AppTheme.amber500),
          ]),
        ],
      ),
    );
  }

  Widget _aiAssistantSection(PilotMetrics m) {
    final a = m.aiAssistant;
    if (a == null) {
      return PcCard(
        padding: const EdgeInsets.all(14),
        child: _sectionHeader('Assistant IA', Icons.auto_awesome_rounded,
            subtitle: 'Compteurs à brancher', pending: true),
      );
    }
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Assistant IA', Icons.auto_awesome_rounded),
          _metricsRow([
            _Metric('Requêtes', '${a.requested}', AppTheme.primary),
            _Metric('Complétées', '${a.completed}', AppTheme.successColor),
            _Metric('Succès', _pct(a.successRatePercent), AppTheme.teal500),
          ]),
        ],
      ),
    );
  }

  Widget _anomaliesSection(PilotMetrics m) {
    final an = m.anomalies;
    if (an == null) {
      return PcCard(
        padding: const EdgeInsets.all(14),
        child: _sectionHeader('Anomalies trajet', Icons.warning_amber_rounded,
            subtitle: 'Compteurs à alimenter depuis les logs', pending: true),
      );
    }
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Anomalies trajet', Icons.warning_amber_rounded),
          _metricsRow([
            _Metric('Silence GPS', '${an.gpsSilence}', AppTheme.amber500),
            _Metric('Arrêt long', '${an.prolongedStop}', AppTheme.red400),
            _Metric('Déviation', '${an.routeDeviation}', AppTheme.teal500),
            _Metric('Total', '${an.total}', AppTheme.textPrimary),
          ]),
        ],
      ),
    );
  }

  Widget _slaSection(PilotMetrics m) {
    final s = m.sla;
    if (s == null) {
      return PcCard(
        padding: const EdgeInsets.all(14),
        child: _sectionHeader('SLA livraisons', Icons.timer_outlined,
            subtitle: 'Alimenté par les livraisons achevées', pending: true),
      );
    }
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('SLA livraisons', Icons.timer_outlined),
          _metricsRow([
            _Metric('Livrés', '${s.delivered}', AppTheme.primary),
            _Metric('À l\'heure', '${s.deliveredOnTime}', AppTheme.successColor),
            _Metric('Taux', _pct(s.onTimePercent), AppTheme.teal500),
          ]),
        ],
      ),
    );
  }

  Widget _metricsRow(List<_Metric> items) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(items[i].value,
                    style: AppFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: items[i].color)),
                const SizedBox(height: 2),
                Text(items[i].label,
                    style: AppFonts.manrope(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (i < items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final Color color;

  const _Metric(this.label, this.value, this.color);
}
