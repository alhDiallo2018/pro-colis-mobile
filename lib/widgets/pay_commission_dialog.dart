import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../services/commission_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

class PayCommissionDialog extends ConsumerStatefulWidget {
  final String parcelId;
  final double deliveryAmount;
  final String trackingNumber;
  final VoidCallback? onPaid;

  const PayCommissionDialog({
    super.key,
    required this.parcelId,
    required this.deliveryAmount,
    required this.trackingNumber,
    this.onPaid,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String parcelId,
    required double deliveryAmount,
    required String trackingNumber,
    VoidCallback? onPaid,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => PayCommissionDialog(
        parcelId: parcelId,
        deliveryAmount: deliveryAmount,
        trackingNumber: trackingNumber,
        onPaid: onPaid,
      ),
    );
  }

  @override
  ConsumerState<PayCommissionDialog> createState() => _PayCommissionDialogState();
}

class _PayCommissionDialogState extends ConsumerState<PayCommissionDialog> {
  final ApiService _api = ApiService();
  bool _loading = true;
  bool _paying = false;
  String? _error;

  /// Les soldes (wallet/points) sont `null` tant qu'ils n'ont pas été chargés
  /// avec succès : un solde inconnu n'est jamais présenté comme 0.
  bool _balanceError = false;
  String _source = 'wallet';
  double _commission = 0;
  double _netAmount = 0;
  double _percentage = 0;
  double? _walletBalance;
  double? _scoreBalance;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _balanceError = false;
    });

    // 1. Estimation de commission : le repli local reste acceptable (c'est une
    //    estimation d'affichage, la vérité financière reste le backend).
    double commission;
    double netAmount;
    double percentage;
    try {
      final estimate = await _api.estimateCommission(widget.deliveryAmount);
      commission = (estimate['commission'] as num?)?.toDouble() ??
          CommissionService.calculate(widget.deliveryAmount);
      netAmount = (estimate['netAmount'] as num?)?.toDouble() ??
          widget.deliveryAmount - commission;
      percentage = (estimate['percentage'] as num?)?.toDouble() ??
          CommissionService.percentage;
    } catch (_) {
      commission = CommissionService.calculate(widget.deliveryAmount);
      netAmount = widget.deliveryAmount - commission;
      percentage = CommissionService.percentage;
    }

    // 2. Soldes : une erreur ne doit JAMAIS être traduite en solde nul. On
    //    charge les deux indépendamment pour ne pas masquer l'un par l'autre.
    double? walletBalance;
    double? scoreBalance;
    var balanceError = false;
    try {
      final wallet = await _api.getWallet('');
      walletBalance = wallet.balance;
    } catch (_) {
      balanceError = true;
    }
    try {
      scoreBalance = await _api.getScoreBalance();
    } catch (_) {
      balanceError = true;
    }

    if (!mounted) return;
    setState(() {
      _commission = commission;
      _netAmount = netAmount;
      _percentage = percentage;
      _walletBalance = walletBalance;
      _scoreBalance = scoreBalance;
      _balanceError = balanceError;
      _loading = false;
    });
  }

  bool get _canPayWallet => _walletBalance != null && _walletBalance! >= _commission;
  bool get _canPayScore => _scoreBalance != null && _scoreBalance! >= _commission;
  bool get _canPayCombined =>
      _walletBalance != null &&
      _scoreBalance != null &&
      (_walletBalance! + _scoreBalance!) >= _commission;
  bool get _needsCombined => !_canPayWallet && !_canPayScore && _canPayCombined;

  /// Les fonds disponibles (wallet + points) ne couvrent pas la commission.
  bool get _insufficient => !_canPayCombined;

  /// La configuration autorise-t-elle à enregistrer la commission en dette
  /// (`debt`) ou avec simple alerte (`warn`) ? Le backend reste seul juge : le
  /// bouton reste accessible pour déclencher l'appel, qui sera refusé si la
  /// politique est `block` ou si la limite de dette est atteinte.
  bool get _canGoIntoDebt => _insufficient && CommissionService.allowsDebt;

  /// Le bouton de validation est-il actionnable ? Jamais si les soldes n'ont
  /// pas pu être chargés : on ne peut pas déterminer la capacité de paiement.
  bool get _canSubmitPayment =>
      !_balanceError &&
      (_canPayWallet || _canPayScore || _canPayCombined || _canGoIntoDebt);

  double get _walletPart =>
      (_walletBalance ?? 0) < _commission ? (_walletBalance ?? 0) : _commission;
  double get _scorePart {
    final remainder = _commission - _walletPart;
    return remainder < (_scoreBalance ?? 0) ? remainder : (_scoreBalance ?? 0);
  }

  String _fcfa(double v) {
    final s = NumberFormat('#,##0', 'fr').format(v.toInt());
    return '$s FCFA';
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      final source = (_canPayWallet && _source != 'score') ? 'wallet' : (_canPayScore ? 'score' : 'auto');
      final result = await _api.payCashCommission(widget.parcelId, source, amount: widget.deliveryAmount);
      if (mounted) {
        if (result['success'] == true) {
          final walletUsed = (result['walletDebited'] as num?)?.toDouble() ?? (_source == 'wallet' ? _commission : _walletPart);
          final ptsUsed = (result['pointsDebited'] as num?)?.toDouble() ?? (_source == 'score' ? _commission : _scorePart);
          final debt = (result['debt'] as num?)?.toDouble() ?? 0;
          final parts = <String>[];
          if (walletUsed > 0) parts.add('${_fcfa(walletUsed)} portefeuille');
          if (ptsUsed > 0) parts.add('${ptsUsed.toInt()} pts');
          if (debt > 0) parts.add('${_fcfa(debt)} en dette');

          final paidLabel = parts.isEmpty ? _fcfa(_commission) : parts.join(' + ');
          final message = debt > 0
              ? 'Commission de ${_fcfa(_commission)} comptabilisée. '
                  'Reste dû : ${_fcfa(debt)} (à régulariser).'
              : 'Commission de ${_fcfa(_commission)} payée via $paidLabel';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: debt > 0 ? AppTheme.amber600 : AppTheme.green600,
            ),
          );
          widget.onPaid?.call();
          Navigator.pop(context);
        } else {
          setState(() {
            _error = result['message']?.toString() ?? 'Erreur lors du paiement';
            _paying = false;
          });
        }
      }
    } catch (error, stackTrace) {
      debugPrint(
        'PayCommissionDialog: paiement de ${widget.parcelId} impossible '
        '($error)\n$stackTrace',
      );
      if (mounted) {
        setState(() {
          _error = 'Le paiement a échoué. Veuillez réessayer.';
          _paying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.amber50,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Icon(Icons.receipt_long_rounded, color: AppTheme.amber600, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Payer la commission',
                        style: AppFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Commission breakdown
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.amber50,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.amber100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DÉTAIL COMMISSION',
                          style: AppFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.amber600,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _rowInfo('Montant livraison', _fcfa(widget.deliveryAmount), AppTheme.textBody),
                        _rowInfo('Commission (${_percentage.toInt()}%)', '- ${_fcfa(_commission)}', AppTheme.red500),
                        Divider(color: AppTheme.amber200, height: 16),
                        _rowInfo('Votre gain net', _fcfa(_netAmount), AppTheme.green700),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Comment souhaitez-vous payer la commission ?',
                    style: AppFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Source selection
                  Row(
                    children: [
                      Expanded(
                        child: _sourceOption(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Portefeuille',
                          balance: _walletBalance != null
                              ? _fcfa(_walletBalance!)
                              : 'Solde indisponible',
                          enough: _canPayWallet,
                          selected: _source == 'wallet',
                          onTap: _canPayWallet ? () => setState(() => _source = 'wallet') : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _sourceOption(
                          icon: Icons.stars_rounded,
                          label: 'Points Score',
                          balance: _scoreBalance != null
                              ? '${_scoreBalance!.toInt()} pts'
                              : 'Solde indisponible',
                          enough: _canPayScore,
                          selected: _source == 'score',
                          onTap: _canPayScore ? () => setState(() => _source = 'score') : null,
                        ),
                      ),
                    ],
                  ),
                  if (_balanceError) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.red50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.red100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: AppTheme.red500, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Impossible de charger vos soldes. Le paiement est '
                              'désactivé pour éviter toute erreur.',
                              style: AppFonts.manrope(
                                fontSize: 12,
                                color: AppTheme.red500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PcButton(
                            'Réessayer',
                            variant: PcButtonVariant.secondary,
                            size: PcButtonSize.sm,
                            onPressed: _loadData,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_needsCombined || (!_canPayWallet && !_canPayScore)) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.teal50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.teal500),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.join_full_rounded, size: 16, color: AppTheme.teal600),
                              const SizedBox(width: 6),
                              Text(
                                'Portefeuille + Points',
                                style: AppFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.teal700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Portefeuille: ${_fcfa(_walletPart)} + Points: ${_scorePart.toInt()} pts = ${_fcfa(_commission)}',
                            style: AppTheme.mono(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _canPayCombined
                                ? 'Le paiement combiné est possible'
                                : _canGoIntoDebt
                                    ? 'Solde insuffisant : la commission sera comptabilisée en dette.'
                                    : 'Solde insuffisant : rechargez votre portefeuille ou vos points.',
                            style: TextStyle(
                              fontSize: 11,
                              color: _canPayCombined
                                  ? AppTheme.textSecondary
                                  : _canGoIntoDebt
                                      ? AppTheme.amber700
                                      : AppTheme.red500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: AppTheme.red500, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: PcButton(
                          'Plus tard',
                          variant: PcButtonVariant.secondary,
                          block: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PcButton(
                          'Payer $_commission FCFA',
                          icon: Icons.payments_rounded,
                          variant: PcButtonVariant.primary,
                          block: true,
                          loading: _paying,
                          onPressed: _canSubmitPayment && !_paying ? _pay : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _rowInfo(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value, style: AppTheme.mono(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }

  Widget _sourceOption({
    required IconData icon,
    required String label,
    required String balance,
    required bool enough,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.teal50 : AppTheme.slate50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.teal500 : AppTheme.slate200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: selected ? AppTheme.teal600 : AppTheme.slate500),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              balance,
              style: AppTheme.mono(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: enough ? AppTheme.textPrimary : AppTheme.red500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              enough ? 'Solde suffisant' : 'Insuffisant',
              style: TextStyle(
                fontSize: 11,
                color: enough ? AppTheme.textSecondary : AppTheme.red500,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
