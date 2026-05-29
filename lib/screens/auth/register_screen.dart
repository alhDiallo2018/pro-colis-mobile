import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'otp_verification_screen.dart';

class RegisterDriverScreen extends ConsumerStatefulWidget {
  const RegisterDriverScreen({super.key});

  @override
  ConsumerState<RegisterDriverScreen> createState() =>
      _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends ConsumerState<RegisterDriverScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  // ignore: unused_field
  final _garageIdController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehicleYearController = TextEditingController();

  // État
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  String? _selectedGarageId; // ✅ Ajouté pour stocker l'UUID sélectionné

  // Données statiques
  final List<String> _regions = [
    'Dakar',
    'Thiès',
    'Saint-Louis',
    'Louga',
    'Matam',
    'Tambacounda',
    'Kédougou',
    'Kaffrine',
    'Diourbel',
    'Fatick',
    'Kaolack',
    'Kolda',
    'Sédhiou',
    'Ziguinchor'
  ];

  // ✅ Utiliser des UUIDs STRING directement
  final Map<String, String> _garages = {
    'Garage Dakar Centre (Dakar)': 'd5053c30-b80c-478c-ba5b-5d5b38f62180',
    'Garage Thiès (Thiès)': 'b950c678-528e-44a8-9fbc-33afb31966b2',
    'Garage Saint-Louis (Saint-Louis)': 'd3e4b779-c966-4969-b28a-44ecf7f57147',
    'Garage Ziguinchor (Ziguinchor)': 'efcf0dd1-c9aa-4627-b25c-735690cc59b0',
    'Garage Kaolack (Kaolack)': 'b6be53c6-266b-4140-871a-e746dd2c0d74',
  };

  final List<String> _vehicleModels = [
    'Toyota HiAce',
    'Toyota Corolla',
    'Renault Logan',
    'Peugeot 301',
    'Hyundai H100',
    'Kia K2700',
    'Mitsubishi L300',
    'Nissan Caravan',
    'Ford Transit'
  ];

  final List<String> _vehicleColors = [
    'Blanc',
    'Noir',
    'Gris',
    'Bleu',
    'Rouge',
    'Vert',
    'Jaune',
    'Beige',
    'Marron'
  ];

  Future<void> _registerDriver() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Les mots de passe ne correspondent pas'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vous devez accepter les conditions'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🔵 Appel de la méthode register...');

      final result = await ref.read(authProvider.notifier).register(
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            fullName: _fullNameController.text.trim(),
            password: _passwordController.text,
            role: 'driver',
            address: _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : null,
            city: _cityController.text.trim().isNotEmpty
                ? _cityController.text.trim()
                : null,
            region: _regionController.text.trim().isNotEmpty
                ? _regionController.text.trim()
                : null,
            garageId: _selectedGarageId,
            vehiclePlate: _vehiclePlateController.text.trim().isNotEmpty
                ? _vehiclePlateController.text.trim().toUpperCase()
                : null,
            vehicleModel: _vehicleModelController.text.trim().isNotEmpty
                ? _vehicleModelController.text.trim()
                : null,
            vehicleColor: _vehicleColorController.text.isNotEmpty
                ? _vehicleColorController.text
                : null,
            vehicleYear: _vehicleYearController.text.isNotEmpty
                ? int.tryParse(_vehicleYearController.text)
                : null,
          );

      print('🟢 Résultat reçu: $result');
      print('   success: ${result['success']}');
      print('   userId: ${result['userId']}');

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success'] == true) {
          final userId = result['userId'];
          final email = _emailController.text.trim();

          print('✅ Redirection vers OTP avec userId: $userId');

