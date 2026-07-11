// mobile/lib/screens/driver/points_screen.dart
// Écran Points / Recharge chauffeur

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/wallet.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/commission_service.dart';
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
  List<WalletTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authState = ref.read(authProvider);
      final userId = authState.user?.id ?? '';
      final balance = await _apiService.getWalletBalance(userId);
      final wallet = await _apiService.getWallet(userId);
      if (mounted) {
        setState(() {
          _balance = balance;
          _transactions = wallet.transactions;
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
        title: const Text('Mon Portefeuille',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 20),
                  const PcSectionHeader('Comment gérer mon portefeuille'),
                  _buildHowItWorks(),
                  const SizedBox(height: 22),
                  const PcSectionHeader('Historique du portefeuille'),
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
                      'PORTEFEUILLE PRO-COLIS',
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
                          'FCFA',
                          style: AppTheme.mono(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.amberOnFg.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Commission: ${CommissionService.percentage.toStringAsFixed(0)}% (min ${CommissionService.minimum.toStringAsFixed(0)} FCFA, max ${CommissionService.maximum.toStringAsFixed(0)} FCFA)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.amberOnFg.withOpacity(0.6),
                      ),
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
              'Des commissions sont automatiquement déduites', 'À chaque livraison acceptée'),
          row(Icons.add_circle_rounded, PcTone.amber, 'Rechargez votre portefeuille',
              '1 FCFA = 1 crédit. Rechargez en Wave, OM, CB...'),
          row(Icons.rocket_launch_rounded, PcTone.primary,
              'Maintenez un solde suffisant', 'Pour accepter des livraisons',
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
          message: 'Vos crédits et débits apparaîtront ici.',
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < _transactions.length; i++) {
      final tx = _transactions[i];
      final amount = tx.amount;
      final isPositive = amount > 0 && tx.type == WalletTransactionType.deposit;
      final description = tx.description;
      final typeLabel = tx.type.label;
      final date = tx.createdAt.toIso8601String();
      final title = description.isNotEmpty ? description : typeLabel;

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
            '${amount > 0 ? '+' : ''}${_formatFcfa(amount)} FCFA',
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
    final authState = ref.read(authProvider);
    final userId = authState.user?.id ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RechargeSheetContent(userId: userId),
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
  final String userId;
  const _RechargeSheetContent({required this.userId});

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
    {'value': 'paydunya', 'label': 'PayDunya', 'icon': Icons.payment},
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
      if (_selectedMethod == 'paydunya') {
        final payment = await _apiService.createPaydunyaPayment(
          'wallet',
          amount: _amount.toDouble(),
        );
        final paymentUrl = payment['paymentUrl']?.toString();
        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
          final token = payment['token']?.toString() ?? '';
          final confirm = await _apiService.confirmPaydunyaPayment(token);
          if (confirm['status'] == 'completed') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Paiement confirmé via PayDunya'),
                    backgroundColor: AppTheme.green600),
              );
              Navigator.pop(context);
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Paiement en attente de confirmation'),
                    backgroundColor: AppTheme.amber600),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Erreur: impossible de créer le paiement PayDunya'),
                  backgroundColor: AppTheme.error),
            );
          }
        }
      } else {
        final result = await _apiService.depositWallet(
          widget.userId,
          {
            'amount': _amount,
            'method': _selectedMethod,
            if (_needsPhone) 'phone': _phoneController.text.trim(),
          },
        );

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
            'Recharger mon portefeuille',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '1 FCFA = 1 crédit. Les crédits sont utilisés pour payer les commissions.',
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
                                '${pack['points']}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? AppTheme.amber700
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              const Text(
                                'FCFA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.slate500,
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
