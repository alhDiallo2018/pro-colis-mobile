import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/cancellation.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pay_client_debt_sheet.dart';
import '../../widgets/pc_components.dart';

/// Les dettes sont relues sur le serveur après paiement et au retour dans
/// l'application : ouvrir PayDunya ne signifie jamais que la dette est réglée.
class ClientDebtsScreen extends StatefulWidget {
  final ApiService? api;
  const ClientDebtsScreen({super.key, this.api});

  @override
  State<ClientDebtsScreen> createState() => _ClientDebtsScreenState();
}

class _ClientDebtsScreenState extends State<ClientDebtsScreen>
    with WidgetsBindingObserver {
  late final ApiService _api = widget.api ?? ApiService();
  final _money = NumberFormat('#,##0', 'fr');
  List<Map<String, dynamic>> _debts = [];
  double? _totalDebt;
  bool _canCreateParcel = true;
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({bool more = false}) async {
    if (!mounted) return;
    final generation = ++_generation;
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.getClientDebts(page: page);
      final summary = response['summary'];
      final rows = response['debts'];
      final total =
          summary is Map ? double.tryParse('${summary['totalDebt']}') : null;
      if (response['success'] != true ||
          rows is! List ||
          total == null ||
          !total.isFinite ||
          total < 0) {
        throw const FormatException('Réponse de dettes invalide');
      }
      // Un retour PayDunya peut doubler un rafraîchissement manuel. Seule la
      // requête la plus récente peut remplacer les montants affichés.
      if (!mounted || generation != _generation) return;
      setState(() {
        final debts =
            rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _debts = more ? [..._debts, ...debts] : debts;
        _totalDebt = total;
        _canCreateParcel = summary['canCreateParcel'] == true;
        _page = page;
        _totalPages =
            (response['pagination']?['totalPages'] as num?)?.toInt() ?? page;
      });
    } catch (error, stackTrace) {
      developer.log('Chargement des dettes impossible',
          name: 'ClientDebtsScreen', error: error, stackTrace: stackTrace);
      if (!mounted || generation != _generation) return;
      setState(() =>
          _error = 'Impossible de charger vos dettes. Veuillez réessayer.');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _debtCard(Map<String, dynamic> row) {
    final debt = CancellationClientDebt.fromJson(row);
    final remaining = debt.remaining;
    final paid = debt.status == 'paid' && remaining == 0;
    final canPay = debt.hasId && remaining != null && remaining > 0 && !paid;
    final date = DateTime.tryParse('${row['createdAt']}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PcCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              row['trackingNumber']?.toString() ??
                  debt.reference ??
                  'Pénalité d’annulation',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
              [
                if (debt.reference != null) debt.reference!,
                if (date != null)
                  DateFormat('dd/MM/yyyy').format(date.toLocal()),
              ].join(' · '),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          if (row['reason']?.toString().trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(row['reason'].toString()),
          ],
          const SizedBox(height: 14),
          Text(
              paid
                  ? 'Réglée'
                  : debt.status == 'partially_paid'
                      ? 'Partiellement réglée'
                      : 'À régler',
              style: TextStyle(
                  color: paid ? AppTheme.green700 : AppTheme.amber600,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
              remaining == null
                  ? 'Montant indisponible'
                  : '${_money.format(remaining)} FCFA restants',
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          if (canPay) ...[
            const SizedBox(height: 14),
            PcButton('Régler cette dette',
                block: true,
                icon: Icons.payments_outlined,
                onPressed: () => showPayClientDebtSheet(context,
                    debt: debt, onRefresh: _load)),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Mes dettes'), actions: [
        IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: _loading && _totalDebt == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? PcEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Chargement impossible',
                  message: _error,
                  action: PcButton('Réessayer', onPressed: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      PcCard(
                          accent: (_totalDebt ?? 0) > 0
                              ? AppTheme.amber600
                              : AppTheme.green700,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TOTAL RESTANT À RÉGLER',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1)),
                                const SizedBox(height: 10),
                                Text('${_money.format(_totalDebt)} FCFA',
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text(
                                    _totalDebt == 0
                                        ? 'Vous êtes à jour.'
                                        : 'Pénalités d’annulation de vos colis.',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary)),
                                if (!_canCreateParcel) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                      'Régularisez vos dettes pour pouvoir créer un nouveau colis.'),
                                ],
                              ])),
                      const SizedBox(height: 24),
                      const PcSectionHeader('Historique des dettes'),
                      if (_debts.isEmpty)
                        const PcEmptyState(
                            icon: Icons.task_alt_rounded,
                            title: 'Aucune dette',
                            message:
                                'Vos pénalités éventuelles apparaîtront ici.'),
                      ..._debts.map(_debtCard),
                      if (_page < _totalPages)
                        PcButton('Afficher la suite',
                            variant: PcButtonVariant.secondary,
                            loading: _loading,
                            onPressed: () => _load(more: true)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
