// mobile/lib/screens/super-admin/admin_parametres_screen.dart
// Paramètres système pour Super Admin — sections dédiées alignées sur le web.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../../providers/public_config_provider.dart';
import '../../services/api_service.dart';
import '../../services/commission_service.dart';
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
  final List<String> options;
  final bool secret;

  const _ConfigField(
    this.key,
    this.label,
    this.type,
    this.defaultValue, {
    this.options = const [],
    this.secret = false,
  });
}

enum _ConfigFieldType { string, number, boolean, select }

const _sections = <_ConfigSection>[
  _ConfigSection('Tarification', Icons.payments_rounded, PcTone.amber, [
    _ConfigField(
        'pricing.baseFee', 'Frais de base (FCFA)', _ConfigFieldType.number, ''),
    _ConfigField('pricing.pricePerKg', 'Prix par kg (FCFA)',
        _ConfigFieldType.number, ''),
    _ConfigField('pricing.urgentFee', 'Frais urgence (FCFA)',
        _ConfigFieldType.number, ''),
    _ConfigField('pricing.insuranceFee', 'Frais assurance (FCFA)',
        _ConfigFieldType.number, ''),
  ]),
  _ConfigSection('Score & Réputation', Icons.stars_rounded, PcTone.primary, [
    _ConfigField('score.deliveryCompleted', 'Points par livraison réussie',
        _ConfigFieldType.number, '0'),
    _ConfigField('score.signupBonus', 'Points bonus inscription',
        _ConfigFieldType.number, '0'),
    _ConfigField('score.cfaPerPoint', 'Équivalent CFA par point (FCFA)',
        _ConfigFieldType.number, ''),
    _ConfigField('score.commitmentFee', 'Points de frais d’engagement',
        _ConfigFieldType.number, ''),
    _ConfigField('score.standardThreshold', 'Seuil niveau Standard (points)',
        _ConfigFieldType.number, ''),
    _ConfigField('score.premiumThreshold', 'Seuil niveau Premium (points)',
        _ConfigFieldType.number, ''),
    _ConfigField('score.eliteThreshold', 'Seuil niveau Elite (points)',
        _ConfigFieldType.number, ''),
  ]),
  _ConfigSection('Finances — Retraits', Icons.savings_rounded, PcTone.green, [
    _ConfigField('withdrawal.minAmount', 'Montant minimum de retrait (FCFA)',
        _ConfigFieldType.number, ''),
    _ConfigField('withdrawal.maxAmount', 'Montant maximum (0 = illimité)',
        _ConfigFieldType.number, '0'),
  ]),
  _ConfigSection('Finances — Commission', Icons.percent_rounded, PcTone.amber, [
    _ConfigField(
      'commission.insufficient_rule',
      'Règle si solde insuffisant',
      _ConfigFieldType.select,
      'block',
      options: ['block', 'warn', 'debt'],
    ),
  ]),
  _ConfigSection(
      'Finances — Déboursement', Icons.send_rounded, PcTone.primary, [
    _ConfigField(
      'disbursement.mode',
      'Mode de déboursement',
      _ConfigFieldType.select,
      'manual',
      options: ['manual', 'auto'],
    ),
  ]),
  _ConfigSection('Uploads', Icons.cloud_upload_rounded, PcTone.green, [
    _ConfigField('uploads.maxPhotoMb', 'Taille max photo (Mo)',
        _ConfigFieldType.number, ''),
  ]),
  _ConfigSection('Maintenance', Icons.engineering_rounded, PcTone.red, [
    _ConfigField('maintenance.enabled', 'Mode maintenance',
        _ConfigFieldType.boolean, 'false'),
  ]),
  _ConfigSection('Support & Aide', Icons.support_agent_rounded, PcTone.green, [
    _ConfigField(
        'support.phone', 'Téléphone commercial', _ConfigFieldType.string, ''),
    _ConfigField(
        'support.email', 'Email commercial', _ConfigFieldType.string, ''),
    _ConfigField('support.technicalPhone', 'Téléphone technique',
        _ConfigFieldType.string, ''),
    _ConfigField('support.technicalEmail', 'Email technique',
        _ConfigFieldType.string, ''),
    _ConfigField('support.responseTime', 'Délai de réponse (ex: 24h)',
        _ConfigFieldType.string, ''),
    _ConfigField('support.availability', 'Disponibilité (ex: 7j/7)',
        _ConfigFieldType.string, ''),
  ]),
  _ConfigSection('Informations légales', Icons.gavel_rounded, PcTone.primary, [
    _ConfigField(
        'legal.companyName', 'Raison sociale', _ConfigFieldType.string, ''),
    _ConfigField(
        'legal.address', 'Adresse du siège', _ConfigFieldType.string, ''),
    _ConfigField('legal.registrationNumber', 'Numéro d\'immatriculation',
        _ConfigFieldType.string, ''),
    _ConfigField('legal.cdpAuthorization', 'Numéro d\'autorisation CDP',
        _ConfigFieldType.string, ''),
    _ConfigField('legal.privacyEmail', 'Email contact protection des données',
        _ConfigFieldType.string, ''),
    _ConfigField('legal.publisherName', 'Directeur de la publication',
        _ConfigFieldType.string, ''),
    _ConfigField('legal.hostName', 'Hébergeur de la plateforme',
        _ConfigFieldType.string, ''),
    _ConfigField('legal.directorName', 'Directeur Général (nom)',
        _ConfigFieldType.string, ''),
    _ConfigField('legal.directorEmail', 'Directeur Général (email)',
        _ConfigFieldType.string, ''),
    _ConfigField('legal.technicalDirectorName', 'Directeur Technique (nom)',
        _ConfigFieldType.string, ''),
    _ConfigField('legal.technicalDirectorEmail', 'Directeur Technique (email)',
        _ConfigFieldType.string, ''),
  ]),
  _ConfigSection(
      'PayDunya', Icons.account_balance_wallet_rounded, PcTone.primary, [
    _ConfigField('paydunya.masterKey', 'Clé principale (Master Key)',
        _ConfigFieldType.string, '',
        secret: true),
    _ConfigField('paydunya.privateKey', 'Clé privée (Private Key)',
        _ConfigFieldType.string, '',
        secret: true),
    _ConfigField('paydunya.publicKey', 'Clé publique (Public Key)',
        _ConfigFieldType.string, '',
        secret: true),
    _ConfigField('paydunya.token', 'Token', _ConfigFieldType.string, '',
        secret: true),
    _ConfigField('paydunya.mode', 'Mode', _ConfigFieldType.select, 'test',
        options: ['test', 'live']),
    _ConfigField('paydunya.disburse.masterKey', 'Disburse — Master Key',
        _ConfigFieldType.string, '',
        secret: true),
    _ConfigField('paydunya.disburse.privateKey', 'Disburse — Private Key',
        _ConfigFieldType.string, '',
        secret: true),
    _ConfigField('paydunya.disburse.publicKey', 'Disburse — Public Key',
        _ConfigFieldType.string, '',
        secret: true),
    _ConfigField('paydunya.disburse.token', 'Disburse — Token',
        _ConfigFieldType.string, '',
        secret: true),
    _ConfigField('paydunya.disburse.mode', 'Disburse — Mode',
        _ConfigFieldType.select, 'test',
        options: ['test', 'live']),
  ]),
];

