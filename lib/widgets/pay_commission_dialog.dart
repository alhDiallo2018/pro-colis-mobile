import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
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

  @override
  ConsumerState<PayCommissionDialog> createState() => _PayCommissionDialogState();
}

class _PayCommissionDialogState extends ConsumerState<PayCommissionDialog> {
  final ApiService _api = ApiService();
  bool _loading = true;
  bool _paying = false;
  String? _error;

  String _source = 'wallet';
  double _commission = 0;
  double _netAmount = 0;
  double _percentage = 5;
  double _walletBalance = 0;
  double _scoreBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final estimate = await _api.estimateCommission(widget.deliveryAmount);
      final wallet = await _api.getWallet('');
      final scoreBalanceData = await _api.getScoreBalance();

      if (mounted) {
        setState(() {
          _commission = (estimate['commission'] as num?)?.toDouble() ?? (widget.deliveryAmount * 0.05).clamp(100.0, 500.0);
          _netAmount = (estimate['netAmount'] as num?)?.toDouble() ?? widget.deliveryAmount - _commission;
          _percentage = (estimate['percentage'] as num?)?.toDouble() ?? 5;
          _walletBalance = wallet.balance;
          _scoreBalance = scoreBalanceData;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _commission = (widget.deliveryAmount * 0.05).clamp(100.0, 500.0);
          _netAmount = widget.deliveryAmount - _commission;
          _loading = false;
        });
      }
    }
  }

  bool get _canPayWallet => _walletBalance >= _commission;
  bool get _canPayScore => _scoreBalance >= _commission;
  bool get _canPayCombined => (_walletBalance + _scoreBalance) >= _commission;
  bool get _needsCombined => !_canPayWallet && !_canPayScore && _canPayCombined;
  
  double get _walletPart => _walletBalance < _commission ? _walletBalance : _commission;
  double get _scorePart {
    final remainder = _commission - _walletPart;
    return remainder < _scoreBalance ? remainder : _scoreBalance;
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
          final parts = <String>[];
          if (walletUsed > 0) parts.add('${_fcfa(walletUsed)} portefeuille');
          if (ptsUsed > 0) parts.add('${ptsUsed.toInt()} pts');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Commission de ${_fcfa(_commission)} payée via ${parts.join(' + ')}'),
              backgroundColor: AppTheme.green600,
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur: $e';
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
                        child: const Icon(Icons.receipt_long_rounded, color: AppTheme.amber600, size: 22),
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
                        const Divider(color: AppTheme.amber200, height: 16),
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
                          balance: _fcfa(_walletBalance),
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
                          balance: '${_scoreBalance.toInt()} pts',
                          enough: _canPayScore,
                          selected: _source == 'score',
                          onTap: _canPayScore ? () => setState(() => _source = 'score') : null,
                        ),
                      ),
                    ],
                  ),
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
                              const Icon(Icons.join_full_rounded, size: 16, color: AppTheme.teal600),
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
                                : 'Solde total insuffisant (${_fcfa(_walletBalance + _scoreBalance)})',
                            style: TextStyle(
                              fontSize: 11,
                              color: _canPayCombined ? AppTheme.textSecondary : AppTheme.red500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppTheme.red500, fontSize: 12)),
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
                          onPressed: (_canPayWallet || _canPayScore || _canPayCombined) && !_paying ? _pay : null,
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
}
