// mobile/lib/screens/auth/register_client_screen.dart

// ignore_for_file: unused_field, deprecated_member_use, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/custom_text_field.dart';
import 'otp_verification_screen.dart';

class RegisterClientScreen extends ConsumerStatefulWidget {
  const RegisterClientScreen({super.key});

  @override
  ConsumerState<RegisterClientScreen> createState() => _RegisterClientScreenState();
}

class _RegisterClientScreenState extends ConsumerState<RegisterClientScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  // Liste pour les régions/villes
  List<String> _regions = [];
  List<String> _cities = [];
  final Map<String, List<String>> _citiesByRegion = {};
  String? _selectedRegion;
  String? _selectedCity;
  bool _isLoadingLocations = false;

  // Préfixe téléphone
  String _selectedCountryCode = '+221';
  final List<Map<String, String>> _countryCodes = [
    {'code': '+221', 'flag': '🇸🇳', 'name': 'Sénégal'},
    {'code': '+223', 'flag': '🇲🇱', 'name': 'Mali'},
    {'code': '+224', 'flag': '🇬🇳', 'name': 'Guinée'},
    {'code': '+222', 'flag': '🇲🇷', 'name': 'Mauritanie'},
    {'code': '+225', 'flag': '🇨🇮', 'name': 'Côte d\'Ivoire'},
    {'code': '+226', 'flag': '🇧🇫', 'name': 'Burkina Faso'},
    {'code': '+227', 'flag': '🇳🇪', 'name': 'Niger'},
    {'code': '+228', 'flag': '🇹🇬', 'name': 'Togo'},
    {'code': '+229', 'flag': '🇧🇯', 'name': 'Bénin'},
    {'code': '+220', 'flag': '🇬🇲', 'name': 'Gambie'},
    {'code': '+245', 'flag': '🇬🇼', 'name': 'Guinée-Bissau'},
    {'code': '+238', 'flag': '🇨🇻', 'name': 'Cap-Vert'},
    {'code': '+240', 'flag': '🇬🇶', 'name': 'Guinée équatoriale'},
    {'code': '+241', 'flag': '🇬🇦', 'name': 'Gabon'},
    {'code': '+242', 'flag': '🇨🇬', 'name': 'Congo'},
    {'code': '+243', 'flag': '🇨🇩', 'name': 'RDC'},
    {'code': '+244', 'flag': '🇦🇴', 'name': 'Angola'},
    {'code': '+33', 'flag': '🇫🇷', 'name': 'France'},
    {'code': '+1', 'flag': '🇺🇸', 'name': 'USA/Canada'},
  ];

  // Couleurs du thème
  static const Color primaryColor = Color(0xFF0B6E3A);
  static const Color secondaryColor = Color(0xFF0D8C46);
  static const Color backgroundColor = Color(0xFFF0F4F8);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);
  
  // ✅ NOUVELLES COULEURS BLEU ET BLANC
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color lightBlue = Color(0xFFEFF6FF);
  static const Color darkBlue = Color(0xFF1E40AF);

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() => _isLoadingLocations = true);
    try {
      final locations = await _apiService.getAllGarages();
      
      final regionsSet = <String>{};
      final citiesByRegionTemp = <String, Set<String>>{};
      
      for (var location in locations) {
        final region = location.region;
        final city = location.city;
        
        regionsSet.add(region);
        
        if (!citiesByRegionTemp.containsKey(region)) {
          citiesByRegionTemp[region] = {};
        }
        citiesByRegionTemp[region]!.add(city);
      }
      
      final citiesByRegionFinal = <String, List<String>>{};
      for (var entry in citiesByRegionTemp.entries) {
        citiesByRegionFinal[entry.key] = entry.value.toList()..sort();
      }
      
      setState(() {
        _regions = regionsSet.toList()..sort();
        _citiesByRegion.clear();
        _citiesByRegion.addAll(citiesByRegionFinal);
        _isLoadingLocations = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocations = false);
      _loadFallbackData();
    }
  }
  
  void _loadFallbackData() {
    final fallbackRegions = [
      'Dakar', 'Thiès', 'Saint-Louis', 'Ziguinchor', 'Kaolack',
      'Tambacounda', 'Kédougou', 'Kaffrine', 'Diourbel', 'Fatick',
      'Kolda', 'Louga', 'Matam', 'Sédhiou'
    ];
    
    final fallbackCitiesByRegion = {
      'Dakar': ['Dakar', 'Pikine', 'Guédiawaye', 'Rufisque', 'Bargny', 'Diamniadio'],
      'Thiès': ['Thiès', 'Mbour', 'Tivaouane', 'Saly'],
      'Saint-Louis': ['Saint-Louis', 'Richard Toll', 'Dagana'],
      'Ziguinchor': ['Ziguinchor', 'Bignona', 'Oussouye'],
      'Kaolack': ['Kaolack', 'Nioro du Rip'],
      'Tambacounda': ['Tambacounda', 'Bakel'],
      'Kédougou': ['Kédougou', 'Salémata'],
      'Kaffrine': ['Kaffrine', 'Malem Hodar'],
      'Diourbel': ['Diourbel', 'Bambey', 'Touba'],
      'Fatick': ['Fatick', 'Foundiougne', 'Sokone'],
      'Kolda': ['Kolda', 'Vélingara'],
      'Louga': ['Louga', 'Linguère'],
      'Matam': ['Matam', 'Kanel'],
      'Sédhiou': ['Sédhiou', 'Bounkiling'],
    };
    
    setState(() {
      _regions = fallbackRegions;
      _citiesByRegion.addAll(fallbackCitiesByRegion);
      _isLoadingLocations = false;
    });
  }

  void _onRegionChanged(String? region) {
    setState(() {
      _selectedRegion = region;
      _selectedCity = null;
      if (region != null && _citiesByRegion.containsKey(region)) {
        _cities = _citiesByRegion[region]!;
      } else {
        _cities = [];
      }
    });
  }

  String _getFullPhoneNumber() {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) return '';
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return '$_selectedCountryCode$cleanNumber';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Les mots de passe ne correspondent pas', Colors.red);
      return;
    }

    if (!_acceptTerms) {
      _showSnackBar('Vous devez accepter les conditions', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullPhoneNumber = _getFullPhoneNumber();
      
      final result = await ref.read(authProvider.notifier).register(
            email: _emailController.text.trim(),
            phone: fullPhoneNumber,
            fullName: _fullNameController.text.trim(),
            password: _passwordController.text,
            role: 'client',
            address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
            city: _selectedCity,
            region: _selectedRegion,
          );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success'] == true) {
          final userId = result['userId'];
          final email = _emailController.text.trim();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(
                userId: userId,
                identifier: email,
                isLogin: false,
              ),
            ),
            (route) => false,
          );
        } else {
          _showSnackBar(result['message'] ?? 'Erreur lors de l\'inscription', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Erreur: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryBlue),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 24, isWhite: false),
            const SizedBox(width: 8),
            const Text(
              'PRO COLIS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0.5,
        shadowColor: Colors.grey.shade200,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec logo BLEU
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryBlue, secondaryBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const AppLogo(size: 50, isWhite: true),
                    const SizedBox(height: 12),
                    const Text(
                      'CRÉER UN COMPTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rejoignez la communauté PRO COLIS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section Informations personnelles
              _buildSectionCard(
                title: 'Informations personnelles',
                icon: Icons.person,
                color: primaryBlue,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _fullNameController,
                      label: 'Nom complet *',
                      prefixIcon: Icons.person,
                      hint: 'Ex: Jean Dupont',
                      validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email *',
                      prefixIcon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      hint: 'Ex: jean.dupont@email.com',
                      validator: (v) => v == null || !v.contains('@') ? 'Email valide requis' : null,
                    ),
                    const SizedBox(height: 12),
                    // Téléphone avec code pays
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Téléphone *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCountryCode,
                                  isExpanded: false,
                                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  dropdownColor: Colors.white,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: textPrimary,
                                  ),
                                  items: _countryCodes.map((country) {
                                    return DropdownMenuItem(
                                      value: country['code'],
                                      child: Row(
                                        children: [
                                          Text(country['flag']!),
                                          const SizedBox(width: 4),
                                          Text(country['code']!),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCountryCode = value!;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _phoneController,
                                label: 'Numéro',
                                prefixIcon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                hint: '77 123 45 67',
                                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _addressController,
                      label: 'Adresse',
                      prefixIcon: Icons.location_on,
                      maxLines: 2,
                      hint: 'Ex: 123 Rue de la Paix',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section Localisation
              _buildSectionCard(
                title: 'Localisation',
                icon: Icons.map,
                color: primaryBlue,
                child: Column(
                  children: [
                    if (_isLoadingLocations)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                          ),
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedRegion,
                        hint: const Text('Sélectionnez votre région'),
                        decoration: _inputDecoration('Région', Icons.map),
                        items: _regions.map((region) => DropdownMenuItem(
                          value: region,
                          child: Text(region, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: _onRegionChanged,
                      ),
                      const SizedBox(height: 12),
                      if (_selectedRegion != null && _cities.isNotEmpty)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedCity,
                          hint: const Text('Sélectionnez votre ville'),
                          decoration: _inputDecoration('Ville', Icons.location_city),
                          items: _cities.map((city) => DropdownMenuItem(
                            value: city,
                            child: Text(city, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (value) => setState(() => _selectedCity = value),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section Sécurité
              _buildSectionCard(
                title: 'Sécurité',
                icon: Icons.lock,
                color: primaryBlue,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Mot de passe *',
                      prefixIcon: Icons.lock,
                      suffixIcon: _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      onSuffixPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      obscureText: _obscurePassword,
                      hint: 'Minimum 6 caractères',
                      validator: (v) => v == null || v.length < 6 ? 'Min 6 caractères' : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirmer mot de passe *',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      onSuffixPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      obscureText: _obscureConfirmPassword,
                      hint: 'Confirmez votre mot de passe',
                      validator: (v) => v == null || v.length < 6 ? 'Min 6 caractères' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Conditions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                      activeColor: primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          children: [
                            const TextSpan(text: "J'accepte les "),
                            TextSpan(
                              text: "conditions d'utilisation",
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: " et la "),
                            TextSpan(
                              text: "politique de confidentialité",
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bouton inscription - BLEU
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: primaryBlue.withValues(alpha: 0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Créer mon compte',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Lien connexion
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      children: [
                        const TextSpan(text: 'Déjà un compte ? '),
                        TextSpan(
                          text: 'Se connecter',
                          style: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}