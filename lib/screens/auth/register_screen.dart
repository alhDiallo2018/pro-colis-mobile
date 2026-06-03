import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
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
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehicleYearController = TextEditingController();

  // État
  bool _isLoading = false;
  bool _isLoadingLocations = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  
  // Sélections
  String? _selectedRegion;
  String? _selectedCity;
  String? _selectedLocationId;
  
  // Listes dynamiques
  List<String> _regions = [];
  List<String> _cities = [];
  List<Map<String, dynamic>> _locations = [];
  
  // Map pour stocker les villes par région
  final Map<String, List<String>> _citiesByRegion = {};
  
  // ✅ MODÈLES DE VÉHICULES DU SÉNÉGAL (transports, taxis, véhicules particuliers)
  final List<String> _vehicleModels = [
    // ---- Transports en commun (cars, bus) ----
    'TATA Motors',
    'TATA Marcopolo',
    'TATA Starbus',
    'TATA Ultra',
    'Tebian',
    'King Long',
    'Yutong Bus',
    'Golden Dragon',
    'DFAC',
    'Foton',
    'Hyundai County',
    'Toyota Coaster',
    'Mitsubishi Rosa',
    'Isuzu Journey',
    'Higer Bus',
    'Ankai Bus',
    'Zhongtong Bus',
    
    // ---- Minibus et cars rapides (clandos) ----
    'Toyota HiAce (Car Rapide)',
    'Toyota HiAce',
    'Toyota Dyna',
    'Mitsubishi L300',
    'Hyundai H100',
    'Hyundai HD65',
    'Hyundai HD78',
    'Hyundai County',
    'Isuzu Elf',
    'Isuzu N-Series',
    'Foton Aumark',
    'JAC N-Series',
    'Mercedes-Benz Sprinter',
    'Mercedes-Benz Vario',
    'Renault Master',
    'Peugeot Boxer',
    'Citroën Jumper',
    'IVECO Daily',
    'Ford Transit',
    'Nissan Caravan',
    'Nissan Urvan',
    
    // ---- Berlines et véhicules particuliers (taxis, VTC) ----
    'Toyota Corolla',
    'Toyota Camry',
    'Toyota Yaris',
    'Toyota Prius',
    'Toyota Avensis',
    'Toyota Belta',
    'Toyota Vitz',
    'Toyota Passo',
    'Toyota Raum',
    'Toyota Sienta',
    'Toyota Premio',
    'Toyota Allion',
    'Toyota Axio',
    'Honda Accord',
    'Honda Civic',
    'Honda Fit',
    'Honda City',
    'Hyundai Accent',
    'Hyundai Elantra',
    'Hyundai Sonata',
    'Hyundai i10',
    'Hyundai i20',
    'Hyundai i30',
    'Kia Picanto',
    'Kia Rio',
    'Kia Cerato',
    'Kia Optima',
    'Nissan Sunny',
    'Nissan Tiida',
    'Nissan Note',
    'Nissan Micra',
    'Nissan Altima',
    'Nissan Sentra',
    'Mitsubishi Lancer',
    'Mitsubishi Colt',
    'Suzuki Swift',
    'Suzuki Alto',
    'Suzuki Celerio',
    'Mazda 2',
    'Mazda 3',
    'Mazda 6',
    'Ford Fiesta',
    'Ford Focus',
    'Peugeot 301',
    'Peugeot 206',
    'Peugeot 208',
    'Peugeot 307',
    'Peugeot 308',
    'Citroën C-Elysée',
    'Renault Logan',
    'Renault Sandero',
    'Renault Clio',
    'Renault Symbol',
    'Dacia Logan',
    'Dacia Sandero',
    'Chevrolet Spark',
    'Chevrolet Aveo',
    'Chevrolet Cruze',
    'Volkswagen Polo',
    'Volkswagen Golf',
    'Volkswagen Jetta',
    
    // ---- SUV, 4x4 et pick-up (pour les routes difficiles) ----
    'Toyota Land Cruiser',
    'Toyota Prado',
    'Toyota RAV4',
    'Toyota Hilux',
    'Toyota Fortuner',
    'Toyota Rush',
    'Nissan Patrol',
    'Nissan X-Trail',
    'Nissan Navara',
    'Nissan Pathfinder',
    'Nissan Murano',
    'Nissan Qashqai',
    'Mitsubishi Pajero',
    'Mitsubishi Pajero Sport',
    'Mitsubishi Outlander',
    'Mitsubishi L200',
    'Mitsubishi Triton',
    'Hyundai Santa Fe',
    'Hyundai Tucson',
    'Hyundai Santa Cruz',
    'Hyundai Palisade',
    'Kia Sportage',
    'Kia Sorento',
    'Kia Telluride',
    'Honda CR-V',
    'Honda HR-V',
    'Honda Pilot',
    'Ford Ranger',
    'Ford Everest',
    'Ford Explorer',
    'Ford Escape',
    'Chevrolet Trailblazer',
    'Chevrolet Tahoe',
    'GMC Yukon',
    'Jeep Grand Cherokee',
    'Jeep Wrangler',
    'Land Rover Defender',
    'Land Rover Discovery',
    'Mercedes-Benz G-Class',
    'Mercedes-Benz GLK',
    'Mercedes-Benz GLE',
    'BMW X5',
    'BMW X3',
    'Audi Q5',
    'Audi Q7',
    'Range Rover Sport',
    'Range Rover Evoque',
    'Volvo XC60',
    'Volvo XC90',
    'Suzuki Jimny',
    'Suzuki Grand Vitara',
    'Suzuki Vitara',
    'Great Wall Motors (GWM)',
    'Haval H6',
    'Haval H9',
    'BAIC BJ40',
    'BAIC BJ80',
    
    // ---- Motos et scooters (livraisons, transport rapide) ----
    'Yamaha Crypton',
    'Yamaha FZ',
    'Yamaha MT-15',
    'Yamaha MT-125',
    'Honda Dream',
    'Honda DIO',
    'Honda PCX',
    'Honda Click',
    'Honda Wave',
    'Honda CRF',
    'Honda XRM',
    'Suzuki Axelo',
    'Suzuki Gixxer',
    'Suzuki Burgman',
    'Suzuki Address',
    'TVS Apache',
    'TVS Ntorq',
    'TVS Jupiter',
    'Bajaj Pulsar',
    'Bajaj Boxer',
    'Bajaj Platina',
    'Kawasaki Ninja',
    'Kawasaki Z250',
    'Kymco Agility',
    'SYM Jet',
    
    // ---- Poids lourds et camions (transport de marchandises) ----
    'Mercedes-Benz Actros',
    'Mercedes-Benz Axor',
    'Mercedes-Benz Atego',
    'Volvo FH',
    'Volvo FM',
    'Scania R-Series',
    'Scania G-Series',
    'Scania P-Series',
    'MAN TGX',
    'MAN TGS',
    'MAN TGL',
    'DAF XF',
    'DAF CF',
    'Renault Trucks T',
    'Renault Trucks D',
    'IVECO Stralis',
    'IVECO Eurocargo',
    'IVECO Daily Cargo',
    'Hyundai Xcient',
    'Hyundai Mighty',
    'Isuzu Giga',
    'Isuzu Forward',
    'Isuzu NPR',
    'Isuzu NQR',
    'Hino 300 Series',
    'Hino 500 Series',
    'Hino 700 Series',
    'Foton Auman',
    'Foton Forland',
    'Dongfeng KL',
    'Sinotruk Howo',
    'Shacman X3000',
    'FAW J6',
    'JAC N200',
    'JAC N120',
    
    // ---- Remorques et semi-remorques ----
    'Remorque simple',
    'Remorque double essieu',
    'Semi-remorque citerne',
    'Semi-remorque frigo',
    'Semi-remorque bâché',
    'Plateau porte-conteneurs',
    'Plateau grue',
    
    // ---- Autres véhicules ----
    'Tricycle (Mbemba)',
    'Charrette tractée',
    'Voiture électrique',
    'Moto électrique',
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
    'Marron',
    'Orange',
    'Violet',
    'Rose',
    'Bordeaux',
    'Kaki',
    'Argenté',
    'Doré',
    'Bleu ciel',
    'Bleu marine',
    'Gris foncé',
    'Gris clair',
    'Blanc cassé',
  ];

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
      final locationsList = <Map<String, dynamic>>[];
      final citiesByRegionTemp = <String, Set<String>>{};
      
      for (var location in locations) {
        final region = location.region;
        final city = location.city;
        
        regionsSet.add(region);
        
        // Nettoyer le nom
        String cleanName = location.name;
        if (cleanName.startsWith('Garage ')) {
          cleanName = cleanName.substring(7);
        }
        
        locationsList.add({
          'id': location.id,
          'name': cleanName,
          'city': city,
          'region': region,
        });
        
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
        _locations = locationsList;
        _citiesByRegion.clear();
        _citiesByRegion.addAll(citiesByRegionFinal);
        _isLoadingLocations = false;
      });
      
      print('✅ Régions chargées: ${_regions.length}');
    } catch (e) {
      debugPrint('❌ Erreur chargement régions: $e');
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
      'Thiès': ['Thiès', 'Mbour', 'Tivaouane', 'Joal-Fadiouth', 'Saly', 'Somone'],
      'Saint-Louis': ['Saint-Louis', 'Richard Toll', 'Dagana', 'Podor'],
      'Ziguinchor': ['Ziguinchor', 'Bignona', 'Oussouye'],
      'Kaolack': ['Kaolack', 'Nioro du Rip', 'Gossas'],
      'Tambacounda': ['Tambacounda', 'Bakel', 'Koumpentoum'],
      'Kédougou': ['Kédougou', 'Salémata', 'Saraya'],
      'Kaffrine': ['Kaffrine', 'Malem Hodar', 'Koungheul'],
      'Diourbel': ['Diourbel', 'Bambey', 'Mbacké', 'Touba'],
      'Fatick': ['Fatick', 'Foundiougne', 'Passy', 'Sokone'],
      'Kolda': ['Kolda', 'Vélingara', 'Médina Yoro Foulah'],
      'Louga': ['Louga', 'Linguère', 'Kébémer'],
      'Matam': ['Matam', 'Kanel', 'Ourossogui'],
      'Sédhiou': ['Sédhiou', 'Bounkiling', 'Goudomp'],
    };
    
    setState(() {
      _regions = fallbackRegions;
      _citiesByRegion.clear();
      _citiesByRegion.addAll(fallbackCitiesByRegion);
      _isLoadingLocations = false;
    });
  }

  void _onRegionChanged(String? region) {
    setState(() {
      _selectedRegion = region;
      _selectedCity = null;
      _selectedLocationId = null;
      
      if (region != null && _citiesByRegion.containsKey(region)) {
        _cities = _citiesByRegion[region]!;
      } else {
        _cities = [];
      }
    });
  }

  void _onCityChanged(String? city) {
    setState(() {
      _selectedCity = city;
      _selectedLocationId = null;
    });
  }

  void _onLocationSelected(String? locationId) {
    setState(() {
      _selectedLocationId = locationId;
    });
    
    if (locationId != null) {
      final selected = _locations.firstWhere(
        (loc) => loc['id'] == locationId,
        orElse: () => {},
      );
      print('✅ Point de service sélectionné: ${selected['name']}');
    }
  }

  List<Map<String, dynamic>> get _filteredLocations {
    return _locations.where((loc) {
      if (_selectedRegion != null && loc['region'] != _selectedRegion) return false;
      if (_selectedCity != null && loc['city'] != _selectedCity) return false;
      return true;
    }).toList();
  }

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

    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez sélectionner votre point de service'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🔵 Appel de la méthode register...');
      print('📍 Région: $_selectedRegion');
      print('📍 Ville: $_selectedCity');

      final result = await ref.read(authProvider.notifier).register(
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            fullName: _fullNameController.text.trim(),
            password: _passwordController.text,
            role: 'driver',
            address: _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : null,
            city: _selectedCity,
            region: _selectedRegion,
            garageId: _selectedLocationId,
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
                        color: const Color(0xFF0B6E3A).withAlpha(25),
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

              // Nom complet
              CustomTextField(
                controller: _fullNameController,
                label: 'Nom complet *',
                prefixIcon: Icons.person,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),

              // Email
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

              // Téléphone
              CustomTextField(
                controller: _phoneController,
                label: 'Téléphone *',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),

              // Région
              if (_isLoadingLocations)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedRegion,
                  hint: const Text('Sélectionnez votre région'),
                  decoration: const InputDecoration(
                    labelText: 'Région *',
                    prefixIcon: Icon(Icons.map),
                    border: OutlineInputBorder(),
                  ),
                  items: _regions
                      .map((region) => DropdownMenuItem(
                            value: region,
                            child: Text(region, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _onRegionChanged,
                  validator: (v) => v == null ? 'Champ requis' : null,
                ),
              const SizedBox(height: 12),

              // Ville
              if (_selectedRegion != null && _cities.isNotEmpty)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedCity,
                  hint: const Text('Sélectionnez votre ville'),
                  decoration: const InputDecoration(
                    labelText: 'Ville *',
                    prefixIcon: Icon(Icons.location_city),
                    border: OutlineInputBorder(),
                  ),
                  items: _cities
                      .map((city) => DropdownMenuItem(
                            value: city,
                            child: Text(city, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _onCityChanged,
                  validator: (v) => v == null ? 'Champ requis' : null,
                ),
              const SizedBox(height: 12),

              // Adresse détaillée
              CustomTextField(
                controller: _addressController,
                label: 'Adresse détaillée',
                prefixIcon: Icons.location_on,
                maxLines: 2,
                hint: 'Ex: Quartier, Rue, Numéro...',
              ),
              const SizedBox(height: 12),

              // Point de service
              if (_selectedCity != null && _filteredLocations.isNotEmpty)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedLocationId,
                  hint: const Text('Sélectionnez votre point de service'),
                  decoration: const InputDecoration(
                    labelText: 'Point de service *',
                    prefixIcon: Icon(Icons.business_center),
                    border: OutlineInputBorder(),
                  ),
                  items: _filteredLocations.map((location) {
                    return DropdownMenuItem<String>(
                      value: location['id'],
                      child: Text(
                        location['name'],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: _onLocationSelected,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez sélectionner votre point de service';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 12),

              // Plaque d'immatriculation
              CustomTextField(
                controller: _vehiclePlateController,
                label: 'Plaque d\'immatriculation',
                prefixIcon: Icons.confirmation_number,
                hint: 'Ex: DK-123-AB',
              ),
              const SizedBox(height: 12),

              // Modèle du véhicule (avec les marques sénégalaises)
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _vehicleModelController.text.isNotEmpty
                    ? _vehicleModelController.text
                    : null,
                hint: const Text('Sélectionnez votre modèle'),
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

              // Couleur du véhicule
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _vehicleColorController.text.isNotEmpty
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

              // Année du véhicule
              CustomTextField(
                controller: _vehicleYearController,
                label: 'Année du véhicule',
                prefixIcon: Icons.calendar_today,
                keyboardType: TextInputType.number,
                hint: 'Ex: 2022',
              ),
              const SizedBox(height: 12),

              // Mot de passe
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

              // Confirmation mot de passe
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

              // Conditions d'utilisation
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
      case 'Orange':
        return Colors.orange;
      case 'Violet':
        return Colors.purple;
      case 'Rose':
        return Colors.pink;
      case 'Bordeaux':
        return Colors.deepPurple;
      case 'Kaki':
        return Colors.lime.shade700;
      case 'Argenté':
        return Colors.grey.shade400;
      case 'Doré':
        return Colors.amber.shade700;
      case 'Bleu ciel':
        return Colors.lightBlue;
      case 'Bleu marine':
        return Colors.blue.shade900;
      case 'Gris foncé':
        return Colors.grey.shade800;
      case 'Gris clair':
        return Colors.grey.shade300;
      case 'Blanc cassé':
        return Colors.white70;
      default:
        return Colors.grey;
    }
  }
}