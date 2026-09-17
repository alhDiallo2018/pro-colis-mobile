// lib/widgets/cancellation_result_sheet.dart
//
// Affichage dynamique des conséquences d'une annulation de colis.
//
// Tout est piloté par [CancellationResult] (données renvoyées par l'API) :
// aucune valeur financière n'est construite ici. Les sections wallet / points /
// dette ne sont montrées qu'au chauffeur connecté ; le client ne voit que sa
// propre pénalité et son remboursement.

import 'package:flutter/material.dart';

import '../models/cancellation.dart';
import '../models/parcel.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'pay_client_debt_sheet.dart';
import 'pc_components.dart';

/// Ouvre la feuille de résultat d'une annulation. [viewerIsDriver] détermine
/// quelles sections sont visibles (respect strict des rôles).
///
/// [onPayDebt] (optionnel) active le bouton « Payer » sur la dette de pénalité
/// client : l'appelant fournit le parcours de règlement (PayDunya + refresh).
Future<void> showCancellationResultSheet(
  BuildContext context, {
  required CancellationResult result,
  required bool viewerIsDriver,
  Future<void> Function(CancellationClientDebt debt)? onPayDebt,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CancellationResultSheet(
      result: result,
      viewerIsDriver: viewerIsDriver,
      onPayDebt: onPayDebt,
    ),
  );
}

/// Confirmation explicite avant envoi, avec sélection obligatoire du motif.
///
/// [reasons] est la liste des motifs fournie par l'API (devis client ou
/// configuration publique) ; [preview] est l'aperçu du devis (`cancellation`)
/// renvoyé par `GET /client/parcels/:id/cancel/quote`, le cas échéant. Aucun
/// montant n'est calculé ici : on n'affiche que les valeurs déjà retournées.
///
/// Retourne :
/// - `null` si l'utilisateur annule ;
/// - une chaîne vide si l'utilisateur confirme sans motif (motifs absents) ;
/// - le `value` du motif choisi (code technique fourni par l'API).
Future<String?> showCancellationConfirmDialog(
  BuildContext context, {
  required Parcel parcel,
  bool viewerIsDriver = false,
  List<CancellationReason> reasons = const [],
  CancellationResult? preview,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _CancellationConfirmDialog(
      parcel: parcel,
      viewerIsDriver: viewerIsDriver,
      reasons: reasons,
      preview: preview,
    ),
  );
}

class _CancellationConfirmDialog extends StatefulWidget {
  final Parcel parcel;
  final bool viewerIsDriver;
  final List<CancellationReason> reasons;
  final CancellationResult? preview;

  const _CancellationConfirmDialog({
    required this.parcel,
    required this.viewerIsDriver,
    required this.reasons,
    required this.preview,
  });

  @override
  State<_CancellationConfirmDialog> createState() =>
      _CancellationConfirmDialogState();
}

class _CancellationConfirmDialogState extends State<_CancellationConfirmDialog> {
  String? _selectedReason;

  CancellationResult? get _preview =>
      widget.preview ?? widget.parcel.cancellation;

  double? get _previewAmount {
    final preview = _preview;
    if (preview == null) return null;
    return widget.viewerIsDriver
        ? preview.penaltyForDriver
        : preview.penaltyForClient;
  }

  bool get _reasonRequired => widget.reasons.isNotEmpty;

  bool get _canConfirm => !_reasonRequired || _selectedReason != null;

