// lib/screens/super-admin/cash_declarations_screen.dart
//
// Réconciliation des encaissements en espèces.
//
// Sur une course réglée en espèces, la plateforme n'encaisse rien : le chauffeur
// reçoit l'argent en main propre puis le déclare depuis l'app. La déclaration
// crée un paiement `cash` en `processing`. Cet écran est la file d'attente de
// ces déclarations : l'admin valide (paiement `completed`, colis payé) ou
// rejette avec un motif (paiement `failed`, la course reste due).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/payment.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/payment_channel_selector.dart';
import '../../widgets/pc_components.dart';

class CashDeclarationsScreen extends ConsumerStatefulWidget {
  const CashDeclarationsScreen({super.key});

  @override
  ConsumerState<CashDeclarationsScreen> createState() =>
      _CashDeclarationsScreenState();
}

class _CashDeclarationsScreenState
    extends ConsumerState<CashDeclarationsScreen> {
  final ApiService _api = ApiService();

  List<Payment> _declarations = [];
  bool _loading = true;
  String? _error;

  /// Identifiant du paiement en cours de traitement, pour n'afficher le spinner
  /// que sur la ligne concernée.
  String? _busyId;

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
      final raw = await _api.pendingCashDeclarations();
      final parsed = raw.map(Payment.fromJson).toList()
        // Les plus anciennes déclarations d'abord : ce sont celles qui
        // attendent leur réconciliation depuis le plus longtemps.
        ..sort((a, b) {
          final da = a.declaredAt ?? a.createdAt;
          final db = b.declaredAt ?? b.createdAt;
          return da.compareTo(db);
        });
      if (!mounted) return;
      setState(() {
        _declarations = parsed;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _validate(Payment payment) async {
    final confirmed = await _confirmValidation(payment);
    if (confirmed != true) return;

    setState(() => _busyId = payment.id);
    try {
      final result = await _api.validateCashDeclaration(payment.id);
      if (!mounted) return;
      if (result['success'] == true) {
        _snack('Encaissement de ${payment.formattedAmount} validé',
            success: true);
        await _load();
      } else {
        _snack(result['message']?.toString() ?? 'Validation impossible');
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<bool?> _confirmValidation(Payment payment) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider l’encaissement ?'),
        content: Text(
          'Vous confirmez avoir retrouvé ${payment.formattedAmount} en espèces '
          'pour le colis ${payment.trackingNumber ?? payment.parcelId ?? '—'}. '
          'Le colis sera marqué payé.',
          style: AppFonts.manrope(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _reject(Payment payment) async {
    final reason = await _askRejectionReason();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _busyId = payment.id);
    try {
      final result = await _api.rejectCashDeclaration(
        payment.id,
        reason: reason.trim(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        _snack('Déclaration rejetée');
        await _load();
      } else {
        _snack(result['message']?.toString() ?? 'Rejet impossible');
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Le motif est obligatoire : un rejet laisse la course due au chauffeur, il
  /// doit pouvoir comprendre pourquoi.
  Future<String?> _askRejectionReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter la déclaration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le chauffeur sera notifié et la course restera due.',
              style: AppFonts.manrope(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Ex : montant non retrouvé en caisse.',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red400),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? AppTheme.green600 : null,
      ),
    );
  }

  double get _totalPending =>
      _declarations.fold<double>(0, (sum, p) => sum + p.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Encaissements espèces'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_loading && _error == null && _declarations.isNotEmpty)
            _summary(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _summary() {
    return Container(
      width: double.infinity,
      color: AppTheme.cardColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.amber50,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(Icons.hourglass_top_rounded,
                color: AppTheme.amber600, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_declarations.length} déclaration'
                  '${_declarations.length > 1 ? 's' : ''} à réconcilier',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Total déclaré : ${_totalPending.toStringAsFixed(0)} FCFA',
                  style: AppTheme.mono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        tone: AppTheme.red400,
        title: 'Erreur',
        message: _error,
        action: PcButton('Réessayer', onPressed: _load),
      );
    }
    if (_declarations.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_rounded,
        title: 'Rien à réconcilier',
        message:
            'Aucun encaissement en espèces n’attend de validation. Les nouvelles '
            'déclarations des chauffeurs apparaîtront ici.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _declarations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) => _declarationCard(_declarations[index]),
      ),
    );
  }

  Widget _declarationCard(Payment payment) {
    final busy = _busyId == payment.id;
    final point = payment.cashCollectionPoint;

    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.trackingNumber ?? payment.parcelId ?? '—',
                      style: AppTheme.mono(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      payment.declaredByName ?? payment.userName ?? 'Chauffeur',
                      style: AppFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                payment.formattedAmount,
                style: AppTheme.mono(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.teal700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PaymentChannelBadge(
                channel: payment.channel,
                collectionPoint: point,
                status: payment.statusLabel,
              ),
              if (payment.declaredAt != null)
                _metaChip(
                  Icons.schedule_rounded,
                  'Déclaré ${_relative(payment.declaredAt!)}',
                ),
              if (payment.declarationProofUrl != null &&
                  payment.declarationProofUrl!.isNotEmpty)
                _metaChip(Icons.image_rounded, 'Preuve jointe'),
            ],
          ),
          if (payment.declarationNote != null &&
              payment.declarationNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                payment.declarationNote!,
                style: AppFonts.manrope(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppTheme.textBody,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PcButton(
                  'Rejeter',
                  variant: PcButtonVariant.secondary,
                  block: true,
                  onPressed: busy ? null : () => _reject(payment),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: PcButton(
                  'Valider',
                  icon: Icons.verified_rounded,
                  block: true,
                  loading: busy,
                  onPressed: busy ? null : () => _validate(payment),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.slate500),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.slate600,
            ),
          ),
        ],
      ),
    );
  }

  String _relative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'à l’instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }
}
