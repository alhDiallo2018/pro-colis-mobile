// mobile/lib/screens/super-admin/admin_parametres_screen.dart
// Paramètres système pour Super Admin — sections dédiées alignées sur le web.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

class _ConfigSection {
  final String title;
  final IconData icon;
  final PcTone tone;
  final List<_ConfigField> fields;

  const _ConfigSection(this.title, this.icon, this.tone, this.fields);
}

class _ConfigField {
  final String key;
  final String label;
  final _ConfigFieldType type;
  final String defaultValue;

  const _ConfigField(this.key, this.label, this.type, this.defaultValue);
}

enum _ConfigFieldType { string, number, boolean }

const _sections = <_ConfigSection>[
  _ConfigSection('Tarification', Icons.payments_rounded, PcTone.amber, [
    _ConfigField('pricing.baseFee', 'Frais de base (FCFA)', _ConfigFieldType.number, '1000'),
    _ConfigField('pricing.pricePerKg', 'Prix par kg (FCFA)', _ConfigFieldType.number, '500'),
    _ConfigField('pricing.urgentFee', 'Frais urgence (FCFA)', _ConfigFieldType.number, '1000'),
    _ConfigField('pricing.insuranceFee', 'Frais assurance (FCFA)', _ConfigFieldType.number, '1000'),
  ]),
  _ConfigSection('Score & Réputation', Icons.stars_rounded, PcTone.primary, [
    _ConfigField('score.deliveryCompleted', 'Points par livraison réussie', _ConfigFieldType.number, '50'),
    _ConfigField('score.signupBonus', 'Points bonus inscription', _ConfigFieldType.number, '100'),
  ]),
  _ConfigSection('Uploads', Icons.cloud_upload_rounded, PcTone.green, [
    _ConfigField('uploads.maxPhotoMb', 'Taille max photo (Mo)', _ConfigFieldType.number, '10'),
  ]),
  _ConfigSection('Maintenance', Icons.engineering_rounded, PcTone.red, [
    _ConfigField('maintenance.enabled', 'Mode maintenance', _ConfigFieldType.boolean, 'false'),
  ]),
  _ConfigSection('PayDunya', Icons.account_balance_wallet_rounded, PcTone.primary, [
    _ConfigField('paydunya.masterKey', 'Clé principale (Master Key)', _ConfigFieldType.string, ''),
    _ConfigField('paydunya.privateKey', 'Clé privée (Private Key)', _ConfigFieldType.string, ''),
    _ConfigField('paydunya.publicKey', 'Clé publique (Public Key)', _ConfigFieldType.string, ''),
    _ConfigField('paydunya.token', 'Token', _ConfigFieldType.string, ''),
    _ConfigField('paydunya.mode', 'Mode (test ou live)', _ConfigFieldType.string, 'test'),
  ]),
];

class AdminParametresScreen extends StatefulWidget {
  const AdminParametresScreen({super.key});

  @override
  State<AdminParametresScreen> createState() => _AdminParametresScreenState();
}

