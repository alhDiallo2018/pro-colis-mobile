// 4-step parcel creation wizard matching the web app
// Step 0: Destinataire → Step 1: Livraison → Step 2: Colis → Step 3: Recapitulatif

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/user.dart';
import '../../models/zone.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api/client.dart';
import '../../services/api/zones_api.dart';
import '../../services/api_service.dart';
import '../../services/places_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/procolis_design_system.dart';
import '../../widgets/route_picker.dart';
import '../../widgets/location_autocomplete.dart';

final _apiService = ApiService();

class NewParcelWizardScreen extends ConsumerStatefulWidget {
  const NewParcelWizardScreen({super.key});

  @override
  ConsumerState<NewParcelWizardScreen> createState() =>
      _NewParcelWizardScreenState();
}

class _NewParcelWizardScreenState extends ConsumerState<NewParcelWizardScreen> {
  int _currentStep = 0;
  bool _isPublishing = false;

  // Step 0 - Destinataire
  final _receiverNameCtrl = TextEditingController();
  final _receiverPhoneCtrl = TextEditingController();
  final _receiverEmailCtrl = TextEditingController();
  final _receiverAddressCtrl = TextEditingController();

  // Détection de zone à partir des coordonnées de l'adresse destinataire.
  final ZonesApi _zonesApi = ZonesApi(ApiClient());
  Zone? _detectedZone;
  bool _detectingZone = false;

  // Step 1 - Livraison
  List<Garage> _garages = [];
  String? _departureGarageId;
  String? _arrivalGarageId;

  // Repli "Autre lieu" : résolution d'un lieu Google Places en zone (pending).
  final _departurePlaceCtrl = TextEditingController();
  final _arrivalPlaceCtrl = TextEditingController();
  PlaceResult? _pendingDeparturePlace;
  PlaceResult? _pendingArrivalPlace;
  bool _resolvingDeparture = false;
  bool _resolvingArrival = false;
  bool _isFreeMode = true;
  List<User> _drivers = [];
  User? _selectedDriver;
  bool _loadingDrivers = false;

  // Step 2 - Colis
  ParcelType _parcelType = ParcelType.package;
  final _weightCtrl = TextEditingController();
  final _proposedPriceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _isUrgent = false;
  bool _isInsured = false;
  List<XFile> _photos = [];
  List<XFile> _videos = [];
  List<VoiceMessageData> _voiceMessages = [];

