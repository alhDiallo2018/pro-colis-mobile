// mobile/lib/screens/auth/login_screen.dart
// Écran de connexion — restyle ProColis design system (PIN direct, aligné Web).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/country_data.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/pc_components.dart';
import '../dashboard/dashboard_screen.dart';
import 'register_page.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinController = TextEditingController();
  final _identifierController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _rememberMe = true;

  CountryInfo? _selectedCountry;
  String _countrySearchQuery = '';
  final _countrySearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCountry = allCountries.firstWhere(
      (c) => c.dialCode == '+221',
      orElse: () => allCountries.first,
    );
    _loadSavedData();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _identifierController.dispose();
    _countrySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIdentifier = prefs.getString('saved_identifier');
    final savedCountryCode = prefs.getString('saved_country_code');
    final rememberMe = prefs.getBool('remember_me') ?? true;
    if (mounted) {
      setState(() {
        _rememberMe = rememberMe;
        if (savedCountryCode != null) {
          _selectedCountry = allCountries.firstWhere(
            (c) => c.dialCode == savedCountryCode,
            orElse: () => _selectedCountry ?? allCountries.first,
          );
        }
        if (rememberMe && savedIdentifier != null && savedIdentifier.isNotEmpty) {
          _identifierController.text = savedIdentifier;
        }
      });
    }
  }

  Future<void> _saveIdentifier(String identifier) async {
    if (!_rememberMe) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_identifier', identifier);
    if (_selectedCountry != null) {
      await prefs.setString('saved_country_code', _selectedCountry!.dialCode);
    }
    await prefs.setBool('remember_me', _rememberMe);
  }

  String _getFullPhoneNumber() {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) return '';
    if (identifier.contains('@')) return identifier;
    final cleanNumber = identifier.replaceAll(RegExp(r'[^0-9]'), '');
    final dialCode = _selectedCountry?.dialCode ?? '+221';
    return '$dialCode$cleanNumber';
  }

  Future<void> _loginWithPin() async {
    if (_isLoading) return;
    final identifier = _getFullPhoneNumber();
    final pin = _pinController.text.trim();

    if (identifier.isEmpty) {
      _showSnack('Veuillez entrer votre email ou numéro de téléphone',
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
          identifier,
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

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = searchCountries(_countrySearchQuery);
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _countrySearchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un pays...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _countrySearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _countrySearchController.clear();
                                    setModalState(() => _countrySearchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.slate100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) {
                          setModalState(() => _countrySearchQuery = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final country = filtered[index];
                          final isSelected = _selectedCountry?.code == country.code;
                          return ListTile(
                            leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                            title: Text(country.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Text(country.dialCode, style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slate600)),
                            selected: isSelected,
                            selectedTileColor: AppTheme.teal50,
                            onTap: () {
                              setState(() => _selectedCountry = country);
                              _saveIdentifier(_identifierController.text.trim());
                              _countrySearchController.clear();
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AuthHero(topPadding: MediaQuery.of(context).padding.top),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connexion',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Entrez votre identifiant et votre code PIN.',
                    style: GoogleFonts.manrope(
                      fontSize: 14.5,
                      color: AppTheme.slate500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Identifiant (email ou téléphone)
                  _fieldLabel('Email ou téléphone'),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _showCountryPicker(),
                        child: Container(
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            border: Border.all(color: AppTheme.slate200),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCountry?.flag ?? '🇸🇳',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedCountry?.dialCode ?? '+221',
                                style: AppTheme.mono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down,
                                  size: 18, color: AppTheme.slate500),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          controller: _identifierController,
                          label: 'Email ou téléphone',
                          prefixIcon: Icons.alternate_email,
                          keyboardType: TextInputType.text,
                          style: AppTheme.mono(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary),
                          onChanged: (value) {
                            _saveIdentifier(value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PIN
                  _fieldLabel('Code PIN'),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _pinController,
                    label: 'Code PIN (6 chiffres)',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: _obscurePin
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    onSuffixPressed: () =>
                        setState(() => _obscurePin = !_obscurePin),
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _loginWithPin(),
                    onChanged: (value) {
                      // Connexion automatique dès que le PIN complet (6 chiffres) est saisi
                      if (value.trim().length == 6 && !_isLoading) {
                        FocusScope.of(context).unfocus();
                        _loginWithPin();
                      }
                    },
                    style: AppTheme.mono(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),

                  // Remember me
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) async {
                          setState(() => _rememberMe = value ?? false);
                          final prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setBool('remember_me', _rememberMe);
                          if (!_rememberMe) {
                            await prefs.remove('saved_identifier');
                          }
                        },
                        activeColor: AppTheme.primary,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusXs)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Se souvenir de mon identifiant',
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.slate500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  PcButton(
                    'Se connecter',
                    size: PcButtonSize.lg,
                    block: true,
                    loading: _isLoading,
                    iconTrailing: Icons.arrow_forward_rounded,
                    onPressed: _loginWithPin,
                  ),
                  const SizedBox(height: 26),

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
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: AppTheme.slate500,
                          ),
                          children: [
                            const TextSpan(text: 'Pas encore de compte ? '),
                            TextSpan(
                              text: 'Créer un compte',
                              style: GoogleFonts.manrope(
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
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.slate700,
        ),
      );
}

// ============================================================
// AuthHero — bandeau brand gradient (logo + wordmark + tagline)
// ============================================================

class _AuthHero extends StatelessWidget {
  final double topPadding;
  const _AuthHero({required this.topPadding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPadding + 36, 24, 40),
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity( 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const AppLogo(size: 30, isWhite: true),
              ),
              const SizedBox(width: 12),
              Text(
                'SENDPROCOLIS',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            'Pilotez vos colis\ndepuis votre mobile.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.18,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Connectez-vous pour créer des colis, comparer les offres et suivre vos livraisons.',
            style: GoogleFonts.manrope(
              color: Colors.white.withOpacity( 0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
