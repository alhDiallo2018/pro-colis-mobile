import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';
import 'wallet_detail_screen.dart';

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _wallets = [];
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
      final data = await _api.adminWallets();
      setState(() { _wallets = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fcfa(dynamic v) {
    final n = (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
    return '${n.toStringAsFixed(0)} FCFA';
  }

  String _driverName(Map<String, dynamic> w) {
    final driver = w['driver'];
    if (driver is Map) return driver['fullName']?.toString() ?? 'Inconnu';
    return w['driverName']?.toString() ?? 'Inconnu';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des Wallets')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline, tone: AppTheme.red400,
                  title: 'Erreur', message: _error,
                  action: PcButton('Réessayer', onPressed: _load),
                )
              : _wallets.isEmpty
                  ? const EmptyState(icon: Icons.wallet, title: 'Aucun wallet')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _wallets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final w = _wallets[i];
                          final balance = (w['balance'] is num) ? (w['balance'] as num).toDouble() : 0.0;
                          final isActive = w['status'] == 'active';

                          return PcCard(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => WalletDetailScreen(userId: w['userId']?.toString() ?? w['id']?.toString() ?? '', driverName: _driverName(w)),
                              ));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: isActive ? AppTheme.primary.withOpacity(0.1) : AppTheme.slate200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.account_balance_wallet,
                                        color: isActive ? AppTheme.primary : AppTheme.slate400, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_driverName(w), style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                        const SizedBox(height: 2),
                                        Text(w['driver']?['phone']?.toString() ?? '', style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_fcfa(balance), style: AppTheme.mono(fontSize: 16, fontWeight: FontWeight.w800, color: balance >= 0 ? AppTheme.successColor : AppTheme.errorColor)),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isActive ? AppTheme.green50 : AppTheme.slate100,
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                        child: Text(isActive ? 'Actif' : 'Suspendu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? AppTheme.green600 : AppTheme.slate500)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
