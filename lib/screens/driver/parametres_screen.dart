// mobile/lib/screens/driver/parametres_screen.dart
// Paramètres chauffeur (véhicule + PIN) - aligné Web

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class DriverParametresScreen extends ConsumerStatefulWidget {
  const DriverParametresScreen({super.key});

  @override
  ConsumerState<DriverParametresScreen> createState() =>
      _DriverParametresScreenState();
}

class _DriverParametresScreenState
    extends ConsumerState<DriverParametresScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  // Vehicle fields
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  final _typeController = TextEditingController();
  final _capacityController = TextEditingController();
  Map<String, dynamic>? _vehicle;

  // PIN fields
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _showPinForm = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  @override
  void dispose() {
    _plateController.dispose();
    _modelController.dispose();
    _typeController.dispose();
    _capacityController.dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    setState(() => _isLoading = true);
    try {
      final vehicle = await _apiService.getDriverVehicle();
      if (mounted) {
        setState(() {
          _vehicle = vehicle != null ? Map<String, dynamic>.from(vehicle) : null;
          if (_vehicle != null) {
            _plateController.text = _vehicle!['plateNumber']?.toString() ?? '';
            _modelController.text = _vehicle!['model']?.toString() ?? '';
            _typeController.text = _vehicle!['type']?.toString() ?? '';
            _capacityController.text =
                _vehicle!['capacity']?.toString() ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveVehicle() async {
    setState(() => _isSaving = true);
    try {
      await _apiService.upsertVehicle({
        'plateNumber': _plateController.text.trim(),
        'model': _modelController.text.trim(),
        'type': _typeController.text.trim(),
        'capacity': int.tryParse(_capacityController.text.trim()) ?? 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Véhicule enregistré'),
              backgroundColor: AppTheme.green600),
        );
        await _loadVehicle();
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

  Future<void> _changePin() async {
    if (_newPinController.text != _confirmPinController.text) {
      _showError('Les PIN ne correspondent pas');
      return;
    }
    if (_newPinController.text.length != 6) {
      _showError('Le PIN doit faire 6 chiffres');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = await ref.read(authProvider.notifier).changePin(
            _currentPinController.text,
            _newPinController.text,
          );
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _showPinForm = false;
            _currentPinController.clear();
            _newPinController.clear();
            _confirmPinController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('PIN modifié avec succès'),
                backgroundColor: AppTheme.green600),
          );
        } else {
          _showError(result['message']?.toString() ?? 'Erreur');
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Paramètres',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Vehicle section
                _sectionHeader('Véhicule', Icons.directions_car),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      _inputField(_plateController, 'Plaque d\'immatriculation',
                          Icons.confirmation_number, 'AB-123-CD'),
                      const SizedBox(height: 14),
                      _inputField(_modelController, 'Modèle', Icons.car_repair,
                          'Toyota HiAce'),
                      const SizedBox(height: 14),
                      _inputField(_typeController, 'Type de véhicule',
                          Icons.category, 'Minibus'),
                      const SizedBox(height: 14),
                      _inputField(_capacityController, 'Capacité (kg)',
                          Icons.scale, '1500',
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveVehicle,
                          icon: const Icon(Icons.save, size: 18),
                          label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // PIN section
                _sectionHeader('Sécurité', Icons.lock),
                const SizedBox(height: 12),
                if (!_showPinForm)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.teal50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.lock_outline,
                              color: AppTheme.teal600, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Code PIN',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                              Text('Modifier votre code de connexion',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.slate500)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _showPinForm = true),
                          child: const Text('Modifier'),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        TextField(
                          controller: _currentPinController,
                          decoration: _pinDecoration('PIN actuel'),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          obscureText: true,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _newPinController,
                          decoration: _pinDecoration('Nouveau PIN'),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          obscureText: true,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _confirmPinController,
                          decoration: _pinDecoration('Confirmer le PIN'),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(
                                    () => _showPinForm = false),
                                child: const Text('Annuler'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _changePin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(_isSaving
                                    ? 'Modification...'
                                    : 'Modifier'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 28),

                // Info section
                _sectionHeader('À propos', Icons.info_outline),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      _infoRow('Version', '1.0.0'),
                      const Divider(height: 24),
                      _infoRow('Application', 'PRO COLIS'),
                      const Divider(height: 24),
                      _infoRow('API', ApiService.baseUrl),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.slate200),
    );
  }

  Widget _inputField(
      TextEditingController controller, String label, IconData icon,
      String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  InputDecoration _pinDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      counterText: '',
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppTheme.slate500, fontSize: 14)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontSize: 14)),
      ],
    );
  }
}
