import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  String? _error;

  int _page = 1;
  int _total = 0;
  int _totalPages = 0;
  static const int _limit = 20;

  String _statusFilter = '';
  String _methodFilter = '';

  static const _statusOptions = <String, String>{
    '': 'Tous',
    'reussi': 'Réussis',
    'en_attente': 'En attente',
    'echoue': 'Échoués',
    'rembourse': 'Remboursés',
  };

  static const _methodOptions = <String, String>{
    '': 'Toutes les méthodes',
    'paydunya': 'PayDunya',
    'wallet': 'Wallet',
    'cash': 'Espèces',
    'cheque': 'Chèque',
    'virement': 'Virement',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = <String, dynamic>{
        'page': _page,
        'limit': _limit,
      };
      if (_statusFilter.isNotEmpty) params['status'] = _statusFilter;
      if (_methodFilter.isNotEmpty) params['method'] = _methodFilter;

      final result = await _loadPaymentsWithPagination(params);
      final pagination = Map<String, dynamic>.from(
        result['pagination'] ?? const <String, dynamic>{},
      );
      final payments = List<Map<String, dynamic>>.from(
        result['payments'] ?? result['data'] ?? <dynamic>[],
      );

      if (mounted) {
        setState(() {
          _payments = payments;
          _total = int.tryParse(pagination['total']?.toString() ?? '') ?? payments.length;
          _totalPages = int.tryParse(pagination['pages']?.toString() ?? '') ?? 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<Map<String, dynamic>> _loadPaymentsWithPagination(
    Map<String, dynamic> params,
  ) async {
    final response = await _api.adminPayments(params: params);
    return {
      'payments': response,
      'pagination': <String, dynamic>{'total': response.length, 'pages': 1},
    };
  }

  void _setStatus(String s) {
    setState(() { _statusFilter = s; _page = 1; });
    _load();
  }

  void _setMethod(String m) {
    setState(() { _methodFilter = m; _page = 1; });
    _load();
  }

  void _prevPage() {
    if (_page <= 1) return;
    setState(() => _page--);
    _load();
  }

  void _nextPage() {
    if (_page >= _totalPages) return;
    setState(() => _page++);
    _load();
  }

  String _fcfa(dynamic v) {
    final n = (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
    return '${n.toStringAsFixed(0)} FCFA';
  }

  String _status(Map<String, dynamic> p) =>
      p['status']?.toString() ?? 'pending';

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':
      case 'reussi':
      case 'success':
        return AppTheme.green600;
      case 'pending':
      case 'en_attente':
        return AppTheme.amber500;
      case 'processing':
        return AppTheme.teal500;
      case 'failed':
      case 'echoue':
        return AppTheme.red400;
      case 'refunded':
      case 'rembourse':
        return AppTheme.slate500;
      default:
        return AppTheme.slate500;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso.substring(0, iso.length.clamp(0, 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Paiements')),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody()),
          if (_total > _limit) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppTheme.cardColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          SizedBox(
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
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _methodOptions.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: _methodFilter == e.key
                                    ? Colors.white
                                    : AppTheme.textSecondary)),
                        selected: _methodFilter == e.key,
                        selectedColor: AppTheme.teal500,
                        backgroundColor: AppTheme.slate100,
                        onSelected: (_) => _setMethod(e.key),
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
        ],
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
    if (_payments.isEmpty) {
      return const EmptyState(
        icon: Icons.payments,
        title: 'Aucun paiement',
        message: 'Aucun paiement ne correspond à ces filtres.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _payments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = _payments[i];
          final st = _status(p);
          return PcCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor(st).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.receipt, size: 20,
                      color: _statusColor(st)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['user']?['fullName']?.toString() ??
                            p['userName']?.toString() ??
                            'Inconnu',
                        style: AppFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p['method']?.toString() ?? '-'} · ${_formatDate(p['createdAt']?.toString())}',
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
                      _fcfa(p['amount']),
                      style: AppTheme.mono(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(st).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        st,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: _statusColor(st)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: const Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PcButton(
            'Précédent',
            variant: PcButtonVariant.secondary,
            size: PcButtonSize.sm,
            onPressed: _page > 1 ? _prevPage : null,
          ),
          const SizedBox(width: 14),
          Text(
            'Page $_page / $_totalPages',
            style: AppFonts.manrope(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          PcButton(
            'Suivant',
            variant: PcButtonVariant.secondary,
            size: PcButtonSize.sm,
            onPressed: _page < _totalPages ? _nextPage : null,
          ),
        ],
      ),
    );
  }
}
