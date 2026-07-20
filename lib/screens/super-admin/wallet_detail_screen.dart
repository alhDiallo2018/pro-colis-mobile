import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

class WalletDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  final String driverName;

  const WalletDetailScreen({super.key, required this.userId, this.driverName = ''});

  @override
  ConsumerState<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends ConsumerState<WalletDetailScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _transactions = [];
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
      final w = await _api.adminWalletDetail(widget.userId);
      final txs = await _api.adminWalletTransactions(widget.userId);
      setState(() { _wallet = w; _transactions = txs; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fcfa(dynamic v) {
    final n = (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
    return '${n.toStringAsFixed(0)} FCFA';
  }

  Future<void> _showRechargeDebitDialog(bool isRecharge) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRecharge ? 'Recharger le wallet' : 'Débiter le wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant (FCFA)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || amount <= 0) return;
              final data = {'amount': amount, 'description': descCtrl.text};
              final res = isRecharge
                  ? await _api.adminRechargeWallet(widget.userId, data)
                  : await _api.adminDebitWallet(widget.userId, data);
              if (res['success'] == true) {
                if (ctx.mounted) Navigator.pop(ctx, true);
              }
            },
            child: Text(isRecharge ? 'Recharger' : 'Débiter'),
          ),
        ],
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.driverName.isNotEmpty ? widget.driverName : (_wallet?['driver']?['fullName']?.toString() ?? 'Wallet');
    return Scaffold(
      appBar: AppBar(title: Text('Wallet de $name')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.error_outline, tone: AppTheme.red400, title: 'Erreur', message: _error, action: PcButton('Réessayer', onPressed: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_wallet != null) _walletHeader(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Recharger'),
                              onPressed: () => _showRechargeDebitDialog(true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.remove, size: 18),
                              label: const Text('Débiter'),
                              onPressed: () => _showRechargeDebitDialog(false),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor, side: const BorderSide(color: AppTheme.errorColor)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Historique des transactions', style: AppFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 10),
                      if (_transactions.isEmpty)
                        const EmptyState(icon: Icons.receipt_long, title: 'Aucune transaction')
                      else
                        ..._transactions.map(_txTile),
                    ],
                  ),
                ),
    );
  }

  Widget _walletHeader() {
    final w = _wallet!;
    final balance = (w['balance'] is num) ? (w['balance'] as num).toDouble() : 0.0;
    final deposited = (w['totalDeposited'] is num) ? (w['totalDeposited'] as num).toDouble() : 0.0;
    final spent = (w['totalSpent'] is num) ? (w['totalSpent'] as num).toDouble() : 0.0;

    return PcCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('Solde actuel', style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(_fcfa(balance), style: AppTheme.mono(fontSize: 32, fontWeight: FontWeight.w800, color: balance >= 0 ? AppTheme.successColor : AppTheme.errorColor)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniStat('Total rechargé', _fcfa(deposited), AppTheme.primary),
              _miniStat('Total dépensé', _fcfa(spent), AppTheme.amber500),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: AppFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: AppFonts.manrope(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _txTile(Map<String, dynamic> tx) {
    final amount = (tx['amount'] is num) ? (tx['amount'] as num).toDouble() : 0.0;
    final isCredit = amount >= 0 || tx['type'] == 'deposit';
    final type = tx['type']?.toString() ?? 'transaction';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PcCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isCredit ? AppTheme.green50 : AppTheme.red50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 18, color: isCredit ? AppTheme.green600 : AppTheme.red400),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.toUpperCase(), style: AppFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  if (tx['description'] != null)
                    Text(tx['description'].toString(), style: AppFonts.manrope(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Text(_fcfa(amount), style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w700, color: isCredit ? AppTheme.green600 : AppTheme.red400)),
          ],
        ),
      ),
    );
  }
}
