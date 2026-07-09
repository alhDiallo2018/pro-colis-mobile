// mobile/lib/screens/super-admin/admin_parametres_screen.dart
// Paramètres système pour Super Admin — refonte alignée sur le web ProColis.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

/// Définition d'un groupe de paramètres (carte) et de ses mots-clés.
class _ParamGroup {
  final String title;
  final IconData icon;
  final PcTone tone;
  final List<String> keywords;
  final List<Map<String, dynamic>> items = [];

  _ParamGroup(this.title, this.icon, this.tone, this.keywords);
}

class AdminParametresScreen extends ConsumerStatefulWidget {
  const AdminParametresScreen({super.key});

  @override
  ConsumerState<AdminParametresScreen> createState() =>
      _AdminParametresScreenState();
}

class _AdminParametresScreenState extends ConsumerState<AdminParametresScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _configItems = [];
  final Map<String, dynamic> _formValues = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.getAdminConfig();
      final List<dynamic> configList = [];
      if (result['config'] is List) {
        configList.addAll(result['config'] as List);
      } else if (result['data'] is List) {
        configList.addAll(result['data'] as List);
      }

      if (mounted) {
        // Dispose old controllers
        for (final c in _controllers.values) {
          c.dispose();
        }
        _controllers.clear();
        _formValues.clear();

        final items = configList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        for (final item in items) {
          final key = item['key']?.toString() ?? '';
          final value = item['value'];
          final type = item['type']?.toString() ?? 'string';

          _formValues[key] = value;

          if (type == 'string' || type == 'number') {
            _controllers[key] = TextEditingController(
              text: value?.toString() ?? '',
            );
          }
        }

        setState(() {
          _configItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
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
    for (final item in _configItems) {
      final key = item['key']?.toString() ?? '';
      final type = item['type']?.toString() ?? 'string';

      switch (type) {
        case 'boolean':
          result[key] = _formValues[key] ?? false;
          break;
        case 'number':
          final raw = _controllers[key]?.text.trim() ?? '';
          final parsed = num.tryParse(raw);
          result[key] = parsed ?? 0;
          break;
        case 'string':
        default:
          result[key] = _controllers[key]?.text.trim() ?? '';
          break;
      }
    }
    return result;
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      final config = _collectFormValues();
      final result = await _apiService.updateAdminConfig(config);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Configuration enregistrée avec succès'),
                backgroundColor: AppTheme.green600),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    result['message']?.toString() ?? 'Erreur lors de l\'enregistrement'),
                backgroundColor: AppTheme.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Répartit les paramètres dans des groupes thématiques (cartes).
  List<_ParamGroup> _buildGroups() {
    final tarifs = _ParamGroup(
      'Tarifs & commissions',
      Icons.payments_rounded,
      PcTone.amber,
      const [
        'tarif', 'prix', 'price', 'commission', 'montant', 'fee', 'frais',
        'taux', 'rate', 'seuil', 'cout', 'coût', 'wallet', 'solde', 'devise',
      ],
    );
    final notifs = _ParamGroup(
      'Notifications',
      Icons.notifications_rounded,
      PcTone.primary,
      const ['notif', 'email', 'mail', 'sms', 'push', 'alerte'],
    );
    final securite = _ParamGroup(
      'Sécurité',
      Icons.shield_rounded,
      PcTone.red,
      const [
        'secur', 'sécur', 'password', 'mot_de_passe', 'token', 'auth',
        'session', 'otp', '2fa', 'verif', 'vérif',
      ],
    );
    final general = _ParamGroup(
      'Général',
      Icons.tune_rounded,
      PcTone.neutral,
      const [],
    );

    // Groupes spécifiques testés avant le repli "Général".
    final specific = [tarifs, notifs, securite];

    for (final item in _configItems) {
      final key = item['key']?.toString() ?? '';
      final label = item['label']?.toString() ?? '';
      final hay = '$key $label'.toLowerCase();
      final match = specific.firstWhere(
        (g) => g.keywords.any(hay.contains),
        orElse: () => general,
      );
      match.items.add(item);
    }

    // Ordre d'affichage : Général en tête, puis les groupes spécifiques.
    return [general, ...specific].where((g) => g.items.isNotEmpty).toList();
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
          PcIconButton(
            Icons.refresh_rounded,
            tooltip: 'Recharger',
            onPressed: _loadConfig,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _configItems.isEmpty
                  ? _buildEmptyView()
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                            children: [
                              _buildIntro(),
                              const SizedBox(height: 18),
                              for (final group in _buildGroups()) ...[
                                _buildGroupCard(group),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                        _buildSaveButton(),
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
          child: const Icon(Icons.settings_rounded,
              size: 24, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configuration système',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Ajustez les paramètres de la plateforme puis enregistrez.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.slate500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupCard(_ParamGroup group) {
    return PcCard(
      padding: const EdgeInsets.all(18),
      shadow: AppTheme.shadowXs(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupHeader(group),
          const SizedBox(height: 16),
          for (int i = 0; i < group.items.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            _buildConfigField(group.items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupHeader(_ParamGroup group) {
    final chip = _toneColors(group.tone);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: chip.$1,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(group.icon, size: 19, color: chip.$2),
        ),
        const SizedBox(width: 10),
        Text(
          group.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const Spacer(),
        PcBadge('${group.items.length}', tone: group.tone),
      ],
    );
  }

  Widget _buildConfigField(Map<String, dynamic> item) {
    final key = item['key']?.toString() ?? '';
    final label = item['label']?.toString() ?? _prettyKey(key);
    final type = item['type']?.toString() ?? 'string';

    if (type == 'boolean') {
      return _buildBooleanField(key, label);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate700,
          ),
        ),
        const SizedBox(height: 8),
        _buildTextInput(key, type),
      ],
    );
  }

  Widget _buildBooleanField(String key, String label) {
    final active = _formValues[key] == true;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: active,
          onChanged: (val) => setState(() => _formValues[key] = val),
          activeThumbColor: Colors.white,
          activeTrackColor: AppTheme.primary,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: AppTheme.slate300,
          trackOutlineColor:
              const WidgetStatePropertyAll(Colors.transparent),
        ),
      ],
    );
  }

  Widget _buildTextInput(String key, String type) {
    final isNumber = type == 'number';
    return TextField(
      controller: _controllers[key],
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : null,
      style: isNumber
          ? AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w600)
          : GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
      decoration: InputDecoration(
        hintText:
            isNumber ? 'Saisir une valeur numérique' : 'Saisir une valeur',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildEmptyView() {
    return PcEmptyState(
      icon: Icons.tune_rounded,
      title: 'Aucun paramètre',
      message:
          'La configuration système ne contient aucun paramètre modifiable.',
      action: PcButton(
        'Réessayer',
        variant: PcButtonVariant.secondary,
        icon: Icons.refresh_rounded,
        onPressed: _loadConfig,
      ),
    );
  }

  Widget _buildErrorView() {
    return PcEmptyState(
      icon: Icons.error_outline_rounded,
      tone: PcTone.red,
      title: 'Erreur de chargement',
      message: _error,
      action: PcButton(
        'Réessayer',
        icon: Icons.refresh_rounded,
        onPressed: _loadConfig,
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: const Border(top: BorderSide(color: AppTheme.slate200)),
        boxShadow: AppTheme.softShadow(alpha: 0.06),
      ),
      child: PcButton(
        _isSaving ? 'Enregistrement...' : 'Enregistrer',
        icon: Icons.save_rounded,
        block: true,
        loading: _isSaving,
        onPressed: _isSaving ? null : _saveConfig,
      ),
    );
  }

  // ---- Helpers présentation -------------------------------------------------

  /// Convertit une clé technique en libellé lisible (fallback si pas de label).
  String _prettyKey(String key) {
    if (key.isEmpty) return key;
    final spaced = key
        .replaceAll(RegExp(r'[_-]'), ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .trim();
    if (spaced.isEmpty) return key;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// Couleurs (fond, texte) associées à un ton, pour les pastilles d'entête.
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
