// mobile/lib/screens/auth/register_page.dart
// Formulaire d'inscription — restylé sur le design system ProColis.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:procolis/theme/fonts.dart';

import '../../data/country_data.dart';
import '../../providers/auth_provider.dart';
import '../../services/places_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/location_autocomplete.dart';
import '../../widgets/pc_components.dart';

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
    _selectedCountryCode = _selectedCountry?.dialCode ?? '+221';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _countrySearchController.dispose();
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
      GoRouter.of(context).go('/dashboard');
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
                  style: AppFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Quelques informations et vous êtes prêt.',
                  style: AppFonts.manrope(
                    color: Colors.white.withOpacity( 0.88),
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
                    style: AppFonts.plusJakartaSans(
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
                  LocationAutocomplete(
                    controller: _cityController,
                    label: 'Ville',
                    prefixIcon: Icons.location_on_outlined,
                    hint: 'Rechercher votre ville...',
                    googleApiKey: PlacesService.googleApiKey,
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
                              style: AppFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.slate600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _PhoneField(
                              controller: _phoneController,
                              countryCode: _selectedCountryCode,
                              selectedCountry: _selectedCountry,
                              onCountryChanged: (c) {
                                setState(() {
                                  _selectedCountryCode = c.dialCode;
                                  _selectedCountry = c;
                                });
                              },
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
                              style: AppFonts.manrope(
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
                          style: AppFonts.manrope(
                            fontSize: 14,
                            color: AppTheme.slate500,
                          ),
                          children: [
                            const TextSpan(text: 'Déjà un compte ? '),
                            TextSpan(
                              text: 'Se connecter',
                              style: AppFonts.plusJakartaSans(
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
      color: Colors.white.withOpacity( 0.16),
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
                style: AppFonts.plusJakartaSans(
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
// Champ téléphone avec préfixe pays (searchable)
// ============================================================

class _PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String countryCode;
  final CountryInfo? selectedCountry;
  final ValueChanged<CountryInfo> onCountryChanged;
  final VoidCallback onChanged;

  const _PhoneField({
    required this.controller,
    required this.countryCode,
    required this.selectedCountry,
    required this.onCountryChanged,
    required this.onChanged,
  });

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = searchCountries(_searchQuery);
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
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un pays...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setModalState(() => _searchQuery = '');
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
                        onChanged: (v) => setModalState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final country = filtered[index];
                          final isSelected = widget.selectedCountry?.code == country.code;
                          return ListTile(
                            leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                            title: Text(country.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Text(country.dialCode, style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slate600)),
                            selected: isSelected,
                            selectedTileColor: AppTheme.teal50,
                            onTap: () {
                              widget.onCountryChanged(country);
                              _searchQuery = '';
                              _searchController.clear();
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
    return Row(
      children: [
        GestureDetector(
          onTap: _showPicker,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 6),
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
                  widget.selectedCountry?.flag ?? '🇸🇳',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.countryCode,
                  style: AppTheme.mono(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.slate500),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            keyboardType: TextInputType.phone,
            onChanged: (_) => widget.onChanged(),
            style: AppTheme.mono(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '77 123 45 67',
              filled: true,
              fillColor: AppTheme.cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
