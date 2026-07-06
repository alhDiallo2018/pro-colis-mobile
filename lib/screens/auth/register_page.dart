// mobile/lib/screens/auth/register_page.dart
// Formulaire d'inscription — restylé sur le design system ProColis.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/pc_components.dart';
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bandeau brand
          PcGradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TranslucentBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(height: 18),
                Text(
                  'Créer un compte',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Quelques informations et vous êtes prêt.',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Corps
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rôle
                  Text(
                    'Je suis…',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleTile(
                          selected: _role == 'client',
                          iconSelected: Icons.inventory_2,
                          iconIdle: Icons.inventory_2_outlined,
                          label: 'Expéditeur',
                          onTap: () => setState(() => _role = 'client'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoleTile(
                          selected: _role == 'driver',
                          iconSelected: Icons.local_shipping,
                          iconIdle: Icons.local_shipping_outlined,
                          label: 'Chauffeur',
                          onTap: () => setState(() => _role = 'driver'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Nom
                  CustomTextField(
                    controller: _fullNameController,
                    label: 'Nom complet',
                    prefixIcon: Icons.badge_outlined,
                    hint: 'Ex : Aïcha Mballa',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Ville
                  CustomTextField(
                    controller: _cityController,
                    label: 'Ville',
                    prefixIcon: Icons.location_on_outlined,
                    hint: 'Douala',
                  ),
                  const SizedBox(height: 16),

                  // Téléphone (préfixe pays) + PIN
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Téléphone',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.slate600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _PhoneField(
                              controller: _phoneController,
                              countryCode: _selectedCountryCode,
                              countryCodes: _countryCodes,
                              onCountryChanged: (v) =>
                                  setState(() => _selectedCountryCode = v),
                              onChanged: () => setState(() {}),
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
                          prefixIcon: Icons.lock_outline,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          hint: '6 chiffres',
                          style: AppTheme.mono(fontSize: 16),
                          onChanged: (value) {
                            final cleaned =
                                value.replaceAll(RegExp(r'[^0-9]'), '');
                            if (cleaned != value) {
                              _pinController.text = cleaned;
                              _pinController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(offset: cleaned.length),
                              );
                            }
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Conditions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _accepted,
                          onChanged: (v) =>
                              setState(() => _accepted = v ?? false),
                          activeColor: AppTheme.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusXs),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _accepted = !_accepted),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'J\'accepte les conditions de transport et la politique de confidentialité.',
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                height: 1.4,
                                color: AppTheme.slate500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Soumettre
                  PcButton(
                    'Créer mon compte',
                    icon: Icons.person_add_alt_1,
                    block: true,
                    size: PcButtonSize.lg,
                    loading: _isLoading,
                    onPressed: _canSubmit ? _register : null,
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: AppTheme.slate500,
                          ),
                          children: [
                            const TextSpan(text: 'Déjà un compte ? '),
                            TextSpan(
                              text: 'Se connecter',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

// ============================================================
// Bouton retour translucide (sur bandeau brand)
// ============================================================

class _TranslucentBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TranslucentBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

// ============================================================
// Tuile de rôle sélectionnable
// ============================================================

class _RoleTile extends StatelessWidget {
  final bool selected;
  final IconData iconSelected;
  final IconData iconIdle;
  final String label;
  final VoidCallback onTap;

  const _RoleTile({
    required this.selected,
    required this.iconSelected,
    required this.iconIdle,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.teal50 : AppTheme.cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.slate200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                selected ? iconSelected : iconIdle,
                size: 30,
                color: selected ? AppTheme.primary : AppTheme.slate400,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppTheme.teal700 : AppTheme.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Champ téléphone avec préfixe pays
// ============================================================

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String countryCode;
  final List<Map<String, String>> countryCodes;
  final ValueChanged<String> onCountryChanged;
  final VoidCallback onChanged;

  const _PhoneField({
    required this.controller,
    required this.countryCode,
    required this.countryCodes,
    required this.onCountryChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            border: Border.all(color: AppTheme.slate200),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: countryCode,
              icon: const Icon(Icons.arrow_drop_down,
                  size: 18, color: AppTheme.slate500),
              style: AppTheme.mono(fontSize: 13, fontWeight: FontWeight.w600),
              items: countryCodes.map((c) {
                return DropdownMenuItem(
                  value: c['code'],
                  child: Text('${c['flag']} ${c['code']}'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) onCountryChanged(v);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            onChanged: (_) => onChanged(),
            style: AppTheme.mono(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '77 123 45 67',
              filled: true,
              fillColor: AppTheme.cardColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