          // ✅ Utiliser WidgetsBinding pour garantir la redirection
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
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
            }
          });
        } else {
          print('❌ Erreur: ${result['message']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(result['message'] ?? 'Erreur lors de l\'inscription'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('❌ Exception: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscription Chauffeur'),
        backgroundColor: const Color(0xFF0B6E3A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B6E3A).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_taxi,
                          size: 60, color: Color(0xFF0B6E3A)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Devenez chauffeur partenaire',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // full_name
              CustomTextField(
                controller: _fullNameController,
                label: 'Nom complet *',
                prefixIcon: Icons.person,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),

              // email
              CustomTextField(
                controller: _emailController,
                label: 'Email *',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || !v.contains('@')
                    ? 'Email valide requis'
                    : null,
              ),
              const SizedBox(height: 12),

              // phone
              CustomTextField(
                controller: _phoneController,
                label: 'Téléphone *',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),

              // region
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _regionController.text.isNotEmpty
                    ? _regionController.text
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Région',
                  prefixIcon: Icon(Icons.map),
                  border: OutlineInputBorder(),
                ),
                items: _regions
                    .map((region) => DropdownMenuItem(
                          value: region,
                          child: Text(region, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _regionController.text = value ?? ''),
              ),
              const SizedBox(height: 12),

              // city
              CustomTextField(
                controller: _cityController,
                label: 'Ville',
                prefixIcon: Icons.location_city,
              ),
              const SizedBox(height: 12),

              // address
              CustomTextField(
                controller: _addressController,
                label: 'Adresse',
                prefixIcon: Icons.location_on,
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // ✅ garage_id - Version CORRECTE avec UUIDs
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedGarageId,
                hint: const Text('Sélectionnez un garage'),
                decoration: const InputDecoration(
                  labelText: 'Garage d\'attache *',
                  prefixIcon: Icon(Icons.garage),
                  border: OutlineInputBorder(),
                ),
                items: _garages.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.value, // ✅ Value = UUID
                    child: Text(
                      entry.key, // ✅ Display = Nom du garage
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedGarageId = value; // ✅ Stocker l'UUID
                    });
                    print('✅ Garage sélectionné - UUID: $value');

                    // Trouver le nom du garage
                    final garageName = _garages.entries
                        .firstWhere(
                          (entry) => entry.value == value,
                          orElse: () => const MapEntry('', ''),
                        )
                        .key;
                    print('📍 Garage: $garageName');
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez sélectionner un garage';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // vehicle_plate
              CustomTextField(
                controller: _vehiclePlateController,
                label: 'Plaque d\'immatriculation',
                prefixIcon: Icons.confirmation_number,
                hint: 'Ex: DK-123-AB',
              ),
              const SizedBox(height: 12),

              // vehicle_model
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _vehicleModelController.text.isNotEmpty
                    ? _vehicleModelController.text
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Modèle du véhicule',
                  prefixIcon: Icon(Icons.car_repair),
                  border: OutlineInputBorder(),
                ),
                items: _vehicleModels
                    .map((model) => DropdownMenuItem(
                          value: model,
                          child: Text(model, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _vehicleModelController.text = value ?? ''),
              ),
              const SizedBox(height: 12),

              // vehicle_color
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _vehicleColorController.text.isNotEmpty
                    ? _vehicleColorController.text
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Couleur du véhicule',
                  prefixIcon: Icon(Icons.color_lens),
                  border: OutlineInputBorder(),
                ),
                items: _vehicleColors
                    .map((color) => DropdownMenuItem(
                          value: color,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _getColorValue(color),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(color,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _vehicleColorController.text = value ?? ''),
              ),
              const SizedBox(height: 12),

              // vehicle_year
              CustomTextField(
                controller: _vehicleYearController,
                label: 'Année du véhicule',
                prefixIcon: Icons.calendar_today,
                keyboardType: TextInputType.number,
                hint: 'Ex: 2022',
              ),
              const SizedBox(height: 12),

              // password
              CustomTextField(
                controller: _passwordController,
                label: 'Mot de passe *',
                prefixIcon: Icons.lock,
                suffixIcon:
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                onSuffixPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                obscureText: _obscurePassword,
                validator: (v) =>
                    v == null || v.length < 6 ? 'Min 6 caractères' : null,
              ),
              const SizedBox(height: 12),

              // confirmation password
              CustomTextField(
                controller: _confirmPasswordController,
                label: 'Confirmer mot de passe *',
                prefixIcon: Icons.lock_outline,
                suffixIcon: _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                onSuffixPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
                obscureText: _obscureConfirmPassword,
                validator: (v) =>
                    v == null || v.length < 6 ? 'Min 6 caractères' : null,
              ),

              const SizedBox(height: 24),

              // Conditions
              Row(
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) =>
                        setState(() => _acceptTerms = value ?? false),
                    activeColor: const Color(0xFF0B6E3A),
                  ),
                  Expanded(
                    child: Text(
                      "J'accepte les conditions d'utilisation",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bouton inscription
              CustomButton(
                text: 'Créer mon compte chauffeur',
                onPressed: _registerDriver,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 16),

              // Lien connexion
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Déjà un compte ? ',
                      style: TextStyle(color: Colors.grey[600])),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Se connecter',
                        style: TextStyle(color: Color(0xFF0B6E3A))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorValue(String colorName) {
    switch (colorName) {
      case 'Blanc':
        return Colors.white;
      case 'Noir':
        return Colors.black;
      case 'Gris':
        return Colors.grey;
      case 'Bleu':
        return Colors.blue;
      case 'Rouge':
        return Colors.red;
      case 'Vert':
        return Colors.green;
      case 'Jaune':
        return Colors.yellow;
      case 'Beige':
        return Colors.brown.shade50;
      case 'Marron':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
