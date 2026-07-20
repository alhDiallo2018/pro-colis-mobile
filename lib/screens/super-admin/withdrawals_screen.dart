import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

/// Gestion des retraits chauffeurs (aligné sur WithdrawalsPage du web) :
/// liste filtrée par statut, approbation, rejet (avec raison), complétion.
class WithdrawalsScreen extends ConsumerStatefulWidget {
  const WithdrawalsScreen({super.key});

  @override
  ConsumerState<WithdrawalsScreen> createState() => _WithdrawalsScreenState();
}

class _WithdrawalsScreenState extends ConsumerState<WithdrawalsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _withdrawals = [];
  bool _loading = true;
  bool _processing = false;
  String? _error;
  String _statusFilter = '';

  static const _statusOptions = <String, String>{
    '': 'Tous',
    'PENDING': 'En attente',
    'PROCESSING': 'En cours',
    'SUCCESS': 'Réussis',
    'FAILED': 'Échoués',
    'CANCELLED': 'Annulés',
  };

  static const _statusLabels = <String, String>{
    'PENDING': 'En attente',
    'PROCESSING': 'En cours',
    'SUCCESS': 'Réussi',
    'FAILED': 'Échoué',
    'CANCELLED': 'Annulé',
  };

  static const _methodLabels = <String, String>{
    'wave': 'Wave',
    'orange_money': 'Orange Money',
    'orangeMoney': 'Orange Money',
    'freeMoney': 'Free Money',
    'freemMoney': 'Free Money',
    'bank': 'Virement',
    'paydunya': 'PayDunya',
  };

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
      final list = await _api.adminWithdrawals(status: _statusFilter);
      if (mounted) {
        setState(() {
          _withdrawals = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _setStatus(String s) {
    setState(() => _statusFilter = s);
    _load();
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }

  Future<void> _approve(Map<String, dynamic> w) async {
    setState(() => _processing = true);
    final result = await _api.adminApproveWithdrawal(w['id'].toString());
    if (!mounted) return;
    setState(() => _processing = false);
    if (result['success'] == true) {
      _showSnack('Retrait approuvé', AppTheme.successColor);
      await _load();
    } else {
      _showSnack(result['message'] ?? 'Erreur lors de l\'approbation',
          AppTheme.errorColor);
    }
  }

  Future<void> _complete(Map<String, dynamic> w) async {
    setState(() => _processing = true);
    final result = await _api.adminCompleteWithdrawal(w['id'].toString());
    if (!mounted) return;
    setState(() => _processing = false);
    if (result['success'] == true) {
      _showSnack('Retrait complété', AppTheme.successColor);
      await _load();
    } else {
      _showSnack(result['message'] ?? 'Erreur lors de la complétion',
          AppTheme.errorColor);
    }
  }

  Future<void> _reject(Map<String, dynamic> w) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text('Rejeter le retrait',
            style: AppFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppTheme.textPrimary,
            )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Raison du rejet',
                hintText: 'Ex: Numéro invalide, fraude...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Le montant sera remis dans le solde disponible du chauffeur.',
              style: AppFonts.manrope(
                fontSize: 12,
                color: AppTheme.slate500,
              ),
            ),
          ],
        ),
        actions: [
          PcButton(
            'Annuler',
            variant: PcButtonVariant.secondary,
            size: PcButtonSize.sm,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          PcButton(
            'Rejeter',
            variant: PcButtonVariant.danger,
            size: PcButtonSize.sm,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _processing = true);
    final reason = reasonController.text.trim().isEmpty
        ? 'Rejeté par administration'
        : reasonController.text.trim();
    final result = await _api.adminRejectWithdrawal(w['id'].toString(), reason);
    if (!mounted) return;
    setState(() => _processing = false);
    if (result['success'] == true) {
      _showSnack('Retrait rejeté', AppTheme.successColor);
      await _load();
    } else {
      _showSnack(
          result['message'] ?? 'Erreur lors du rejet', AppTheme.errorColor);
    }
  }

  String _fcfa(dynamic v) {
    final n = (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
    return '${n.toStringAsFixed(0)} FCFA';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'SUCCESS':
        return AppTheme.green600;
      case 'PENDING':
        return AppTheme.amber500;
      case 'PROCESSING':
        return AppTheme.teal500;
      case 'FAILED':
        return AppTheme.red400;
      case 'CANCELLED':
      default:
        return AppTheme.slate500;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.substring(0, iso.length.clamp(0, 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Retraits chauffeurs'),
        actions: [
          PcIconButton(
            Icons.refresh_rounded,
            variant: PcIconButtonVariant.ghost,
            tooltip: 'Rafraîchir',
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppTheme.cardColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: _statusOptions.entries
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _statusFilter == e.key
                                ? Colors.white
                                : AppTheme.textSecondary)),
                    selected: _statusFilter == e.key,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.slate100,
                    onSelected: (_) => _setStatus(e.key),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
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
    if (_withdrawals.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Aucun retrait',
        message: 'Aucune demande de retrait ne correspond à ces filtres.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _withdrawals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildCard(_withdrawals[i]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> w) {
    final status = w['status']?.toString() ?? 'PENDING';
    final statusLabel = _statusLabels[status] ?? status;
    final driver = (w['driver'] is Map)
        ? Map<String, dynamic>.from(w['driver'])
        : <String, dynamic>{};
    final driverName = driver['fullName']?.toString() ??
        w['driverName']?.toString() ??
        '—';
    final driverPhone =
        driver['phone']?.toString() ?? w['driverPhone']?.toString() ?? '';
    final method = w['method']?.toString() ?? '—';
    final methodLabel = _methodLabels[method] ?? method;
    final phoneNumber = w['phoneNumber']?.toString() ??
        w['phone_number']?.toString() ??
        '';
    final failureReason = w['failureReason']?.toString() ??
        w['failure_reason']?.toString() ??
        '';

    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  driverName.isNotEmpty ? driverName[0].toUpperCase() : '?',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _statusColor(status),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        methodLabel,
                        if (phoneNumber.isNotEmpty) phoneNumber,
                        if (driverPhone.isNotEmpty && phoneNumber.isEmpty)
                          driverPhone,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.manrope(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fcfa(w['amount']),
                    style: AppTheme.mono(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(w['createdAt']?.toString() ?? w['created_at']?.toString()),
            style: AppFonts.manrope(
                fontSize: 11.5, color: AppTheme.slate400),
          ),
          if (failureReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              failureReason,
              style: AppFonts.manrope(
                fontSize: 12,
                color: AppTheme.red400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (status == 'PENDING') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PcButton(
                    'Approuver',
                    icon: Icons.check_rounded,
                    size: PcButtonSize.sm,
                    block: true,
                    loading: _processing,
                    onPressed: _processing ? null : () => _approve(w),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PcButton(
                    'Rejeter',
                    icon: Icons.close_rounded,
                    variant: PcButtonVariant.danger,
                    size: PcButtonSize.sm,
                    block: true,
                    loading: _processing,
                    onPressed: _processing ? null : () => _reject(w),
                  ),
                ),
              ],
            ),
          ] else if (status == 'PROCESSING') ...[
            const SizedBox(height: 12),
            PcButton(
              'Compléter',
              icon: Icons.task_alt_rounded,
              size: PcButtonSize.sm,
              block: true,
              loading: _processing,
              onPressed: _processing ? null : () => _complete(w),
            ),
          ],
        ],
      ),
    );
  }
}
