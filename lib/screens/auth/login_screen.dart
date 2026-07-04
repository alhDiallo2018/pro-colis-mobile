// mobile/lib/screens/auth/login_screen.dart
// Écran de connexion simplifié - PIN direct (aligné Web)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../dashboard/dashboard_screen.dart';
import 'register_page.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _rememberMe = true;

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
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('saved_phone');
    final savedCountryCode = prefs.getString('saved_country_code');
    final rememberMe = prefs.getBool('remember_me') ?? true;
    if (mounted) {
      setState(() {
        _rememberMe = rememberMe;
        if (savedCountryCode != null) _selectedCountryCode = savedCountryCode;
        if (rememberMe && savedPhone != null && savedPhone.isNotEmpty) {
          _phoneController.text = savedPhone;
        }
      });
    }
  }

  Future<void> _savePhoneNumber(String phoneNumber) async {
    if (!_rememberMe) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_phone', phoneNumber);
    await prefs.setString('saved_country_code', _selectedCountryCode);
    await prefs.setBool('remember_me', _rememberMe);
  }

  String _getFullPhoneNumber() {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) return '';
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return '$_selectedCountryCode$cleanNumber';
  }

  Future<void> _loginWithPin() async {
    final phoneNumber = _getFullPhoneNumber();
    final pin = _pinController.text.trim();

    if (phoneNumber.isEmpty) {
      _showSnack('Veuillez entrer votre numéro de téléphone',
          AppTheme.warningColor);
      return;
    }
    if (pin.isEmpty || pin.length != 6) {
      _showSnack('Veuillez entrer un code PIN valide (6 chiffres)',
          AppTheme.warningColor);
      return;
    }

    setState(() => _isLoading = true);

    final result = await ref.read(authProvider.notifier).loginWithPin(
          pin,
          phoneNumber,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      _showSnack(
          result['message']?.toString() ?? 'Identifiant ou PIN incorrect',
          AppTheme.errorColor);
      _pinController.clear();
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 28),
            const SizedBox(width: 10),
            const Text(
              'PRO COLIS',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppTheme.textPrimary),
            ),
          ],
        ),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero
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
                        size: 46, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Pilotez vos colis\ndepuis votre mobile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connectez-vous pour créer des colis, comparer les offres et suivre vos livraisons.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withAlpha(210), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'Connexion',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Entrez votre identifiant et votre code PIN.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            // Téléphone
            const Text(
              'Numéro de téléphone',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: Colors.grey.withAlpha(60)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCountryCode,
                      isExpanded: false,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary),
                      items: _countryCodes.map((c) {
                        return DropdownMenuItem(
                          value: c['code'],
                          child: Text('${c['flag']} ${c['code']}',
                              style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCountryCode = value);
                          _savePhoneNumber(_phoneController.text.trim());
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomTextField(
                    controller: _phoneController,
                    label: 'Numéro de téléphone',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    onChanged: (value) {
                      if (value != null) _savePhoneNumber(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // PIN
            CustomTextField(
              controller: _pinController,
              label: 'Code PIN (6 chiffres)',
              prefixIcon: Icons.lock,
              suffixIcon: _obscurePin
                  ? Icons.visibility_off
                  : Icons.visibility,
              onSuffixPressed: () =>
                  setState(() => _obscurePin = !_obscurePin),
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 8),

            // Remember me
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (value) async {
                    setState(() => _rememberMe = value ?? false);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('remember_me', _rememberMe);
                    if (!_rememberMe) {
                      await prefs.remove('saved_phone');
                    }
                  },
                  activeColor: AppTheme.primaryBlue,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                Text(
                  'Se souvenir de mon numéro',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            CustomButton(
              text: 'Se connecter',
              onPressed: _loginWithPin,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 24),

            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RegisterPage()),
                  );
                },
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary),
                    children: [
                      const TextSpan(text: 'Pas encore de compte ? '),
                      TextSpan(
                        text: 'S\'inscrire',
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