  final Record _recorder = Record();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _loadGarages();
    _loadDriversForGarage();
  }

  @override
  void dispose() {
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    _receiverEmailCtrl.dispose();
    _receiverAddressCtrl.dispose();
    _weightCtrl.dispose();
    _proposedPriceCtrl.dispose();
    _descriptionCtrl.dispose();
    _departurePlaceCtrl.dispose();
    _arrivalPlaceCtrl.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadGarages() async {
    try {
      final garages = await _apiService.getAllGarages();
      if (mounted) setState(() => _garages = garages);
    } catch (_) {}
  }

  Future<void> _loadDriversForGarage({String? garageId}) async {
    final gid = garageId ?? _departureGarageId;
    if (gid == null) return;
    setState(() => _loadingDrivers = true);
    try {
      final drivers = await _apiService.getGarageColleagues(gid);
      if (mounted) setState(() => _drivers = drivers);
    } catch (_) {}
    if (mounted) setState(() => _loadingDrivers = false);
  }

  Future<void> _detectZoneFromCoordinates(double lat, double lng) async {
    setState(() {
      _detectingZone = true;
      _detectedZone = null;
    });
    final zones = await _zonesApi.detectZones(lat, lng);
    if (!mounted) return;
    setState(() {
      _detectingZone = false;
      _detectedZone = zones.isNotEmpty ? zones.first : null;
    });
  }

  /// Résout le lieu Google Places choisi en zone (création "pending" côté API),
  /// l'ajoute à la liste et l'affecte au départ ou à l'arrivée.
  Future<void> _resolvePlaceToField({required bool departure, required double lat, required double lng}) async {
    final place = departure ? _pendingDeparturePlace : _pendingArrivalPlace;
    if (place == null) return;
    setState(() {
      if (departure) {
        _resolvingDeparture = true;
      } else {
        _resolvingArrival = true;
      }
    });
    final garage = await _zonesApi.resolvePlaceAsGarage(
      placeId: place.placeId.isNotEmpty ? place.placeId : null,
      name: place.mainText.isNotEmpty ? place.mainText : place.description,
      latitude: lat,
      longitude: lng,
    );
    if (!mounted) return;
    setState(() {
      if (departure) {
        _resolvingDeparture = false;
      } else {
        _resolvingArrival = false;
      }
      if (garage != null) {
        if (!_garages.any((g) => g.id == garage.id)) {
          _garages = [..._garages, garage];
        }
        if (departure) {
          _departureGarageId = garage.id;
          _selectedDriver = null;
        } else {
          _arrivalGarageId = garage.id;
        }
      }
    });
    if (garage != null && departure) _loadDriversForGarage(garageId: garage.id);
    if (garage == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de résoudre ce lieu, réessayez.')),
      );
    }
  }

  Garage? _garageById(String? id) {
    if (id == null) return null;
    try {
      return _garages.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
  }

  bool _canProceed(int step) {
    switch (step) {
      case 0:
        return _receiverNameCtrl.text.trim().isNotEmpty &&
            _receiverPhoneCtrl.text.trim().isNotEmpty;
      case 1:
        return _departureGarageId != null &&
            _arrivalGarageId != null &&
            _departureGarageId != _arrivalGarageId &&
            (_isFreeMode || _selectedDriver != null);
      case 2:
        return _weightCtrl.text.trim().isNotEmpty &&
            double.tryParse(_weightCtrl.text.trim()) != null;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (!_canProceed(_currentStep)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs requis')),
      );
      return;
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isNotEmpty) {
      setState(() => _photos = [..._photos, ...files]);
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      setState(() => _photos = [..._photos, file]);
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _videos = [..._videos, file]);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      _isRecording = false;
      if (path != null) {
        setState(() {
          _voiceMessages.add(VoiceMessageData(path: path, duration: _recordDuration));
          _recordDuration = 0;
        });
      }
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          path: filePath,
          encoder: AudioEncoder.aacLc,
          samplingRate: 44100,
        );
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
        _startTimer();
      }
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_isRecording && mounted) {
        setState(() => _recordDuration++);
        return true;
      }
      return false;
    });
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _publishParcel() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    final proposedPrice = double.tryParse(_proposedPriceCtrl.text.trim()) ?? 0;
    final description = _descriptionCtrl.text.trim().isEmpty
        ? 'Colis à transporter'
        : _descriptionCtrl.text.trim();

    setState(() => _isPublishing = true);

    try {
      final parcelData = {
        'senderId': user.id,
        'senderName': user.fullName,
        'senderPhone': user.phone,
        'senderEmail': user.email,
        'receiverName': _receiverNameCtrl.text.trim(),
        'receiverPhone': _receiverPhoneCtrl.text.trim(),
        'receiverEmail': _receiverEmailCtrl.text.trim().isEmpty ? null : _receiverEmailCtrl.text.trim(),
        'receiverAddress': _receiverAddressCtrl.text.trim(),
        'description': description,
        'weight': weight,
        'type': _parcelType.value,
        'status': _isFreeMode ? 'free' : 'pending',
        'departureGarageId': _departureGarageId,
        'arrivalGarageId': _arrivalGarageId,
        'proposedPrice': proposedPrice,
        'price': proposedPrice,
        'isUrgent': _isUrgent,
        'isInsured': _isInsured,
        'isFreeForBidding': _isFreeMode,
        'paymentMethod': 'cash',
        if (!_isFreeMode && _selectedDriver != null)
          'driverId': _selectedDriver!.id,
      };

      final result = await ref.read(parcelProvider.notifier).createParcel(parcelData);

      if (result != null && mounted) {
        for (final photo in _photos) {
          await _apiService.uploadFile(file: photo, mediaType: 'photo', parcelId: result.id);
        }
        for (final video in _videos) {
          await _apiService.uploadFile(file: video, mediaType: 'video', parcelId: result.id);
        }
        for (final voice in _voiceMessages) {
          await _apiService.uploadFile(file: XFile(voice.path), mediaType: 'audio', parcelId: result.id);
        }

        await ref.read(parcelProvider.notifier).loadSentParcels();
        _showSnack(_isFreeMode ? 'Colis publié en libre service' : 'Colis créé et chauffeur assigné');
        if (mounted) Navigator.pop(context, result);
      } else if (mounted) {
        _showSnack('Erreur lors de la création du colis');
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  String get _modeLabel => _isFreeMode ? 'Publier une annonce' : 'Assigner un chauffeur';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Nouveau colis'),
        backgroundColor: AppTheme.cardColor,
      ),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: _buildStepContent(),
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    final steps = ['Destinataire', 'Livraison', 'Colis', 'Récapitulatif'];
    return Container(
      color: AppTheme.cardColor,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          final circleColor = isDone
              ? AppTheme.green500
              : isActive
                  ? AppTheme.primary
                  : AppTheme.slate300;
          final textColor = isActive || isDone ? AppTheme.textPrimary : AppTheme.slate400;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isDone ? AppTheme.green300 : AppTheme.slate200,
                        ),
                      ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppTheme.green500
                            : isActive
                                ? AppTheme.primaryLight
                                : AppTheme.slate100,
                        shape: BoxShape.circle,
                        border: Border.all(color: circleColor, width: 2),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? AppTheme.primary : AppTheme.slate400,
                                ),
                              ),
                      ),
                    ),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isDone ? AppTheme.green300 : AppTheme.slate200,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildDestinataire();
      case 1:
        return _buildLivraison();
      case 2:
        return _buildColis();
      case 3:
        return _buildRecap();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDestinataire() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('Destinataire', Icons.person_pin_rounded),
        const SizedBox(height: 12),
        TextField(
          controller: _receiverNameCtrl,
          decoration: InputDecoration(
            labelText: 'Nom du destinataire *',
            prefixIcon: const Icon(Icons.badge_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _receiverPhoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Téléphone *',
            prefixIcon: const Icon(Icons.call_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _receiverEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email du destinataire',
            prefixIcon: const Icon(Icons.email_rounded),
          ),
        ),
        const SizedBox(height: 12),
        LocationAutocomplete(
          controller: _receiverAddressCtrl,
          label: 'Adresse (optionnel)',
          prefixIcon: Icons.location_on_rounded,
          hint: 'Rechercher une adresse...',
          googleApiKey: PlacesService.googleApiKey,
          onCoordinates: _detectZoneFromCoordinates,
        ),
        if (_detectingZone || _detectedZone != null) ...[
          const SizedBox(height: 8),
          _buildDetectedZoneChip(),
        ],
      ],
    );
  }

  Widget _buildDetectedZoneChip() {
    if (_detectingZone) {
      return const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Détection de la zone...',
            style: TextStyle(fontSize: 12, color: AppTheme.slate500),
          ),
        ],
      );
    }
    final zone = _detectedZone!;
    final label = zone.displayName?.isNotEmpty == true
        ? zone.displayName!
        : zone.name;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.teal50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.teal100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.explore_rounded,
              size: 16, color: AppTheme.teal600),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Zone détectée : $label',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.teal700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivraison() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('Trajet', Icons.route_rounded),
        const SizedBox(height: 12),
        RoutePicker(
          garages: _garages,
          initialDeparture: _garageById(_departureGarageId),
          initialArrival: _garageById(_arrivalGarageId),
          departureLabel: 'Zone de départ',
          arrivalLabel: "Zone d'arrivée",
          onDepartureChanged: (g) {
            setState(() {
              _departureGarageId = g?.id;
              _selectedDriver = null;
            });
            if (g != null) _loadDriversForGarage(garageId: g.id);
          },
          onArrivalChanged: (g) {
            setState(() => _arrivalGarageId = g?.id);
          },
        ),
        const SizedBox(height: 14),
        Text(
          'Zone introuvable ? Ajoutez un lieu (Google Places)',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.slate500),
        ),
        const SizedBox(height: 8),
        LocationAutocomplete(
          controller: _departurePlaceCtrl,
          label: _resolvingDeparture ? 'Résolution du lieu…' : 'Autre lieu de départ',
          prefixIcon: Icons.add_location_alt_rounded,
          hint: 'Ville / adresse de départ',
          googleApiKey: PlacesService.googleApiKey,
          onPlaceSelected: (p) => _pendingDeparturePlace = p,
          onCoordinates: (lat, lng) => _resolvePlaceToField(departure: true, lat: lat, lng: lng),
        ),
        const SizedBox(height: 8),
        LocationAutocomplete(
          controller: _arrivalPlaceCtrl,
          label: _resolvingArrival ? 'Résolution du lieu…' : "Autre lieu d'arrivée",
          prefixIcon: Icons.add_location_alt_rounded,
          hint: "Ville / adresse d'arrivée",
          googleApiKey: PlacesService.googleApiKey,
          onPlaceSelected: (p) => _pendingArrivalPlace = p,
          onCoordinates: (lat, lng) => _resolvePlaceToField(departure: false, lat: lat, lng: lng),
        ),
        const SizedBox(height: 20),
        _sectionHeader('Mode de livraison', Icons.settings_rounded),
        const SizedBox(height: 12),
        _modeTile(
          Icons.campaign_rounded,
          'Publier une annonce',
          'Les chauffeurs pourront faire des offres',
          _isFreeMode,
          () => setState(() => _isFreeMode = true),
        ),
        const SizedBox(height: 8),
        _modeTile(
          Icons.person_search_rounded,
          'Assigner un chauffeur',
          'Choisissez un chauffeur directement',
          !_isFreeMode,
          () => setState(() => _isFreeMode = false),
        ),
        if (!_isFreeMode) ...[
          const SizedBox(height: 16),
          if (_loadingDrivers)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_drivers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun chauffeur disponible pour cette zone', textAlign: TextAlign.center),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _drivers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final d = _drivers[i];
                  final selected = _selectedDriver?.id == d.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDriver = d),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primaryLight : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: selected ? AppTheme.primary : AppTheme.slate200,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppTheme.primaryLight,
                            child: Text(
                              d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${d.completedDeliveries} liv.',
                            style: const TextStyle(fontSize: 10, color: AppTheme.slate500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }

  Widget _modeTile(IconData icon, String title, String subtitle, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight : AppTheme.slate50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.slate200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.primary : AppTheme.slate400, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: selected ? AppTheme.primary : AppTheme.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: selected ? AppTheme.teal600 : AppTheme.slate500)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildColis() {
    final types = [
      (ParcelType.document, Icons.description, 'Document'),
      (ParcelType.package, Icons.inventory, 'Colis standard'),
      (ParcelType.fragile, Icons.warning, 'Fragile'),
      (ParcelType.perishable, Icons.food_bank, 'Périssable'),
      (ParcelType.valuable, Icons.attach_money, 'Précieux'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('Type de colis', Icons.category_rounded),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((t) {
            final selected = _parcelType == t.$1;
            return GestureDetector(
              onTap: () => setState(() => _parcelType = t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryLight : AppTheme.slate50,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? AppTheme.primary : AppTheme.slate200,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.$2, size: 16, color: selected ? AppTheme.primary : AppTheme.slate500),
                    const SizedBox(width: 6),
                    Text(t.$3, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppTheme.primary : AppTheme.textPrimary)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Poids (kg) *',
                  prefixIcon: const Icon(Icons.monitor_weight_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _proposedPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Prix proposé (FCFA)',
                  prefixIcon: const Icon(Icons.sell_rounded),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionCtrl,
          maxLines: 3,
          maxLength: 280,
          decoration: InputDecoration(
            labelText: 'Description',
            prefixIcon: const Icon(Icons.description_rounded),
          ),
        ),
        const SizedBox(height: 20),
        _sectionHeader('Options', Icons.tune_rounded),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _isUrgent,
          onChanged: (v) => setState(() => _isUrgent = v),
          title: const Text('Express / Urgent', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Livraison prioritaire (+2000 FCFA)'),
          activeColor: AppTheme.red400,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          value: _isInsured,
          onChanged: (v) => setState(() => _isInsured = v),
          title: const Text('Assurance', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Protection du colis (200 000 FCFA)'),
          activeColor: AppTheme.green500,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 20),
        _sectionHeader('Médias (optionnel)', Icons.perm_media_rounded),
        const SizedBox(height: 8),
        Row(
          children: [
            _mediaButton(Icons.photo_library_rounded, 'Photos', _pickPhotos),
            const SizedBox(width: 8),
            _mediaButton(Icons.photo_camera_rounded, 'Photo', _takePhoto),
            const SizedBox(width: 8),
            _mediaButton(Icons.videocam_rounded, 'Vidéo', _pickVideo),
            const SizedBox(width: 8),
            _mediaButton(
              _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              _isRecording ? '${_formatDuration(_recordDuration)}' : 'Voix',
              _toggleRecording,
              highlight: _isRecording,
            ),
          ],
        ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('${_photos.length} photo(s)', style: const TextStyle(fontSize: 12, color: AppTheme.slate500)),
        ],
        if (_voiceMessages.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${_voiceMessages.length} message(s) vocal(aux)', style: const TextStyle(fontSize: 12, color: AppTheme.slate500)),
        ],
      ],
    );
  }

  Widget _mediaButton(IconData icon, String label, VoidCallback onTap, {bool highlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: highlight ? AppTheme.red50 : AppTheme.slate100,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: highlight ? AppTheme.red400 : AppTheme.primary),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: highlight ? AppTheme.red400 : AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecap() {
    final departure = _garageById(_departureGarageId);
    final arrival = _garageById(_arrivalGarageId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('Récapitulatif', Icons.receipt_long_rounded),
        const SizedBox(height: 12),
        _recapSection('Destinataire', Icons.person_pin_rounded, [
          _recapRow('Nom', _receiverNameCtrl.text.trim()),
          _recapRow('Téléphone', _receiverPhoneCtrl.text.trim()),
          if (_receiverEmailCtrl.text.trim().isNotEmpty) _recapRow('Email', _receiverEmailCtrl.text.trim()),
          if (_receiverAddressCtrl.text.trim().isNotEmpty) _recapRow('Adresse', _receiverAddressCtrl.text.trim()),
        ], onEdit: () => _goToStep(0)),
        const SizedBox(height: 12),
        _recapSection('Livraison', Icons.route_rounded, [
          _recapRow('Départ', departure?.name ?? '-'),
          _recapRow('Arrivée', arrival?.name ?? '-'),
          _recapRow('Mode', _modeLabel),
          if (!_isFreeMode && _selectedDriver != null) _recapRow('Chauffeur', _selectedDriver!.fullName),
        ], onEdit: () => _goToStep(1)),
        const SizedBox(height: 12),
        _recapSection('Colis', Icons.tune_rounded, [
          _recapRow('Type', _parcelType.label),
          _recapRow('Poids', '${_weightCtrl.text.trim()} kg'),
          if (_proposedPriceCtrl.text.trim().isNotEmpty) _recapRow('Prix', '${_proposedPriceCtrl.text.trim()} FCFA'),
          if (_descriptionCtrl.text.trim().isNotEmpty) _recapRow('Description', _descriptionCtrl.text.trim()),
          _recapBadgeRow('Express', _isUrgent, 'Oui (+2000 FCFA)', 'Non'),
          _recapBadgeRow('Assurance', _isInsured, 'Oui', 'Non'),
        ], onEdit: () => _goToStep(2)),
        if (_photos.isNotEmpty || _voiceMessages.isNotEmpty) ...[
          const SizedBox(height: 12),
          _recapSection('Médias', Icons.perm_media_rounded, [
            if (_photos.isNotEmpty) _recapRow('Photos', '${_photos.length} fichier(s)'),
            if (_videos.isNotEmpty) _recapRow('Vidéos', '${_videos.length} fichier(s)'),
            if (_voiceMessages.isNotEmpty) _recapRow('Audio', '${_voiceMessages.length} message(s)'),
          ]),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _recapSection(String title, IconData icon, List<Widget> rows, {VoidCallback? onEdit}) {
    return ProcolisCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.primary),
                ),
            ],
          ),
          const Divider(height: 20),
          ...rows,
        ],
      ),
    );
  }

  Widget _recapRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
        ],
      ),
    );
  }

  Widget _recapBadgeRow(String label, bool value, String activeLabel, String inactiveLabel) {
    final color = value ? AppTheme.green500 : AppTheme.slate400;
    final bg = value ? AppTheme.green50 : AppTheme.slate100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(
              value ? activeLabel : inactiveLabel,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: const Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(100, 46),
                side: const BorderSide(color: AppTheme.slate300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              child: const Text('Précédent'),
            )
          else
            const SizedBox(width: 100),
          const Spacer(),
          if (_currentStep < 3)
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 46),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              child: const Text('Suivant'),
            )
          else
            ElevatedButton(
              onPressed: _isPublishing ? null : _publishParcel,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(160, 46),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              child: _isPublishing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Publier le colis'),
            ),
        ],
      ),
    );
  }
}

class VoiceMessageData {
  final String path;
  final int duration;
  const VoiceMessageData({required this.path, required this.duration});
}