class _AdminParametresScreenState extends State<AdminParametresScreen> {
  final ApiService _apiService = ApiService();
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _boolValues = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() { _isLoading = true; _error = null; _saved = false; });
    try {
      final result = await _apiService.getAdminConfig();
      final Map<String, dynamic> apiConfig = {};

      final List<dynamic> configList = [];
      if (result['config'] is List) {
        configList.addAll(result['config'] as List);
      } else if (result['data'] is List) {
        configList.addAll(result['data'] as List);
      }
      for (final item in configList) {
        final m = Map<String, dynamic>.from(item as Map);
        apiConfig[m['key']?.toString() ?? ''] = m['value'];
      }

      if (mounted) {
        for (final c in _textControllers.values) { c.dispose(); }
        _textControllers.clear();
        _boolValues.clear();

        for (final section in _sections) {
          for (final field in section.fields) {
            final apiVal = apiConfig[field.key];
            if (field.type == _ConfigFieldType.boolean) {
              _boolValues[field.key] = apiVal == true;
            } else {
              final text = apiVal?.toString() ?? field.defaultValue;
              _textControllers[field.key] = TextEditingController(text: text);
            }
          }
        }

        setState(() { _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Map<String, dynamic> _collectFormValues() {
    final result = <String, dynamic>{};
    for (final section in _sections) {
      for (final field in section.fields) {
        switch (field.type) {
          case _ConfigFieldType.boolean:
            result[field.key] = _boolValues[field.key] ?? false;
            break;
          case _ConfigFieldType.number:
            final raw = _textControllers[field.key]?.text.trim() ?? '';
            final parsed = num.tryParse(raw);
            result[field.key] = parsed ?? 0;
            break;
          case _ConfigFieldType.string:
            result[field.key] = _textControllers[field.key]?.text.trim() ?? '';
            break;
        }
      }
    }
    return result;
  }

  Future<void> _saveConfig() async {
    setState(() { _isSaving = true; _saved = false; });
    try {
      final config = _collectFormValues();
      final result = await _apiService.updateAdminConfig(config);
      if (mounted) {
        if (result['success'] == true) {
          setState(() => _saved = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  result['message']?.toString() ?? 'Erreur lors de l\'enregistrement'),
              backgroundColor: AppTheme.error,
            ),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Paramètres système',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          PcIconButton(Icons.refresh_rounded,
              tooltip: 'Recharger', onPressed: _loadConfig),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                        children: [
                          _buildIntro(),
                          const SizedBox(height: 18),
                          for (final section in _sections) ...[
                            _buildSectionCard(section),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                    _buildSaveBar(),
                  ],
                ),
    );
  }

  Widget _buildIntro() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppTheme.teal50,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: const Icon(Icons.settings_rounded, size: 24, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configuration système',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 3),
              Text('Ajustez les paramètres de la plateforme puis enregistrez.',
                  style: GoogleFonts.manrope(
                      fontSize: 13, fontWeight: FontWeight.w500,
                      color: AppTheme.slate500, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(_ConfigSection section) {
    final (bg, fg) = _toneColors(section.tone);
    return PcCard(
      padding: const EdgeInsets.all(18),
      shadow: AppTheme.shadowXs(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(section.icon, size: 19, color: fg),
              ),
              const SizedBox(width: 10),
              Text(section.title,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              PcBadge('${section.fields.length}', tone: section.tone),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < section.fields.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            _buildField(section.fields[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildField(_ConfigField field) {
    if (field.type == _ConfigFieldType.boolean) {
      return Row(
        children: [
          Expanded(
            child: Text(field.label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5, fontWeight: FontWeight.w600,
                    color: AppTheme.slate700)),
          ),
          const SizedBox(width: 12),
          Switch(
            value: _boolValues[field.key] ?? false,
            onChanged: (val) => setState(() => _boolValues[field.key] = val),
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppTheme.slate300,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      );
    }

    final isNumber = field.type == _ConfigFieldType.number;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5, fontWeight: FontWeight.w600,
                color: AppTheme.slate700)),
        const SizedBox(height: 8),
        TextField(
          controller: _textControllers[field.key],
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: isNumber
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
              : null,
          style: isNumber
              ? AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w600)
              : GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: isNumber ? 'Saisir une valeur numérique' : 'Saisir une valeur',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: const Border(top: BorderSide(color: AppTheme.slate200)),
        boxShadow: AppTheme.softShadow(alpha: 0.06),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_saved)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('✓ Configuration enregistrée.',
                  style: TextStyle(
                      color: AppTheme.green600,
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          PcButton(
            _isSaving ? 'Enregistrement...' : 'Enregistrer',
            icon: Icons.save_rounded,
            block: true,
            loading: _isSaving,
            onPressed: _isSaving ? null : _saveConfig,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return PcEmptyState(
      icon: Icons.error_outline_rounded,
      tone: PcTone.red,
      title: 'Erreur de chargement',
      message: _error,
      action: PcButton('Réessayer', icon: Icons.refresh_rounded,
          onPressed: _loadConfig),
    );
  }

  (Color, Color) _toneColors(PcTone tone) {
    switch (tone) {
      case PcTone.primary:
        return (AppTheme.teal50, AppTheme.teal500);
      case PcTone.green:
        return (AppTheme.green50, AppTheme.green700);
      case PcTone.amber:
        return (AppTheme.amber50, AppTheme.amber600);
      case PcTone.red:
        return (AppTheme.red50, AppTheme.red500);
      case PcTone.neutral:
        return (AppTheme.slate100, AppTheme.slate500);
    }
  }
}
