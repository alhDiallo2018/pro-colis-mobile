// mobile/lib/screens/driver/points_screen.dart
// Écran Points / Recharge chauffeur

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                  const SizedBox(height: 28),
                  const Text('Historique des transactions',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  _buildTransactionHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: AppTheme.amberGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.brandShadow(),
      ),
      child: Column(
        children: [
          Text(
            _formatFcfa(_balance),
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Points disponibles',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity( 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'Recharger',
            icon: Icons.add_circle_outline,
            backgroundColor: AppTheme.amber400,
            onPressed: () => _showRechargeSheet(),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: CustomButton(
            text: 'Utiliser',
            icon: Icons.redeem,
            outlined: true,
            backgroundColor: AppTheme.amber400,
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionHistory() {
    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: AppTheme.slate300),
            const SizedBox(height: 8),
            const Text('Aucune transaction',
                style: TextStyle(color: AppTheme.slate500)),
          ],
        ),
      );
    }

    return Column(
      children: _transactions.map((tx) {
        final amount = (tx['amount'] ?? 0).toInt();
        final isPositive = amount >= 0;
        final description = tx['description']?.toString() ?? '';
        final type = tx['type']?.toString() ?? '';
        final date = tx['createdAt']?.toString() ?? tx['timestamp']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.slate200),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppTheme.green50
                      : AppTheme.red50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPositive ? Icons.add : Icons.remove,
                  color: isPositive ? AppTheme.green600 : AppTheme.red400,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description.isNotEmpty ? description : type,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        _formatDate(date),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.slate500),
                      ),
                  ],
                ),
              ),
              Text(
                '${isPositive ? '+' : ''}${_formatFcfa(amount)} pts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isPositive ? AppTheme.green600 : AppTheme.red400,
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