  void _confirm() {
    Navigator.pop(context, _selectedReason ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final previewAmount = _previewAmount;
    final availableReasons = widget.reasons;

    return AlertDialog(
      title: Text(widget.viewerIsDriver
          ? 'Annuler la mission ?'
          : 'Annuler ce colis ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.viewerIsDriver
                ? 'Cette action marquera la mission comme annulée.'
                : 'Cette action marquera le colis comme annulé.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          if (widget.parcel.payableAmount > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Montant de la course : ${formatFcfa(widget.parcel.payableAmount)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (previewAmount != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.amber50,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.amber200),
              ),
              child: Text(
                'Cette annulation peut entraîner une pénalité de '
                '${formatFcfa(previewAmount)}. Voulez-vous continuer ?',
                style: TextStyle(
                  color: AppTheme.amber600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Toute pénalité ou remboursement applicable sera déterminé '
              'par la plateforme et affiché après confirmation.',
              style: TextStyle(
                color: AppTheme.slate500,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
          if (_reasonRequired) ...[
            const SizedBox(height: 16),
            Text(
              'Motif d’annulation',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              isExpanded: true,
              hint: const Text('Sélectionnez un motif'),
              items: availableReasons
                  .map((r) => DropdownMenuItem(
                        value: r.value,
                        child: Text(r.label, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedReason = value),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Aucun motif d’annulation disponible. Veuillez contacter le '
              'support si nécessaire.',
              style: TextStyle(
                color: AppTheme.slate500,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        ElevatedButton(
          onPressed: _canConfirm ? _confirm : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red500),
          child: const Text('Confirmer l’annulation'),
        ),
      ],
    );
  }
}

class _CancellationResultSheet extends StatelessWidget {
  final CancellationResult result;
  final bool viewerIsDriver;
  final Future<void> Function(CancellationClientDebt debt)? onPayDebt;

  const _CancellationResultSheet({
    required this.result,
    required this.viewerIsDriver,
    this.onPayDebt,
  });

  @override
  Widget build(BuildContext context) {
    final hasPenaltyForViewer = viewerIsDriver
        ? result.penaltyForDriver != null
        : result.penaltyForClient != null;
    final showPenalty = result.hasPenalty && hasPenaltyForViewer;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.slate200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const PcSectionHeader('Colis annulé'),
              if (result.message != null && result.message!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    result.message!,
                    style: TextStyle(
                      color: AppTheme.slate600,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              if (showPenalty) ...[
                _buildPenaltySection(),
                const SizedBox(height: 12),
              ],
              if (!viewerIsDriver && result.hasRefund) ...[
                _buildRefundSection(),
                const SizedBox(height: 12),
              ],
              if (!viewerIsDriver && result.hasClientDebt) ...[
                _buildClientDebtSection(),
                const SizedBox(height: 12),
              ],
              if (viewerIsDriver && result.hasWalletEffect) ...[
                _buildWalletSection(),
                const SizedBox(height: 12),
              ],
              if (viewerIsDriver && result.hasPointsEffect) ...[
                _buildPointsSection(),
                const SizedBox(height: 12),
              ],
              if (viewerIsDriver && result.hasDebtEffect) ...[
                _buildDebtSection(),
                const SizedBox(height: 12),
              ],
              if (!showPenalty &&
                  !result.hasRefund &&
                  !result.hasClientDebt &&
                  !result.hasWalletEffect &&
                  !result.hasPointsEffect &&
                  !result.hasDebtEffect)
                const PcEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Aucune retenue',
                  message: 'Cette annulation n’a entraîné aucune pénalité '
                      'ni aucun remboursement.',
                  tone: PcTone.green,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPenaltySection() {
    final amount = viewerIsDriver
        ? result.penaltyForDriver
        : result.penaltyForClient;
    final label = result.penalty.label;
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Pénalité', Icons.gavel_rounded, PcTone.red),
          const SizedBox(height: 8),
          if (label != null && label.isNotEmpty) ...[
            _row('Nature', label),
            const SizedBox(height: 8),
          ],
          _row(
            viewerIsDriver ? 'Pénalité chauffeur' : 'Pénalité client',
            amount != null ? formatFcfa(amount) : '—',
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRefundSection() {
    final r = result.refund;
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Remboursement', Icons.currency_exchange_rounded,
              PcTone.green),
          const SizedBox(height: 8),
          if (r.initialAmount != null) ...[
            _row('Montant initial', formatFcfa(r.initialAmount)),
            const SizedBox(height: 6),
          ],
          if (r.fees != null) ...[
            _row('Frais techniques', formatFcfa(r.fees)),
            const SizedBox(height: 6),
          ],
          if (r.paydunyaFee != null) ...[
            _row('Frais PayDunya', formatFcfa(r.paydunyaFee)),
            const SizedBox(height: 6),
          ],
          if (r.penaltyAmount != null) ...[
            _row('Pénalité', formatFcfa(r.penaltyAmount)),
            const SizedBox(height: 6),
          ],
          if (r.refundedAmount != null && r.refundedAmount! > 0) ...[
            _row('Montant remboursé', formatFcfa(r.refundedAmount), bold: true),
            const SizedBox(height: 6),
          ],
          if (r.status != null) ...[
            _row('Statut', _refundStatusLabel(r.status!)),
          ],
        ],
      ),
    );
  }

  Widget _buildClientDebtSection() {
    final d = result.clientDebt;
    final canPay = onPayDebt != null && d.hasId && d.hasDebt;
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
              'Pénalité à régler', Icons.warning_amber_rounded, PcTone.red),
          const SizedBox(height: 8),
          _row(
            'Montant dû',
            d.amount != null ? formatFcfa(d.amount) : '—',
            bold: true,
          ),
          if (d.reference != null && d.reference!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _row('Référence', d.reference!),
          ],
          if (canPay) ...[
            const SizedBox(height: 14),
            PcButton(
              'Payer avec PayDunya',
              icon: Icons.payments_rounded,
              block: true,
              onPressed: () => onPayDebt!(d),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletSection() {
    final w = result.wallet;
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
              'Portefeuille', Icons.account_balance_wallet_rounded, PcTone.amber),
          const SizedBox(height: 8),
          if (w.before != null) ...[
            _row('Wallet avant', formatFcfa(w.before)),
            const SizedBox(height: 6),
          ],
          if (w.deduction != null) ...[
            _row('Prélèvement wallet', formatFcfa(w.deduction)),
            const SizedBox(height: 6),
          ],
          if (w.after != null) ...[
            _row('Wallet après', formatFcfa(w.after), bold: true),
          ],
        ],
      ),
    );
  }

  Widget _buildPointsSection() {
    final p = result.points;
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Points', Icons.stars_rounded, PcTone.amber),
          const SizedBox(height: 8),
          if (p.before != null) ...[
            _row('Points avant', formatPoints(p.before)),
            const SizedBox(height: 6),
          ],
          if (p.deduction != null) ...[
            _row('Prélèvement points', formatPoints(p.deduction)),
            const SizedBox(height: 6),
          ],
          if (p.after != null) ...[
            _row('Points après', formatPoints(p.after), bold: true),
          ],
        ],
      ),
    );
  }

  Widget _buildDebtSection() {
    final d = result.debt;
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Dette', Icons.warning_amber_rounded, PcTone.red),
          const SizedBox(height: 8),
          if (d.before != null) ...[
            _row('Dette avant', formatFcfa(d.before)),
            const SizedBox(height: 6),
          ],
          if (d.created != null) ...[
            _row('Dette créée', formatFcfa(d.created)),
            const SizedBox(height: 6),
          ],
          if (d.after != null) ...[
            _row('Dette après', formatFcfa(d.after), bold: true),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, PcTone tone) {
    final chip = switch (tone) {
      PcTone.red => (AppTheme.red50, AppTheme.red500),
      PcTone.green => (AppTheme.green50, AppTheme.green700),
      PcTone.amber => (AppTheme.amber50, AppTheme.amber600),
      _ => (AppTheme.teal50, AppTheme.teal500),
    };
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: chip.$1,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, size: 18, color: chip.$2),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppTheme.slate500, fontSize: 13.5),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _refundStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'none':
      case 'na':
      case 'n/a':
        return 'Aucun remboursement';
      case 'pending':
      case 'processing':
        return 'Remboursement en attente';
      case 'completed':
      case 'paid':
      case 'refunded':
        return 'Remboursé';
      case 'failed':
      case 'error':
        return 'Remboursement échoué';
      default:
        return status;
    }
  }
}
