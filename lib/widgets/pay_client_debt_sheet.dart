// lib/widgets/pay_client_debt_sheet.dart
//
// Règlement d'une dette de pénalité d'annulation CLIENT via PayDunya.
//
// Le client n'a pas de wallet préfinancé : la pénalité non couverte par un
// remboursement devient une dette persistante (`ClientPenaltyDebt`), réglée
// directement via `POST /payments/paydunya/create` avec `type: "penalty_debt"`.
//
// Le mobile ne fait que transmettre la demande de paiement :
// - `debtId` provient du modèle `CancellationClientDebt` fourni par l'API
//   (jamais d'une saisie utilisateur libre) ;
// - « Tout payer » → `amount` OMIS, le backend règle le reliquat complet ;
// - « Montant personnalisé » → `amount` = montant saisi par l'utilisateur ;
// - le backend reste l'autorité pour montant / statut / reliquat / propriété.
//
// Le statut « payé » n'est JAMAIS affiché parce que PayDunya a été ouvert : il
// est confirmé par `GET /payments/paydunya/confirm/:token` (backend), puis la
// dette est rafraîchie via [onRefresh].

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cancellation.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

/// Ouvre la feuille de règlement d'une dette de pénalité client.
///
/// [debt] est le bloc `clientDebt` renvoyé par l'API (contient l'UUID réel).
/// [onRefresh] est appelé après un paiement réussi, un retour PayDunya ou une
/// erreur 422/409, afin que l'appelant recharge la dette depuis l'API.
Future<void> showPayClientDebtSheet(
  BuildContext context, {
  required CancellationClientDebt debt,
  required Future<void> Function() onRefresh,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PayClientDebtSheetContent(
      debt: debt,
      onRefresh: onRefresh,
    ),
  );
}

class PayClientDebtSheetContent extends StatefulWidget {
  final CancellationClientDebt debt;
  final Future<void> Function() onRefresh;

  /// Injecté pour les tests ; par défaut un [ApiService] réel est créé.
  final ApiService? api;

  const PayClientDebtSheetContent({
    super.key,
    required this.debt,
    required this.onRefresh,
    this.api,
  });

  @override
  State<PayClientDebtSheetContent> createState() =>
      _PayClientDebtSheetContentState();
}

class _PayClientDebtSheetContentState extends State<PayClientDebtSheetContent> {
  late final ApiService _api = widget.api ?? ApiService();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  bool get _useCustomAmount => _amountCtrl.text.trim().isNotEmpty;

  double? get _customAmount {
    final raw = _amountCtrl.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return null;
    return value;
  }

  /// Montant affiché comme « restant » : le reliquat fourni par le backend, ou
  /// à défaut le montant de dette exposé. Aucun calcul local.
  double get _displayedRemaining => widget.debt.displayedRemaining ?? 0;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!widget.debt.hasId) {
      setState(() => _error = 'Cette dette ne peut pas être réglée.');
      return;
    }

    final custom = _useCustomAmount ? _customAmount : null;
    // Validation UX uniquement : le backend reste l'autorité finale.
    if (_useCustomAmount) {
      if (custom == null) {
        setState(() => _error = 'Veuillez saisir un montant valide (supérieur à 0).');
        return;
      }
      if (_displayedRemaining > 0 && custom > _displayedRemaining) {
        setState(() =>
            _error = 'Le montant ne peut pas dépasser le montant affiché.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await _api.createPenaltyDebtPayment(
        debtId: widget.debt.id!,
        amount: custom,
      );
      if (!mounted) return;

      if (result['success'] != true) {
        final statusCode = (result['statusCode'] as num?)?.toInt() ?? 0;
        final message = result['message']?.toString() ??
            'Impossible de créer le paiement';
        setState(() => _error = message);
        // État de la dette modifié côté serveur : on rafraîchit l'appelant.
        if (statusCode == 422 || statusCode == 409) {
          await _safeRefresh();
        }
        return;
      }

      final paymentUrl = result['paymentUrl']?.toString() ?? '';
      final token = result['token']?.toString() ?? '';
      if (paymentUrl.isEmpty || token.isEmpty) {
        setState(() =>
            _error = 'Réponse de paiement invalide. Veuillez réessayer.');
        return;
      }

      final launched = await launchUrl(
        Uri.parse(paymentUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        if (mounted) {
          setState(() => _error = 'Impossible d’ouvrir la page de paiement PayDunya.');
        }
        return;
      }

      // Confirmation par le backend : ne jamais considérer l'ouverture du
      // checkout comme un paiement.
      final confirm = await _api.confirmPaydunyaPayment(token);
      if (!mounted) return;

      if (confirm['status'] == 'completed') {
        await _safeRefresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Paiement confirmé. Votre dette a été mise à jour.'),
            backgroundColor: AppTheme.green600,
          ),
        );
        Navigator.pop(context);
      } else {
        await _safeRefresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Paiement ouvert. Le statut sera actualisé après confirmation.'),
            backgroundColor: AppTheme.amber600,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[PayClientDebtSheet] Échec paiement dette: $e');
      if (mounted) {
        setState(() => _error = 'Impossible de créer le paiement.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _safeRefresh() async {
    try {
      await widget.onRefresh();
    } catch (e) {
      debugPrint('[PayClientDebtSheet] Échec rafraîchissement: $e');
    }
  }

  String _fmt(double v) {
    return NumberFormat('#,##0', 'fr').format(v.round());
  }

  String? _statusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'En attente de paiement';
      case 'partially_paid':
        return 'Partiellement réglée';
      case 'paid':
        return 'Réglée';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final debt = widget.debt;
    final statusLabel = _statusLabel(debt.status);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
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
              'Régler la pénalité d’annulation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (debt.reference != null && debt.reference!.isNotEmpty) ...[
              Text(
                'Référence : ${debt.reference}',
                style: TextStyle(fontSize: 13, color: AppTheme.slate500),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              'Montant à régler : ${_fmt(_displayedRemaining)} FCFA',
              style: TextStyle(fontSize: 13, color: AppTheme.slate500),
            ),
            if (statusLabel != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  PcBadge(
                    statusLabel,
                    tone: debt.status == 'paid' ? PcTone.green : PcTone.amber,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Montant personnalisé (FCFA)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                hintText: 'Laissez vide pour tout payer',
                prefixIcon: Icon(Icons.payments),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Laissez vide pour régler la totalité. Sinon, saisissez un '
              'montant partiel : le paiement est réglé directement via '
              'PayDunya.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: AppTheme.red500, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            PcButton(
              _submitting ? 'Redirection vers PayDunya...' : 'Payer avec PayDunya',
              icon: Icons.payments_rounded,
              block: true,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
