import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final ApiService _api = ApiService();
  double _balance = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authProvider);
      final userId = auth.user?.id ?? '';
      final wallet = await _api.getWallet(userId);
      if (mounted) {
        setState(() {
          _balance = wallet.balance;
          _transactions = wallet.transactions.map((t) => {
            'id': t.id,
            'amount': t.amount,
            'type': t.type.value,
            'description': t.description,
            'date': t.createdAt.toIso8601String(),
          }).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatFcfa(dynamic amount) {
    final n = (amount ?? 0).toInt();
    return NumberFormat('#,##0', 'fr').format(n);
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yy HH:mm').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  void _showWithdrawSheet() {
    final auth = ref.read(authProvider);
    final userId = auth.user?.id ?? '';
    final userPhone = auth.user?.phone ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WithdrawSheetContent(
        userId: userId,
        balance: _balance,
        userPhone: userPhone,
        onWithdrawn: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Points & paiements'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                children: [
                  _BalanceHero(balance: _balance),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PcButton(
                          'Utiliser mes points',
                          icon: Icons.redeem_rounded,
                          variant: PcButtonVariant.secondary,
                          block: true,
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PcButton(
                          'Retirer des fonds',
                          icon: Icons.payments,
                          variant: PcButtonVariant.primary,
                          block: true,
                          onPressed: _showWithdrawSheet,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const PcSectionHeader('Historique'),
                  _buildTransactions(),
                ],
              ),
            ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  Widget _buildTransactions() {
    if (_transactions.isEmpty) {
      return PcCard(
        padding: EdgeInsets.zero,
        child: const PcEmptyState(
          icon: Icons.savings_rounded,
          title: 'Aucun mouvement',
          message: 'Vos crédits et débits apparaîtront ici.',
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < _transactions.length; i++) {
      final tx = _transactions[i];
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
      final isPositive = amount > 0;
      final desc = tx['description']?.toString() ?? '';
      final date = tx['date']?.toString() ?? '';
      final dateFormatted = date.isNotEmpty ? _formatDate(date) : '';

      rows.add(PcListRow(
        icon: isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        iconTone: isPositive ? PcTone.green : PcTone.red,
        title: desc.isNotEmpty ? desc : 'Mouvement',
        subtitle: dateFormatted.isNotEmpty ? dateFormatted : null,
        trailing: Text(
          '${amount > 0 ? '+' : ''}${_formatFcfa(amount)} FCFA',
          style: AppTheme.mono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isPositive ? AppTheme.green600 : AppTheme.red500,
          ),
        ),
      ));
      if (i != _transactions.length - 1) rows.add(const PcDivider());
    }

    return PcCard(padding: EdgeInsets.zero, child: Column(children: rows));
  }
}

class _BalanceHero extends StatelessWidget {
  final double balance;

  const _BalanceHero({required this.balance});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'fr');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.amberGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.amberShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SOLDE DE POINTS',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.amberOnFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.amberOnFg, size: 28),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              text: fmt.format(balance.toInt()),
              children: const [TextSpan(text: ' pts', style: TextStyle(fontSize: 18))],
            ),
            style: AppTheme.mono(color: AppTheme.amberOnFg, fontSize: 38, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '≈ ${fmt.format((balance * 10).toInt())} FCFA de réductions disponibles',
            style: GoogleFonts.manrope(color: AppTheme.amberOnFg.withOpacity(0.8), fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _WithdrawSheetContent extends StatefulWidget {
  final String userId;
  final double balance;
  final String userPhone;
  final VoidCallback onWithdrawn;

  const _WithdrawSheetContent({
    required this.userId,
    required this.balance,
    required this.userPhone,
    required this.onWithdrawn,
  });

  @override
  State<_WithdrawSheetContent> createState() => _WithdrawSheetContentState();
}

class _WithdrawSheetContentState extends State<_WithdrawSheetContent> {
  final ApiService _api = ApiService();
  final _amountCtrl = TextEditingController();
  late final _phoneCtrl = TextEditingController(text: widget.userPhone);

  String _method = 'wave';
  bool _submitting = false;

  static const _methods = [
    {'value': 'wave', 'label': 'Wave'},
    {'value': 'orange_money', 'label': 'Orange Money'},
    {'value': 'freemMoney', 'label': 'FreeMoney'},
    {'value': 'bank', 'label': 'Virement bancaire'},
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _needsPhone => _method == 'wave' || _method == 'orange_money' || _method == 'freemMoney';

  Future<void> _submit() async {
    final amountText = _amountCtrl.text.trim();
    final amount = double.tryParse(amountText) ?? 0;
    if (amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant minimum : 100 FCFA'), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (amount > widget.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solde insuffisant'), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (_needsPhone && _phoneCtrl.text.trim().isEmpty) {
      _phoneCtrl.text = widget.userPhone;
      if (widget.userPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numéro de téléphone requis'), backgroundColor: AppTheme.error),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{
        'amount': amount,
        'method': _method,
        'userId': widget.userId,
      };
      if (_needsPhone) data['phone'] = _phoneCtrl.text.trim().isNotEmpty
          ? _phoneCtrl.text.trim()
          : widget.userPhone;

      final result = await _api.withdrawWallet(data);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Retrait effectué. Traité sous 24-48h.'), backgroundColor: AppTheme.green600),
          );
          widget.onWithdrawn();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message']?.toString() ?? 'Erreur de retrait'), backgroundColor: AppTheme.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final fmt = NumberFormat('#,##0', 'fr');

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppTheme.slate300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 8),
          const Text('Retirer des fonds', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'Solde disponible : ${fmt.format(widget.balance.toInt())} FCFA',
            style: const TextStyle(fontSize: 13, color: AppTheme.slate500),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Montant (FCFA)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Ex : 5 000',
                      prefixIcon: Icon(Icons.payments),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Mode de retrait', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _methods.map((m) {
                      final selected = _method == m['value'];
                      return GestureDetector(
                        onTap: () => setState(() => _method = m['value'] as String),
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 60) / 2 - 5,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.teal50 : AppTheme.slate50,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: selected ? AppTheme.teal500 : AppTheme.slate200,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            m['label'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selected ? AppTheme.teal600 : AppTheme.slate600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_needsPhone) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '+221 77 000 00 00',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.slate100,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      'Solde disponible : ${fmt.format(widget.balance.toInt())} FCFA. Le retrait sera traité sous 24-48h.',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 20),
                  PcButton(
                    _submitting ? 'Retrait en cours...' : 'Retirer',
                    loading: _submitting,
                    block: true,
                    onPressed: _submitting ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