// ✅ Correction : ConsumerStatefulWidget au lieu de StatefulWidget
class AdminParametresScreen extends ConsumerStatefulWidget {
  const AdminParametresScreen({super.key});

  @override
  ConsumerState<AdminParametresScreen> createState() =>
      _AdminParametresScreenState();
}

// ✅ Correction : ConsumerState au lieu de State
class _AdminParametresScreenState extends ConsumerState<AdminParametresScreen> {
  final ApiService _apiService = ApiService();
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _boolValues = {};
  final Set<String> _loadedConfigKeys = {};
  final Set<String> _visibleSecrets = {};
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
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _saved = false;
    });
    try {
      final result = await _apiService.getAdminConfig();
      if (result['success'] == false) {
        throw StateError(
          result['message']?.toString() ??
              'La configuration système n’a pas pu être chargée.',
        );
      }
      final Map<String, dynamic> apiConfig = {};

      final raw = result['config'] ?? result['data'];
      if (raw is List) {
        for (final item in raw) {
          final m = Map<String, dynamic>.from(item as Map);
          apiConfig[m['key']?.toString() ?? ''] = m['value'];
        }
      } else if (raw is Map) {
        raw.forEach((k, v) {
          apiConfig[k.toString()] = v;
        });
      }

      if (mounted) {
        for (final c in _textControllers.values) {
          c.dispose();
        }
        _textControllers.clear();
        _boolValues.clear();
        _loadedConfigKeys
          ..clear()
          ..addAll(apiConfig.keys);

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

        CommissionService.setInsufficientPolicy(
          apiConfig['commission.insufficient_rule']?.toString() ?? 'block',
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[AdminParametres] Échec chargement configuration: $e\n$stackTrace',
      );
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
            // Une clé absente de l'API et laissée vide n'est pas remplacée par
            // zéro : le serveur reste l'unique source de valeur par défaut.
            if (raw.isEmpty && !_loadedConfigKeys.contains(field.key)) continue;
            final parsed = num.tryParse(raw);
            if (parsed == null) {
              throw FormatException(
                'Le champ « ${field.label} » doit contenir un nombre.',
              );
            }
            result[field.key] = parsed;
            break;
          case _ConfigFieldType.string:
          case _ConfigFieldType.select:
            final raw = _textControllers[field.key]?.text.trim() ?? '';
            // Les secrets ne sont jamais renvoyés par l'API. Un champ secret
            // vide signifie donc « conserver la valeur existante », et non
            // « écraser le secret par une chaîne vide ».
            if (field.secret && raw.isEmpty) continue;
            if (!_loadedConfigKeys.contains(field.key) &&
                raw == field.defaultValue) {
              continue;
            }
            result[field.key] = raw;
            break;
        }
      }
    }
    return result;
  }

  Future<void> _saveConfig() async {
    setState(() {
      _isSaving = true;
      _saved = false;
    });
    try {
      final config = _collectFormValues();
      if (config.isEmpty) {
        throw StateError('Aucune valeur à enregistrer.');
      }
      final result = await _apiService.updateAdminConfig(config);
      if (mounted) {
        if (result['success'] == true) {
          CommissionService.setInsufficientPolicy(
            config['commission.insufficient_rule']?.toString() ?? 'block',
          );
          // ✅ Correction : ref.read au lieu de context.read
          ref.read(publicConfigProvider.notifier).load();
          setState(() => _saved = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ??
                  'Erreur lors de l\'enregistrement'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[AdminParametres] Échec enregistrement configuration: $e\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
          ),
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.teal50,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child:
              Icon(Icons.settings_rounded, size: 24, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configuration système',
                  style: AppFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 3),
              Text('Ajustez les paramètres de la plateforme puis enregistrez.',
                  style: AppFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.slate500,
                      height: 1.4)),
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(section.icon, size: 19, color: fg),
              ),
              const SizedBox(width: 10),
              Text(section.title,
                  style: AppFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
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
                style: AppFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
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
    if (field.type == _ConfigFieldType.select) {
      final controller = _textControllers[field.key]!;
      final current = field.options.contains(controller.text)
          ? controller.text
          : field.defaultValue;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label,
              style: AppFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: current,
            items: field.options
                .map((option) => DropdownMenuItem(
                      value: option,
                      child: Text(option),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) controller.text = value;
            },
          ),
        ],
      );
    }

    final secretVisible = _visibleSecrets.contains(field.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label,
            style: AppFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate700)),
        const SizedBox(height: 8),
        TextField(
          controller: _textControllers[field.key],
          obscureText: field.secret && !secretVisible,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: isNumber
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
              : null,
          style: isNumber
              ? AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w600)
              : AppFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText:
                isNumber ? 'Saisir une valeur numérique' : 'Saisir une valeur',
            suffixIcon: field.secret
                ? IconButton(
                    tooltip: secretVisible ? 'Masquer' : 'Afficher',
                    icon: Icon(secretVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () {
                      setState(() {
                        if (secretVisible) {
                          _visibleSecrets.remove(field.key);
                        } else {
                          _visibleSecrets.add(field.key);
                        }
                      });
                    },
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        border: Border(top: BorderSide(color: AppTheme.slate200)),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
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
      action: PcButton('Réessayer',
          icon: Icons.refresh_rounded, onPressed: _loadConfig),
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
