import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

class CommissionConfigScreen extends ConsumerStatefulWidget {
  const CommissionConfigScreen({super.key});

  @override
  ConsumerState<CommissionConfigScreen> createState() => _CommissionConfigScreenState();
}

class _CommissionConfigScreenState extends ConsumerState<CommissionConfigScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _configs = [];
  List<Map<String, dynamic>> _simulation = [];
  bool _loading = true;
  String? _error;
  final _amountCtrl = TextEditingController(text: '10000');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final configs = await _api.adminCommissionConfig();
      setState(() { _configs = configs; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _simulate() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null) return;
    try {
      final res = await _api.adminSimulateCommission(amount);
      setState(() { _simulation = res; });
    } catch (_) {}
  }

  Future<void> _toggleActive(String profile, bool current) async {
    await _api.adminUpdateCommissionConfig({'profile': profile, 'isActive': !current});
    _load();
  }

  String _fcfa(dynamic v) {
    final n = (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
    return '${n.toStringAsFixed(0)} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration Commissions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.error_outline, tone: AppTheme.red400, title: 'Erreur', message: _error, action: PcButton('Réessayer', onPressed: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Profils de commission', style: AppFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      ..._configs.map(_configTile),
                      const SizedBox(height: 24),
                      Text('Simulateur de commission', style: AppFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      _simulatorSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _configTile(Map<String, dynamic> cfg) {
    final profile = cfg['profile']?.toString() ?? '';
    final percentage = (cfg['percentage'] is num) ? (cfg['percentage'] as num).toDouble() : 0.0;
    final minAmt = (cfg['minAmount'] is num) ? (cfg['minAmount'] as num).toDouble() : 0.0;
    final maxAmt = (cfg['maxAmount'] is num) ? (cfg['maxAmount'] as num).toDouble() : 0.0;
    final isActive = cfg['isActive'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PcCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.percent, size: 20, color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.toUpperCase(), style: AppFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text('$percentage% · Min: ${_fcfa(minAmt)} · Max: ${_fcfa(maxAmt)}',
                      style: AppFonts.manrope(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Switch(
              value: isActive,
              onChanged: (v) => _toggleActive(profile, isActive),
              activeColor: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _simulatorSection() {
    return PcCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant de la livraison (FCFA)'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: _simulate, child: const Text('Simuler')),
            ],
          ),
          if (_simulation.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...List.generate(_simulation.length, (i) {
              final s = _simulation[i];
              final profile = s['profile']?.toString() ?? '';
              final commission = (s['commission'] is num) ? (s['commission'] as num).toDouble() : 0.0;
              final percentage = (s['percentage'] is num) ? (s['percentage'] as num).toDouble() : 0.0;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.teal50, borderRadius: BorderRadius.circular(6)),
                      child: Text(profile, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.teal700)),
                    ),
                    const SizedBox(width: 8),
                    Text('$percentage%', style: AppTheme.mono(fontSize: 12, color: AppTheme.textSecondary)),
                    const Spacer(),
                    Text(_fcfa(commission), style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.amber500)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
