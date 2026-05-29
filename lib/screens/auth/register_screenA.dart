import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Informations personnelles
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  
  // Informations professionnelles (selon rôle)
  UserRole _selectedRole = UserRole.client;
  String? _selectedGarageId;
  final _vehiclePlateController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  
  // État
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // Liste des régions du Sénégal
  final List<String> _regions = [
    'Dakar', 'Thiès', 'Saint-Louis', 'Louga', 'Matam', 
    'Tambacounda', 'Kédougou', 'Kaffrine', 'Diourbel', 
    'Fatick', 'Kaolack', 'Kolda', 'Sédhiou', 'Ziguinchor'
  ];
  
  // Liste des villes par région (simplifiée)
  final Map<String, List<String>> _cities = {
    'Dakar': ['Dakar Plateau', 'Pikine', 'Guédiawaye', 'Rufisque', 'Bargny'],
    'Thiès': ['Thiès', 'Tivaouane', 'Mbour', 'Joal-Fadiouth'],
    'Saint-Louis': ['Saint-Louis', 'Dagana', 'Podor', 'Richard-Toll'],
    'Ziguinchor': ['Ziguinchor', 'Bignona', 'Oussouye'],
  };

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Les mots de passe ne correspondent pas'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    setState(() => _isLoading = true);
    
    // Appel de la méthode register avec les bons paramètres
    final result = await ref.read(authProvider.notifier).register(
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      fullName: _fullNameController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole.value,
      address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
      region: _regionController.text.trim().isNotEmpty ? _regionController.text.trim() : null,
      vehiclePlate: _vehiclePlateController.text.trim().isNotEmpty ? _vehiclePlateController.text.trim() : null,
      vehicleModel: _vehicleModelController.text.trim().isNotEmpty ? _vehicleModelController.text.trim() : null,
      garageId: _selectedGarageId,
    );
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
    
    if (result['success'] == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            userId: result['userId'],
            identifier: _emailController.text.trim(),
            isLogin: false,
          ),
        ),
      );
    } else if (mounted && result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Erreur lors de l\'inscription'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _vehiclePlateController.dispose();
    _vehicleModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscription'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sélection du rôle
              const Text(
                'Type de compte',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: UserRole.values.map((role) => Expanded(
                  child: _RoleCard(
                    role: role,
                    isSelected: _selectedRole == role,
                    onTap: () => setState(() => _selectedRole = role),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
              
              // Informations personnelles
              const Text(
                'Informations personnelles',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _fullNameController,
                label: 'Nom complet',
                prefixIcon: Icons.person,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _emailController,
                label: 'Email',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || !v.contains('@') ? 'Email valide requis' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _phoneController,
                label: 'Téléphone',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _addressController,
                label: 'Adresse',
                prefixIcon: Icons.location_on,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _regionController.text.isNotEmpty ? _regionController.text : null,
                      decoration: const InputDecoration(
                        labelText: 'Région',
                        prefixIcon: Icon(Icons.map),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      items: _regions.map((region) => DropdownMenuItem(
                        value: region,
                        child: Text(region),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _regionController.text = value ?? '';
                          _cityController.clear();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _cityController.text.isNotEmpty ? _cityController.text : null,
                      decoration: const InputDecoration(
                        labelText: 'Ville',
                        prefixIcon: Icon(Icons.location_city),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      items: (_cities[_regionController.text] ?? []).map((city) => DropdownMenuItem(
                        value: city,
                        child: Text(city),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _cityController.text = value ?? '';
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _passwordController,
                      label: 'Mot de passe',
                      prefixIcon: Icons.lock,
                      suffixIcon: _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      onSuffixPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      obscureText: _obscurePassword,
                      validator: (v) => v == null || v.length < 6 ? 'Min 6 caractères' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirmer',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      onSuffixPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      obscureText: _obscureConfirmPassword,
                      validator: (v) => v == null || v.length < 6 ? 'Min 6 caractères' : null,
                    ),
                  ),
                ],
              ),
              
              // Informations spécifiques pour chauffeur
              if (_selectedRole == UserRole.driver) ...[
                const SizedBox(height: 24),
                const Text(
                  'Informations véhicule',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _vehiclePlateController,
                  label: 'Plaque d\'immatriculation',
                  prefixIcon: Icons.local_taxi,
                  hint: 'Ex: DK-123-AB',
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _vehicleModelController,
                  label: 'Modèle du véhicule',
                  prefixIcon: Icons.directions_car,
                  hint: 'Ex: Toyota HiAce',
                ),
              ],
              
              const SizedBox(height: 32),
              CustomButton(
                text: 'Créer mon compte',
                onPressed: _register,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Déjà un compte ? ', style: TextStyle(color: Colors.grey[600])),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Se connecter', style: TextStyle(color: Color(0xFF0B6E3A))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0B6E3A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0B6E3A) : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(role.icon, color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(
              role.label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}