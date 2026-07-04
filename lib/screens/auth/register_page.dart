// mobile/lib/screens/auth/register_page.dart
// Formulaire d'inscription simplifié aligné sur l'app Web

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../dashboard/dashboard_screen.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  String _role = 'client';
  final _fullNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _accepted = false;
  bool _isLoading = false;

  String _selectedCountryCode = '+221';
  final List<Map<String, String>> _countryCodes = [
    {'code': '+221', 'flag': '🇸🇳', 'name': 'Sénégal'},
    {'code': '+223', 'flag': '🇲🇱', 'name': 'Mali'},
    {'code': '+224', 'flag': '🇬🇳', 'name': 'Guinée'},
    {'code': '+225', 'flag': '🇨🇮', 'name': 'Côte d\'Ivoire'},
    {'code': '+226', 'flag': '🇧🇫', 'name': 'Burkina Faso'},
    {'code': '+229', 'flag': '🇧🇯', 'name': 'Bénin'},
    {'code': '+220', 'flag': '🇬🇲', 'name': 'Gambie'},
    {'code': '+33', 'flag': '🇫🇷', 'name': 'France'},
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool get _pinValid => RegExp(r'^\d{6}$').hasMatch(_pinController.text);
  bool get _canSubmit =>
      _fullNameController.text.trim().length >= 2 &&
      _phoneController.text.trim().length >= 8 &&
      _pinValid &&
      _accepted;

  String _getFullPhone() {
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    return '$_selectedCountryCode$phone';
  }

  Future<void> _register() async {
    if (!_canSubmit) return;

    setState(() => _isLoading = true);

    final result = await ref.read(authProvider.notifier).register(
          phone: _getFullPhone(),
          fullName: _fullNameController.text.trim(),
          pin: _pinController.text,
          role: _role,
          city: _cityController.text.trim().isNotEmpty
              ? _cityController.text.trim()
              : null,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Erreur inscription'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'PRO COLIS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0FA958), Color(0xFF018982), Color(0xFF0C6E7D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping,
                        size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Rejoignez le réseau Procolis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chauffeurs vérifiés, prix libres, suivi en temps réel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'Créer un compte',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Quelques informations et vous êtes prêt.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            // Rôle
            const Text(
              'Je veux…',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _RoleCard(
                    selected: _role == 'client',
                    icon: Icons.inventory_2,
                    label: 'Envoyer un colis',
                    onTap: () => setState(() => _role = 'client'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RoleCard(
                    selected: _role == 'driver',
                    icon: Icons.local_shipping,
                    label: 'Conduire',
                    onTap: () => setState(() => _role = 'driver'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Info personnelle
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _fullNameController,
                    label: 'Nom complet',
                    prefixIcon: Icons.badge,
                    hint: 'Ex : Aïcha Mballa',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _cityController,
                    label: 'Ville',
                    prefixIcon: Icons.location_on,
                    hint: 'Douala',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Téléphone + PIN
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Téléphone',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.withAlpha(60)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCountryCode,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                icon: const Icon(Icons.arrow_drop_down,
                                    size: 18),
                                style: const TextStyle(
                                    fontSize: 13, color: AppTheme.textPrimary),
                                items: _countryCodes.map((c) {
                                  return DropdownMenuItem(
                                    value: c['code'],
                                    child: Text('${c['flag']} ${c['code']}'),
                                  );
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedCountryCode = v!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '77 123 45 67',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Colors.grey.withAlpha(60)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: CustomTextField(
                    controller: _pinController,
                    label: 'Code PIN',
                    prefixIcon: Icons.lock,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    hint: '6 chiffres',
                    onChanged: (value) {
                      if (value != null) {
                        final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
                        if (cleaned != value) {
                          _pinController.text = cleaned;
                          _pinController.selection = TextSelection.fromPosition(
                            TextPosition(offset: cleaned.length),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Conditions
            Row(
              children: [
                Checkbox(
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                  activeColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _accepted = !_accepted),
                    child: Text(
                      'J\'accepte les conditions de transport et la politique de confidentialité.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            CustomButton(
              text: 'Créer mon compte',
              onPressed: _canSubmit ? _register : null,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 20),

            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary),
                    children: [
                      const TextSpan(text: 'Déjà un compte ? '),
                      TextSpan(
                        text: 'Se connecter',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryBlue.withAlpha(20)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : Colors.grey.withAlpha(50),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 32,
                color: selected ? AppTheme.primaryBlue : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.primaryBlue : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
