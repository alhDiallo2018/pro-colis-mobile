// mobile/lib/screens/super-admin/admin_parametres_screen.dart
// Paramètres système pour Super Admin

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Paramètres système',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConfig,
          ),
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
                        padding: const EdgeInsets.all(20),
                        children: _configItems.map(_buildConfigField).toList(),
                      ),
                    ),
                    _buildSaveButton(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
          const SizedBox(height: 16),
          Text('Erreur: $_error',
              style: const TextStyle(color: AppTheme.slate500),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadConfig,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigField(Map<String, dynamic> item) {
    final key = item['key']?.toString() ?? '';
    final label = item['label']?.toString() ?? key;
    final type = item['type']?.toString() ?? 'string';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.slate200),
          boxShadow: AppTheme.softShadow(alpha: 0.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (key.isNotEmpty && key != label)
              Text(
                key,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.slate400,
                ),
              ),
            const SizedBox(height: 10),
            _buildFieldInput(item, key, type),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldInput(
      Map<String, dynamic> item, String key, String type) {
    switch (type) {
      case 'boolean':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Activé',
                style: TextStyle(color: AppTheme.slate600, fontSize: 14)),
            Switch(
              value: _formValues[key] == true,
              activeColor: AppTheme.teal500,
              onChanged: (val) {
                setState(() {
                  _formValues[key] = val;
                });
              },
            ),
          ],
        );

      case 'number':
        return TextField(
          controller: _controllers[key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          decoration: InputDecoration(
            hintText: 'Saisir une valeur numérique',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        );

      case 'string':
      default:
        return TextField(
          controller: _controllers[key],
          decoration: InputDecoration(
            hintText: 'Saisir une valeur',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        );
    }
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: const Border(top: BorderSide(color: AppTheme.slate200)),
        boxShadow: AppTheme.softShadow(alpha: 0.06),
      ),
      child: CustomButton(
        text: _isSaving ? 'Enregistrement...' : 'Enregistrer',
        isLoading: _isSaving,
        backgroundColor: AppTheme.teal500,
        onPressed: _isSaving ? null : _saveConfig,
      ),
    );
  }
}
