import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.adminPayments();
      setState(() { _payments = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fcfa(dynamic v) {
    final n = (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
    return '${n.toStringAsFixed(0)} FCFA';
  }

  String _status(Map<String, dynamic> p) => p['status']?.toString() ?? 'pending';
  Color _statusColor(String s) {
    switch (s) {
      case 'completed': return AppTheme.green600;
      case 'pending': return AppTheme.amber500;
      case 'processing': return AppTheme.teal500;
      case 'failed': return AppTheme.red400;
      case 'refunded': return AppTheme.deep500;
      default: return AppTheme.slate500;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiements')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.error_outline, tone: AppTheme.red400, title: 'Erreur', message: _error, action: PcButton('Réessayer', onPressed: _load))
              : _payments.isEmpty
                  ? const EmptyState(icon: Icons.payments, title: 'Aucun paiement')
                  : RefreshIndicator(
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
                                  child: Icon(Icons.receipt, size: 20, color: _statusColor(st)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p['user']?['fullName']?.toString() ?? p['userName']?.toString() ?? 'Inconnu',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text('${p['method']?.toString() ?? '-'} · ${p['reference']?.toString() ?? ''}',
                                          style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_fcfa(p['amount']), style: AppTheme.mono(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _statusColor(st).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(st, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(st))),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
