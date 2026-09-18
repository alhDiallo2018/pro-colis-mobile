import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

/// Feuille de règlement de la dette de commission d'un chauffeur.
///
/// La dette est réglée à partir du solde existant du portefeuille. Un montant
/// laissé vide règle tout ce que le solde permet (borné par la dette restante).
Future<void> showPayDebtSheet(
  BuildContext context, {
  required double balance,
  required double debt,
  required VoidCallback onPaid,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PayDebtSheetContent(
      balance: balance,
      debt: debt,
      onPaid: onPaid,
    ),
  );
}

class PayDebtSheetContent extends StatefulWidget {
  final double balance;
  final double debt;
  final VoidCallback onPaid;

  const PayDebtSheetContent({
    super.key,
    required this.balance,
    required this.debt,
    required this.onPaid,
  });

  @override
  State<PayDebtSheetContent> createState() => _PayDebtSheetContentState();
}

class _PayDebtSheetContentState extends State<PayDebtSheetContent> {
  final ApiService _api = ApiService();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

  bool get _useCustomAmount => _amountCtrl.text.trim().isNotEmpty;

  double get _amount {
    final custom = double.tryParse(_amountCtrl.text.trim());
    if (custom != null && custom > 0) return custom;
    final maxPayable =
        widget.balance < widget.debt ? widget.balance : widget.debt;
    return maxPayable;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = _amount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Montant invalide'), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (amount > widget.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Solde insuffisant'),
            backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _api.payWalletDebt(
        amount: _useCustomAmount ? amount : null,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        // ApiService garantit la présence de ces deux valeurs backend avant
        // de déclarer l'opération réussie : aucun reliquat n'est calculé ici.
        final repaid = (result['debtRepaid'] as num).toDouble();
        final remaining = (result['remainingDebt'] as num).toDouble();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remaining > 0
                  ? 'Dette réglée partiellement (${_format(repaid)} FCFA). '
                      'Reste : ${_format(remaining)} FCFA.'
                  : 'Dette de commission réglée (${_format(repaid)} FCFA).',
            ),
            backgroundColor:
                remaining > 0 ? AppTheme.amber600 : AppTheme.green600,
          ),
        );
        widget.onPaid();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  'Erreur lors du règlement de la dette',
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('[PayDebtSheet] Échec paiement dette: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _format(double v) {
    return NumberFormat('#,##0', 'fr').format(v.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final fmt = NumberFormat('#,##0', 'fr');
    final maxPayable =
        widget.balance < widget.debt ? widget.balance : widget.debt;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Régler la dette de commission',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Dette : ${fmt.format(widget.debt.toInt())} FCFA · '
              'Solde : ${fmt.format(widget.balance.toInt())} FCFA',
              style: TextStyle(fontSize: 13, color: AppTheme.slate500),
            ),
            const SizedBox(height: 20),
            Text(
              'Montant à régler (FCFA)',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText:
                    '${fmt.format(maxPayable.toInt())} (solde disponible)',
                prefixIcon: const Icon(Icons.payments),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Laissez vide pour régler tout ce que votre solde permet '
              '(maximum ${fmt.format(maxPayable.toInt())} FCFA).',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            PcButton(
              _submitting ? 'Règlement en cours...' : 'Régler la dette',
              loading: _submitting,
              block: true,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
