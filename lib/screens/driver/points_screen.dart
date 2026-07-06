// mobile/lib/screens/driver/points_screen.dart
// Écran Points / Recharge chauffeur

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/pc_components.dart';

class DriverPointsScreen extends ConsumerStatefulWidget {
  const DriverPointsScreen({super.key});

  @override
  ConsumerState<DriverPointsScreen> createState() =>
      _DriverPointsScreenState();
}

class _DriverPointsScreenState extends ConsumerState<DriverPointsScreen> {
  final ApiService _apiService = ApiService();
  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final balance = await _apiService.getScoreBalance();
      final history = await _apiService.getScoreHistory();
      if (mounted) {
        setState(() {
          _balance = balance;
          _transactions = history;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yy HH:mm').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatFcfa(dynamic amount) {
    final n = (amount ?? 0).toInt();
    return NumberFormat('#,##0', 'fr').format(n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Mes Points',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 20),
                  const PcSectionHeader('Comment gagner des points'),
                  _buildHowItWorks(),
                  const SizedBox(height: 22),
                  const PcSectionHeader('Historique des points'),
                  _buildTransactionHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    size: 28, color: AppTheme.amberOnFg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOLDE DE POINTS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: AppTheme.amberOnFg.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _formatFcfa(_balance),
                          style: AppTheme.mono(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.amberOnFg,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'pts',
                          style: AppTheme.mono(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.amberOnFg.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Row(
              children: [
                Expanded(
                  child: PcButton(
                    'Recharger',
                    icon: Icons.add_rounded,
                    variant: PcButtonVariant.secondary,
                    block: true,
                    onPressed: _showRechargeSheet,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GhostButton(
                    label: 'Utiliser',
                    icon: Icons.redeem_rounded,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    Widget row(IconData icon, PcTone tone, String title, String subtitle,
        {bool divider = true}) {
      return Column(
        children: [
          PcListRow(
            icon: icon,
            iconTone: tone,
            title: title,
            subtitle: subtitle,
          ),
          if (divider) const PcDivider(),
        ],
      );
    }

    return PcCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          row(Icons.local_shipping_rounded, PcTone.green,
              'Effectuez des livraisons', 'Gagnez des points à chaque colis livré'),
          row(Icons.add_circle_rounded, PcTone.amber, 'Rechargez votre solde',
              '1 point = 1 FCFA'),
          row(Icons.rocket_launch_rounded, PcTone.primary,
              'Boostez vos annonces', 'Utilisez vos points pour plus de visibilité',
              divider: false),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory() {
    if (_transactions.isEmpty) {
      return PcCard(
        padding: EdgeInsets.zero,
        child: const PcEmptyState(
          icon: Icons.savings_rounded,
          title: 'Aucun mouvement',
          message: 'Vos crédits et débits de points apparaîtront ici.',
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < _transactions.length; i++) {
      final tx = _transactions[i];
      final amount = (tx['amount'] ?? 0).toInt();
      final isPositive = amount >= 0;
      final description = tx['description']?.toString() ?? '';
      final type = tx['type']?.toString() ?? '';
      final date =
          tx['createdAt']?.toString() ?? tx['timestamp']?.toString() ?? '';
      final title = description.isNotEmpty ? description : type;

      rows.add(
        PcListRow(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPositive ? AppTheme.green50 : AppTheme.red50,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: isPositive ? AppTheme.green700 : AppTheme.red500,
              size: 22,
            ),
          ),
          title: title.isNotEmpty ? title : 'Mouvement',
          subtitle: date.isNotEmpty ? _formatDate(date) : null,
          trailing: Text(
            '${isPositive ? '+' : ''}${_formatFcfa(amount)} pts',
            style: AppTheme.mono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isPositive ? AppTheme.green600 : AppTheme.red500,
            ),
          ),
        ),
      );
      if (i != _transactions.length - 1) rows.add(const PcDivider());
    }

    return PcCard(
      padding: EdgeInsets.zero,
      child: Column(children: rows),
    );
  }

  // ------ Recharge Bottom Sheet ------

  void _showRechargeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RechargeSheetContent(),
    ).then((_) => _loadData());
  }
}

// Bouton translucide posé sur le dégradé ambre (action secondaire du solde).
class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GhostButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppTheme.amberOnFg),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.amberOnFg,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== RECHARGE BOTTOM SHEET ====================

class _RechargeSheetContent extends StatefulWidget {
  const _RechargeSheetContent();

  @override
  State<_RechargeSheetContent> createState() => _RechargeSheetContentState();
}

class _RechargeSheetContentState extends State<_RechargeSheetContent> {
  final ApiService _apiService = ApiService();
  final _phoneController = TextEditingController();
  final _customAmountController = TextEditingController();

  int? _selectedPack;
  String? _selectedMethod;
  bool _isCustomAmount = false;
  bool _isSubmitting = false;

  static const List<Map<String, dynamic>> _packs = [
    {'points': 500, 'price': 500},
    {'points': 1000, 'price': 1000},
    {'points': 3000, 'price': 3000},
    {'points': 5000, 'price': 5000},
    {'points': 10000, 'price': 10000},
  ];

  static const List<Map<String, dynamic>> _paymentMethods = [
    {'value': 'wave', 'label': 'Wave', 'icon': Icons.phone_android},
    {
      'value': 'orange_money',
      'label': 'Orange Money',
      'icon': Icons.phone_iphone
    },
    {
      'value': 'free_money',
      'label': 'Free Money',
      'icon': Icons.phone_android
    },
    {'value': 'card', 'label': 'Carte bancaire', 'icon': Icons.credit_card},
    {'value': 'cash', 'label': 'Espèces', 'icon': Icons.money},
  ];

  bool get _needsPhone =>
      _selectedMethod == 'wave' ||
      _selectedMethod == 'orange_money' ||
      _selectedMethod == 'free_money';

  int get _amount {
    if (_isCustomAmount) {
      return int.tryParse(_customAmountController.text.trim()) ?? 0;
    }
    if (_selectedPack != null && _selectedPack! < _packs.length) {
      return _packs[_selectedPack!]['points'] as int;
    }
    return 0;
  }

  bool get _canSubmit => _amount > 0 && _selectedMethod != null;

  @override
  void dispose() {
    _phoneController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    if (_needsPhone && _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez entrer le numéro de téléphone'),
            backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await _apiService.purchasePoints({
        'amount': _amount,
        'method': _selectedMethod,
        if (_needsPhone) 'phone': _phoneController.text.trim(),
      });

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Recharge effectuée avec succès'),
                backgroundColor: AppTheme.green600),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    result['message']?.toString() ?? 'Erreur de recharge'),
                backgroundColor: AppTheme.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recharger mes points',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '1 point = 1 FCFA',
            style: TextStyle(fontSize: 13, color: AppTheme.slate500),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Packs grid
                  const Text('Choisir un pack',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: _packs.length,
                    itemBuilder: (context, index) {
                      final pack = _packs[index];
                      final selected = _selectedPack == index && !_isCustomAmount;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPack = index;
                            _isCustomAmount = false;
                            _customAmountController.clear();
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.amber50
                                : AppTheme.slate50,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.amber400
                                  : AppTheme.slate200,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${pack['points']} pts',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? AppTheme.amber700
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${pack['price']} FCFA',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: selected
                                      ? AppTheme.amber500
                                      : AppTheme.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // Custom amount toggle
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isCustomAmount = !_isCustomAmount;
                        if (_isCustomAmount) _selectedPack = null;
                        if (!_isCustomAmount) _customAmountController.clear();
                      });
                    },
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _isCustomAmount
                            ? AppTheme.teal50
                            : AppTheme.slate50,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: _isCustomAmount
                              ? AppTheme.teal500
                              : AppTheme.slate200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isCustomAmount
                                ? Icons.toggle_on
                                : Icons.toggle_off,
                            color: _isCustomAmount
                                ? AppTheme.teal500
                                : AppTheme.slate400,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Montant personnalisé',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isCustomAmount) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customAmountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: InputDecoration(
                        hintText: 'Montant en FCFA',
                        prefixIcon: const Icon(Icons.monetization_on_outlined),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Payment method
                  const Text('Moyen de paiement',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _paymentMethods.map((method) {
                      final selected = _selectedMethod == method['value'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMethod = method['value'] as String;
                          });
                        },
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 60) / 3,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.teal50
                                : AppTheme.slate50,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.teal500
                                  : AppTheme.slate200,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                method['icon'] as IconData,
                                size: 24,
                                color: selected
                                    ? AppTheme.teal600
                                    : AppTheme.slate500,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                method['label'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppTheme.teal600
                                      : AppTheme.slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_needsPhone) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Numéro de téléphone',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Submit
                  CustomButton(
                    text: _isSubmitting ? 'Rechargement...' : 'Recharger',
                    isLoading: _isSubmitting,
                    backgroundColor: AppTheme.amber400,
                    onPressed: _canSubmit && !_isSubmitting ? _submit : null,
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
