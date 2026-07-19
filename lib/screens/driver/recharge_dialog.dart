import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/score_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/pc_components.dart';

class RechargeDialog extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onSuccess;

  const RechargeDialog({
    super.key,
    required this.onClose,
    this.onSuccess,
  });

  @override
  ConsumerState<RechargeDialog> createState() => _RechargeDialogState();
}

class _RechargeDialogState extends ConsumerState<RechargeDialog> {
  static const _packs = [
    {'label': '500 points — 500 FCFA', 'points': 500},
    {'label': '1 000 points — 1 000 FCFA', 'points': 1000},
    {'label': '3 000 points — 3 000 FCFA', 'points': 3000},
    {'label': '5 000 points — 5 000 FCFA', 'points': 5000},
    {'label': '10 000 points — 10 000 FCFA', 'points': 10000},
  ];

  static const _paymentMethods = [
    {'value': 'wallet', 'label': 'Portefeuille (solde disponible)'},
    {'value': 'paydunya', 'label': 'PayDunya (Wave, OM, Carte…)'},
    {'value': 'wave', 'label': 'Wave (direct)'},
    {'value': 'orange_money', 'label': 'Orange Money (direct)'},
    {'value': 'freeMoney', 'label': 'FreeMoney (direct)'},
    {'value': 'card', 'label': 'Carte bancaire (direct)'},
    {'value': 'cash', 'label': 'Espèces'},
  ];

  String _selectedPack = '500';
  final _customPointsCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _method = 'wallet';
  bool _useCustom = false;
  bool _loading = false;
  String? _error;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    final userPhone = ref.read(authProvider).user?.phone ?? '';
    _phoneCtrl.text = userPhone;
  }

  @override
  void dispose() {
    _customPointsCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  int get _points => _useCustom ? (int.tryParse(_customPointsCtrl.text.trim()) ?? 0) : int.parse(_selectedPack);

  Future<void> _submit() async {
    final points = _points;
    if (points < 100) {
      setState(() => _error = 'Minimum 100 points.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await _apiService.purchasePoints({
        'points': points,
        'method': _method,
        if (_phoneCtrl.text.trim().isNotEmpty) 'phoneNumber': _phoneCtrl.text.trim(),
      });
      widget.onSuccess?.call();
      widget.onClose();
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final walletBalance = walletState.balance;
    final isWallet = _method == 'wallet';
    final isPaydunya = _method == 'paydunya';
    final showPhone = _method != 'cash' && _method != 'paydunya' && _method != 'wallet';
    final valid = _points >= 100;

    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.amber50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: AppTheme.amber500, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recharger des points',
                      style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ),
                  IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
              const SizedBox(height: 16),
              if (isWallet)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.teal50,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Text(
                    'Solde portefeuille : ${formatFcfa(walletBalance)}',
                    style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.teal700, fontWeight: FontWeight.w600),
                  ),
                ),
              if (!_useCustom)
                DropdownButtonFormField<String>(
                  value: _selectedPack,
                  decoration: const InputDecoration(labelText: 'Forfait'),
                  items: _packs.map((p) => DropdownMenuItem(value: p['points'].toString(), child: Text(p['label'] as String))).toList(),
                  onChanged: (v) => setState(() => _selectedPack = v!),
                )
              else
                TextField(
                  controller: _customPointsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de points',
                    hintText: 'Ex : 2 000',
                    prefixIcon: Icon(Icons.toll),
                  ),
                ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _useCustom = !_useCustom),
                child: Text(
                  _useCustom ? '← Choisir un forfait' : 'Montant personnalisé',
                  style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _method,
                decoration: const InputDecoration(labelText: 'Moyen de paiement'),
                items: _paymentMethods.map((m) => DropdownMenuItem(value: m['value'] as String, child: Text(m['label'] as String))).toList(),
                onChanged: (v) {
                  setState(() { _method = v!; _error = null; });
                },
              ),
              if (showPhone) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: '+221 77 000 00 00',
                    prefixIcon: Icon(Icons.call),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.slate50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Les points vous permettent d\'accéder aux annonces de colis et de recevoir des missions. 1 point = 1 FCFA.',
                      style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                    ),
                    if (isWallet)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Le montant sera débité de votre portefeuille immédiatement.',
                          style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.teal700, fontWeight: FontWeight.w500),
                        ),
                      ),
                    if (isPaydunya)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'PayDunya accepte Wave, Orange Money, FreeMoney et carte bancaire.',
                          style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.teal700, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.red500)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: PcButton('Annuler', variant: PcButtonVariant.secondary, onPressed: widget.onClose)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PcButton(
                      _buttonLabel,
                      icon: Icons.add,
                      variant: PcButtonVariant.amber,
                      loading: _loading,
                      onPressed: valid && !_loading ? _submit : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _buttonLabel {
    final pts = _points;
    if (_method == 'wallet') return 'Acheter $pts pts (portefeuille)';
    if (_method == 'paydunya') return 'Payer $pts pts avec PayDunya';
    return 'Acheter $pts pts';
  }
}
