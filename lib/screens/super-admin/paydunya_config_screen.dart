import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';

import '../../services/paydunya_config_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

class PaydunyaConfigScreen extends StatefulWidget {
  const PaydunyaConfigScreen({super.key});

  @override
  State<PaydunyaConfigScreen> createState() => _PaydunyaConfigScreenState();
}

class _PaydunyaConfigScreenState extends State<PaydunyaConfigScreen> {
  final PaydunyaConfigService _paydunyaService = PaydunyaConfigService();

  final _masterKeyCtrl = TextEditingController();
  final _privateKeyCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _mode = 'test';
  bool _configured = false;
  String? _message;
  bool _messageSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _masterKeyCtrl.dispose();
    _privateKeyCtrl.dispose();
    _tokenCtrl.dispose();
    _storeNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    final config = await _paydunyaService.getPaydunyaConfig();
    if (mounted) {
      setState(() {
        _loading = false;
        if (config != null) {
          _masterKeyCtrl.text = config.masterKey;
          _privateKeyCtrl.text = config.privateKey;
          _tokenCtrl.text = config.token;
          _mode = config.mode == 'live' ? 'live' : 'test';
          _storeNameCtrl.text = config.storeName;
          _configured = config.configured;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _message = null; });
    final result = await _paydunyaService.updatePaydunyaConfig({
      'masterKey': _masterKeyCtrl.text.trim(),
      'privateKey': _privateKeyCtrl.text.trim(),
      'token': _tokenCtrl.text.trim(),
      'mode': _mode,
      'storeName': _storeNameCtrl.text.trim(),
    });
    if (mounted) {
      setState(() {
        _saving = false;
        if (result != null) {
          _masterKeyCtrl.text = result.masterKey;
          _privateKeyCtrl.text = result.privateKey;
          _tokenCtrl.text = result.token;
          _mode = result.mode == 'live' ? 'live' : 'test';
          _storeNameCtrl.text = result.storeName;
          _configured = result.configured;
          _message = 'Configuration PayDunya enregistrée.';
          _messageSuccess = true;
        } else {
          _message = 'Échec de la sauvegarde.';
          _messageSuccess = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Configuration PayDunya'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PcCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Configuration PayDunya (Paiements)', style: AppFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          ),
                          PcBadge(
                            _configured ? 'Configuré' : 'Non configuré',
                            tone: _configured ? PcTone.green : PcTone.red,
                            icon: _configured ? Icons.check_circle : Icons.error_outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "PayDunya est le fournisseur de paiements mobiles (Orange Money, Wave, cartes). Les clés masquées (****) sont conservées telles quelles si vous ne les modifiez pas.",
                        style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _masterKeyCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Master Key',
                          hintText: '****XXXX',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _privateKeyCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Private Key',
                          hintText: '****XXXX',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _tokenCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Token',
                          hintText: '****XXXX',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _storeNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom de la boutique',
                          hintText: 'SENDPROCOLIS',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Mode', style: AppFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Test'),
                            selected: _mode == 'test',
                            onSelected: (_) => setState(() => _mode = 'test'),
                          ),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            label: const Text('Live'),
                            selected: _mode == 'live',
                            onSelected: (_) => setState(() => _mode = 'live'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      PcButton(
                        'Enregistrer',
                        icon: Icons.save,
                        loading: _saving,
                        variant: PcButtonVariant.primary,
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _messageSuccess ? AppTheme.green50 : AppTheme.red50,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _messageSuccess ? Icons.check_circle : Icons.error_outline,
                          color: _messageSuccess ? AppTheme.green600 : AppTheme.red500,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _message!,
                            style: AppFonts.manrope(
                              fontSize: 13,
                              color: _messageSuccess ? AppTheme.green700 : AppTheme.red500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
