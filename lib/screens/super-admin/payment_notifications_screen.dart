import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

const _lastSeenKey = 'pc_admin_payments_last_seen';
const _successStatuses = {'reussi', 'completed', 'success', 'confirmed'};

/// Flux temps réel des paiements (aligné sur PaymentNotificationsPage du web) :
/// actualisation auto toutes les 15 s, badge "Nouveau", marquage comme vu.
class PaymentNotificationsScreen extends ConsumerStatefulWidget {
  const PaymentNotificationsScreen({super.key});

  @override
  ConsumerState<PaymentNotificationsScreen> createState() =>
      _PaymentNotificationsScreenState();
}

class _PaymentNotificationsScreenState
    extends ConsumerState<PaymentNotificationsScreen> {
  final ApiService _api = ApiService();
  Timer? _timer;
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String _statusFilter = '';
  int _lastSeen = 0;

  static const _statusOptions = <String, String>{
    '': 'Tous',
    'reussi': 'Réussis',
    'en_attente': 'En attente',
    'echoue': 'Échoués',
  };

  @override
  void initState() {
    super.initState();
    _loadLastSeen().then((_) => _load(initial: true));
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadLastSeen() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _lastSeen = sp.getInt(_lastSeenKey) ?? 0;
    } catch (_) {
      _lastSeen = 0;
    }
  }

  Future<void> _load({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      if (_refreshing) return;
      setState(() => _refreshing = true);
    }
    try {
      final params = <String, dynamic>{
        'page': 1,
        'limit': 30,
        'sortBy': 'createdAt',
        'sortOrder': 'desc',
      };
      if (_statusFilter.isNotEmpty) params['status'] = _statusFilter;
      final payments = await _api.adminPayments(params: params);
      if (mounted) {
        setState(() {
          _payments = payments;
          _loading = false;
          _refreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (initial) _error = e.toString();
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _setStatus(String s) {
    setState(() => _statusFilter = s);
    _load(initial: true);
  }

  Future<void> _markSeen() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_lastSeenKey, now);
    } catch (_) {}
    if (mounted) setState(() => _lastSeen = now);
  }

  int _paymentTime(Map<String, dynamic> p) {
    final iso = p['completedAt']?.toString() ??
        p['completed_at']?.toString() ??
        p['createdAt']?.toString() ??
        p['created_at']?.toString() ??
        '';
    if (iso.isEmpty) return 0;
    try {
      return DateTime.parse(iso).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  bool _isToday(Map<String, dynamic> p) {
    final t = _paymentTime(p);
    if (t == 0) return false;
    final d = DateTime.fromMillisecondsSinceEpoch(t);
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  double _amountOf(Map<String, dynamic> p) {
    final v = p['amount'];
    return (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
  }

  String _fcfa(double n) =>
      '${NumberFormat('#,##0', 'fr').format(n.toInt())} FCFA';

  String _statusLabel(String status) {
    if (_successStatuses.contains(status)) return 'Réussi';
    if (status == 'en_attente' || status == 'pending') return 'En attente';
    if (status == 'echoue' || status == 'failed') return 'Échoué';
    if (status == 'rembourse' || status == 'refunded') return 'Remboursé';
    return status;
  }

  IconData _methodIcon(String? method) {
    switch (method) {
      case 'paydunya':
        return Icons.smartphone_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'cash':
        return Icons.payments_rounded;
      case 'cheque':
        return Icons.receipt_long_rounded;
      case 'virement':
        return Icons.account_balance_rounded;
      default:
        return Icons.paid_rounded;
    }
  }

  String _methodLabel(String? method) {
    switch (method) {
      case 'paydunya':
        return 'PayDunya';
      case 'wallet':
        return 'Wallet';
      case 'cash':
        return 'Espèces';
      case 'cheque':
        return 'Chèque';
      case 'virement':
        return 'Virement';
      default:
        return method == null || method.isEmpty ? 'Paiement' : method;
    }
  }

  String _formatDateTime(Map<String, dynamic> p) {
    final t = _paymentTime(p);
    if (t == 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(t);
    return DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final newPayments =
        _payments.where((p) => _paymentTime(p) > _lastSeen).toList();
    final todayPayments = _payments.where(_isToday).toList();
    final todayAmount = todayPayments
        .where((p) => _successStatuses.contains(p['status']?.toString() ?? ''))
        .fold<double>(0, (sum, p) => sum + _amountOf(p));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Notifications de paiement'),
        actions: [
          PcIconButton(
            Icons.done_all_rounded,
            variant: PcIconButtonVariant.ghost,
            tooltip: 'Tout marquer comme vu',
            onPressed: newPayments.isEmpty ? null : _markSeen,
          ),
          const SizedBox(width: 8),
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
                  action: PcButton('Réessayer',
                      onPressed: () => _load(initial: true)),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(initial: true),
                  color: AppTheme.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      _buildStats(newPayments.length, todayPayments.length,
                          todayAmount),
                      const SizedBox(height: 14),
                      _buildFilters(),
                      const SizedBox(height: 6),
                      _buildLiveIndicator(),
                      const SizedBox(height: 10),
                      if (_payments.isEmpty)
                        const PcEmptyState(
                          icon: Icons.payments_rounded,
                          tone: PcTone.primary,
                          title: 'Aucun paiement',
                          message:
                              'Les paiements effectués par les utilisateurs apparaîtront ici en temps réel.',
                        )
                      else
                        _buildList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStats(int newCount, int todayCount, double todayAmount) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: PcStatBox(
                icon: Icons.notifications_active_rounded,
                tone: PcTone.amber,
                value: '$newCount',
                label: 'Nouveaux paiements',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PcStatBox(
                icon: Icons.today_rounded,
                tone: PcTone.primary,
                value: '$todayCount',
                label: 'Aujourd\'hui',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PcStatBox(
                icon: Icons.account_balance_wallet_rounded,
                tone: PcTone.green,
                value: _fcfa(todayAmount),
                label: 'Encaissé aujourd\'hui',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PcStatBox(
                icon: Icons.receipt_long_rounded,
                tone: PcTone.neutral,
                value: '${_payments.length}',
                label: 'Derniers affichés',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return SizedBox(
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
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _refreshing ? AppTheme.amber500 : AppTheme.green600,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Actualisation automatique toutes les 15 s',
          style: AppFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.slate500,
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final rows = <Widget>[];
    for (var i = 0; i < _payments.length; i++) {
      final p = _payments[i];
      rows.add(_buildRow(p));
      if (i != _payments.length - 1) rows.add(const PcDivider());
    }
    return PcCard(padding: EdgeInsets.zero, child: Column(children: rows));
  }

  Widget _buildRow(Map<String, dynamic> p) {
    final status = p['status']?.toString() ?? '';
    final isSuccess = _successStatuses.contains(status);
    final isNew = _paymentTime(p) > _lastSeen;
    final user = (p['user'] is Map)
        ? Map<String, dynamic>.from(p['user'])
        : <String, dynamic>{};
    final userName = user['fullName']?.toString() ??
        user['phone']?.toString() ??
        p['userName']?.toString() ??
        'Utilisateur';
    final parcel = (p['parcel'] is Map)
        ? Map<String, dynamic>.from(p['parcel'])
        : <String, dynamic>{};
    final tracking = parcel['trackingNumber']?.toString() ?? '';
    final phone = p['phoneNumber']?.toString() ?? p['phone_number']?.toString() ?? '';
    final method = p['method']?.toString();

    return Container(
      color: isNew ? AppTheme.teal50 : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSuccess ? AppTheme.green50 : AppTheme.slate100,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              _methodIcon(method),
              size: 21,
              color: isSuccess ? AppTheme.green600 : AppTheme.slate500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      userName,
                      style: AppFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'a payé ${_fcfa(_amountOf(p))}',
                      style: AppFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    if (isNew)
                      const PcBadge('Nouveau', tone: PcTone.amber),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    _methodLabel(method),
                    if (tracking.isNotEmpty) tracking,
                    if (phone.isNotEmpty) phone,
                    _formatDateTime(p),
                  ].join(' · '),
                  style: AppFonts.manrope(
                    fontSize: 11.5,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PcBadge(
            _statusLabel(status),
            tone: isSuccess
                ? PcTone.green
                : status == 'en_attente' || status == 'pending'
                    ? PcTone.amber
                    : status == 'echoue' || status == 'failed'
                        ? PcTone.red
                        : PcTone.neutral,
          ),
        ],
      ),
    );
  }
}
