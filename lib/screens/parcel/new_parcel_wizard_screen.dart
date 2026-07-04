// mobile/lib/screens/parcel/new_parcel_wizard_screen.dart
// 4-STEP PARCEL CREATION WIZARD
// Étapes : Destinataire → Livraison → Colis → Récapitulatif

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/payment.dart';
import '../../models/user.dart';
import '../../models/voice_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/procolis_design_system.dart';

final _apiService = ApiService();

class NewParcelWizardScreen extends ConsumerStatefulWidget {
  const NewParcelWizardScreen({super.key});

  @override
  ConsumerState<NewParcelWizardScreen> createState() =>
      _NewParcelWizardScreenState();
}

class _NewParcelWizardScreenState extends ConsumerState<NewParcelWizardScreen> {
  final _picker = ImagePicker();
  final _audioRecorder = Record();
  final _audioPlayer = AudioPlayer();

  static const _stepLabels = [
    'Destinataire',
    'Livraison',
    'Colis',
    'Récapitulatif',
  ];

  int _currentStep = 0;
  bool _isPublishing = false;

  // --- Step 1: Destinataire ---
  final _receiverNameCtrl = TextEditingController();
  final _receiverPhoneCtrl = TextEditingController();
  final _receiverAddressCtrl = TextEditingController();

  // --- Step 2: Livraison ---
  List<Garage> _garages = [];
  bool _isLoadingGarages = true;
  String? _departureGarageId;
  String? _arrivalGarageId;
  bool _isFreeMode = true;
  List<User> _drivers = [];
  bool _isLoadingDrivers = false;
  User? _selectedDriver;

  // --- Step 3: Colis ---
  ParcelType _parcelType = ParcelType.package;
  final _weightCtrl = TextEditingController(text: '5');
  final _proposedPriceCtrl = TextEditingController(text: '5000');
  final _descriptionCtrl = TextEditingController();
  bool _isUrgent = false;
  bool _isInsured = false;
  final List<XFile> _photos = [];
  final List<XFile> _videos = [];
  final List<VoiceMessage> _voiceMessages = [];
  Timer? _recordingTimer;
  bool _isRecording = false;
  int _recordingDuration = 0;
  bool _isPlayingVoice = false;
  int _playingVoiceIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadGarages();
  }

  @override
  void dispose() {
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    _receiverAddressCtrl.dispose();
    _weightCtrl.dispose();
    _proposedPriceCtrl.dispose();
    _descriptionCtrl.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    for (final voice in _voiceMessages) {
      _deleteLocalFile(voice.path);
    }
    super.dispose();
  }

  // ==================== DATA LOADING ====================

  Future<void> _loadGarages() async {
    try {
      final garages = await _apiService.getAllGarages();
      if (!mounted) return;
      setState(() {
        _garages = garages.isEmpty && ApiService.isMockMode
            ? _fallbackGarages()
            : garages;
        _departureGarageId =
            _garages.isNotEmpty ? _garages.first.id : null;
        _arrivalGarageId = _garages.length > 1
            ? _garages[1].id
            : (_garages.isNotEmpty ? _garages.first.id : null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _garages = ApiService.isMockMode ? _fallbackGarages() : [];
        _departureGarageId =
            _garages.isNotEmpty ? _garages.first.id : null;
        _arrivalGarageId = _garages.length > 1
            ? _garages[1].id
            : (_garages.isNotEmpty ? _garages.first.id : null);
      });
    } finally {
      if (mounted) setState(() => _isLoadingGarages = false);
    }
  }

  Future<void> _loadDrivers(String garageId) async {
    setState(() {
      _isLoadingDrivers = true;
      _drivers = [];
      _selectedDriver = null;
    });
    try {
      final drivers =
          await _apiService.getGarageColleagues(garageId);
      if (!mounted) return;
      setState(() => _drivers = drivers);
    } catch (e) {
      if (!mounted) return;
      setState(() => _drivers = []);
    } finally {
      if (mounted) setState(() => _isLoadingDrivers = false);
    }
  }

  List<Garage> _fallbackGarages() {
    final now = DateTime.now();
    const cities = [
      'Dakar',
      'Thiès',
      'Saint-Louis',
      'Touba',
      'Ziguinchor',
      'Kaolack',
    ];
    return cities
        .map((city) => Garage(
              id: city.toLowerCase().replaceAll(' ', '-'),
              name: city,
              city: city,
              region: 'Sénégal',
              createdAt: now,
              updatedAt: now,
            ))
        .toList();
  }

  // ==================== STEP NAVIGATION ====================

  void _goToStep(int step) {
    if (step < _currentStep) {
      setState(() => _currentStep = step);
      return;
    }
    if (_validateCurrentStep()) {
      setState(() => _currentStep = step);
    }
  }

  void _nextStep() {
    if (_currentStep < 3 && _validateCurrentStep()) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_receiverNameCtrl.text.trim().isEmpty) {
          _showSnack('Veuillez saisir le nom du destinataire');
          return false;
        }
        if (_receiverPhoneCtrl.text.trim().isEmpty) {
          _showSnack('Veuillez saisir le téléphone du destinataire');
          return false;
        }
        return true;
      case 1:
        if (_departureGarageId == null) {
          _showSnack('Veuillez sélectionner le garage de départ');
          return false;
        }
        if (_arrivalGarageId == null) {
          _showSnack('Veuillez sélectionner le garage d\'arrivée');
          return false;
        }
        if (_departureGarageId == _arrivalGarageId) {
          _showSnack('Les garages de départ et d\'arrivée doivent être différents');
          return false;
        }
        if (!_isFreeMode && _selectedDriver == null) {
          _showSnack('Veuillez sélectionner un chauffeur');
          return false;
        }
        return true;
      case 2:
        final weight = double.tryParse(_weightCtrl.text.trim());
        if (weight == null || weight <= 0) {
          _showSnack('Veuillez saisir un poids valide');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  // ==================== HELPERS ====================

  Garage? _garageById(String? id) {
    if (id == null) return null;
    try {
      return _garages.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _deleteLocalFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      debugPrint('Erreur suppression fichier local: $e');
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatPrice(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')}';
  }

  // ==================== MEDIA HANDLERS (STEP 3) ====================

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (file == null || !mounted) return;
    setState(() => _photos.add(file));
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
    );
    if (file == null || !mounted) return;
    setState(() => _photos.add(file));
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 45),
    );
    if (file == null || !mounted) return;
    setState(() => _videos.add(file));
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        _showSnack('Permission micro refusée');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/parcel_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingDuration++);
      });
      await _audioRecorder.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        samplingRate: 44100,
      );
    } catch (e) {
      _recordingTimer?.cancel();
      if (mounted) setState(() => _isRecording = false);
      _showSnack('Enregistrement impossible');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (path == null || !mounted) {
        setState(() => _isRecording = false);
        return;
      }
      setState(() {
        _isRecording = false;
        _voiceMessages.add(
          VoiceMessage(
            path: path,
            duration: _recordingDuration,
            createdAt: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));
  void _removeVideo(int index) => setState(() => _videos.removeAt(index));

  void _removeVoice(int index) {
    final voice = _voiceMessages.removeAt(index);
    _deleteLocalFile(voice.path);
    if (_playingVoiceIndex == index) {
      _audioPlayer.stop();
      setState(() {
        _isPlayingVoice = false;
        _playingVoiceIndex = -1;
      });
    }
    setState(() {});
  }

  Future<void> _playVoicePreview(int index) async {
    if (_isPlayingVoice && _playingVoiceIndex == index) {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingVoice = false;
        _playingVoiceIndex = -1;
      });
      return;
    }
    final voice = _voiceMessages[index];
    try {
      await _audioPlayer.play(DeviceFileSource(voice.path));
      setState(() {
        _isPlayingVoice = true;
        _playingVoiceIndex = index;
      });
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlayingVoice = false;
            _playingVoiceIndex = -1;
          });
        }
      });
    } catch (e) {
      _showSnack('Lecture impossible');
    }
  }

  // ==================== PUBLISH ====================

  Future<void> _publishParcel() async {
    final user = ref.read(authProvider).user;
    final departure = _garageById(_departureGarageId);
    final arrival = _garageById(_arrivalGarageId);

    if (user == null || departure == null || arrival == null) {
      _showSnack('Informations incomplètes');
      return;
    }

    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    final proposedPrice =
        double.tryParse(_proposedPriceCtrl.text.trim()) ?? 0;
    final description = _descriptionCtrl.text.trim().isEmpty
        ? 'Colis à transporter'
        : _descriptionCtrl.text.trim();

    setState(() => _isPublishing = true);

    try {
      final photoUrls = <String>[];
      final videoUrls = <String>[];
      final audioUrls = <String>[];

      final parcelData = {
        'senderId': user.id,
        'senderName': user.fullName,
        'senderPhone': user.phone,
        'senderEmail': user.email,
        'receiverName': _receiverNameCtrl.text.trim(),
        'receiverPhone': _receiverPhoneCtrl.text.trim(),
        'receiverAddress': _receiverAddressCtrl.text.trim(),
        'description': description,
        'weight': weight,
        'type': _parcelType.value,
        'status': _isFreeMode ? 'free' : 'confirmed',
        'departureGarageId': departure.id,
        'departureGarageName': departure.name,
        'arrivalGarageId': arrival.id,
        'arrivalGarageName': arrival.name,
        'proposedPrice': proposedPrice,
        'price': proposedPrice,
        'isUrgent': _isUrgent,
        'isInsured': _isInsured,
        'insuranceAmount': _isInsured ? 200000.0 : 0.0,
        'urgentFee': _isUrgent ? 2000.0 : 0.0,
        'paymentMethod': PaymentMethod.cash.value,
        'paymentPhoneNumber': '',
        'isFreeForBidding': _isFreeMode,
        'photoUrls': photoUrls,
        'videoUrls': videoUrls,
        'audioUrls': audioUrls,
        if (!_isFreeMode && _selectedDriver != null) ...{
          'driverId': _selectedDriver!.id,
          'driverName': _selectedDriver!.fullName,
          'driverPhone': _selectedDriver!.phone,
        },
      };

      final result =
          await ref.read(parcelProvider.notifier).createParcel(parcelData);

      if (result != null && mounted) {
        // Upload media files
        if (_photos.isNotEmpty || _videos.isNotEmpty || _voiceMessages.isNotEmpty) {
          for (final photo in _photos) {
            final url = await _apiService.uploadFile(
              file: photo,
              mediaType: 'photo',
              parcelId: result.id,
            );
            if (url != null && url.isNotEmpty) photoUrls.add(url);
          }
          for (final video in _videos) {
            final url = await _apiService.uploadFile(
              file: video,
              mediaType: 'video',
              parcelId: result.id,
            );
            if (url != null && url.isNotEmpty) videoUrls.add(url);
          }
          for (final voice in _voiceMessages) {
            final url = await _apiService.uploadFile(
              file: XFile(voice.path),
              mediaType: 'audio',
              parcelId: result.id,
            );
            if (url != null && url.isNotEmpty) audioUrls.add(url);
          }
        }

        await ref.read(parcelProvider.notifier).loadMyParcels();
        _showSnack(_isFreeMode
            ? 'Colis publié en libre service'
            : 'Colis créé et chauffeur assigné');
        if (mounted) Navigator.pop(context, result);
      } else if (mounted) {
        final error = ref.read(parcelProvider).error;
        _showSnack(error ?? 'Publication impossible');
      }
    } catch (e) {
      debugPrint('Erreur création colis: $e');
      if (mounted) _showSnack('Publication impossible');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Nouveau colis'),
        leading: _currentStep == 0
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _prevStep,
              ),
      ),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: _buildStepContent(),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ==================== STEPPER ====================

  Widget _buildStepper() {
    return Container(
      color: AppTheme.cardColor,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _StepIndicator(
                    stepNumber: index + 1,
                    label: _stepLabels[index],
                    isActive: isActive,
                    isCompleted: isCompleted,
                  ),
                ),
                if (index < 3) _StepConnector(completed: isCompleted),
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
        return _buildStep1Recipient();
      case 1:
        return _buildStep2Delivery();
      case 2:
        return _buildStep3Parcel();
      case 3:
        return _buildStep4Recap();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: const Border(top: BorderSide(color: AppTheme.slate200)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B464F).withOpacity( 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  child: const Text('Précédent'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentStep == 0 ? 1 : 2,
              child: _currentStep < 3
                  ? ElevatedButton(
                      onPressed: _nextStep,
                      child: Text(
                        _currentStep == 2 ? 'Voir le récapitulatif' : 'Suivant',
                      ),
                    )
                  : _buildPublishButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: _isPublishing ? null : AppTheme.brandGradient,
        color: _isPublishing ? AppTheme.slate200 : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow:
            _isPublishing ? null : AppTheme.brandShadow(),
      ),
      child: ElevatedButton(
        onPressed: _isPublishing ? null : _publishParcel,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: AppTheme.slate200,
        ),
        child: _isPublishing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Publier le colis',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
      ),
    );
  }

  // ==================== STEP 1: DESTINATAIRE ====================

  Widget _buildStep1Recipient() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(icon: Icons.person_pin_rounded, title: 'Destinataire'),
        const SizedBox(height: 12),
        ProcolisCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              TextFormField(
                controller: _receiverNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom complet *',
                  hintText: 'Ex : Moussa Traoré',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _receiverPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone *',
                  hintText: '+221 77 000 00 00',
                  prefixIcon: Icon(Icons.call_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _receiverAddressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Adresse (optionnel)',
                  hintText: 'Quartier, rue, point de repère...',
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _InfoTip(
          message:
              'Le destinataire recevra un SMS avec le code de retrait lorsque le colis arrivera.',
        ),
      ],
    );
  }

  // ==================== STEP 2: LIVRAISON ====================

  Widget _buildStep2Delivery() {
    final departure = _garageById(_departureGarageId);
    final arrival = _garageById(_arrivalGarageId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(icon: Icons.route_rounded, title: 'Trajet'),
        const SizedBox(height: 12),
        ProcolisCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _GarageDropdown(
                      label: 'Départ',
                      icon: Icons.trip_origin_rounded,
                      value: _departureGarageId,
                      garages: _garages,
                      isLoading: _isLoadingGarages,
                      onChanged: (v) {
                        setState(() => _departureGarageId = v);
                        if (v != null) _loadDrivers(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GarageDropdown(
                      label: 'Arrivée',
                      icon: Icons.pin_drop_rounded,
                      value: _arrivalGarageId,
                      garages: _garages,
                      isLoading: _isLoadingGarages,
                      onChanged: (v) => setState(() => _arrivalGarageId = v),
                    ),
                  ),
                ],
              ),
              if (departure != null && arrival != null) ...[
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusXl),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          departure.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                            fontSize: 13,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                        ),
                        Text(
                          arrival.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(
            icon: Icons.settings_rounded, title: 'Mode de livraison'),
        const SizedBox(height: 12),
        ProcolisCard(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              _DeliveryModeTile(
                icon: Icons.campaign_rounded,
                title: 'Publier annonce',
                subtitle: 'Les chauffeurs proposent leurs prix',
                isSelected: _isFreeMode,
                onTap: () => setState(() {
                  _isFreeMode = true;
                  _selectedDriver = null;
                }),
              ),
              Container(
                height: 1,
                color: AppTheme.slate200,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              _DeliveryModeTile(
                icon: Icons.person_search_rounded,
                title: 'Assigner chauffeur',
                subtitle: 'Choisissez un chauffeur directement',
                isSelected: !_isFreeMode,
                onTap: () => setState(() => _isFreeMode = false),
              ),
            ],
          ),
        ),
        if (!_isFreeMode) ...[
          const SizedBox(height: 20),
          _SectionHeader(
              icon: Icons.person_search_rounded,
              title: 'Choisir un chauffeur'),
          const SizedBox(height: 12),
          _buildDriverPicker(),
        ],
        const SizedBox(height: 14),
        _InfoTip(
          message: _isFreeMode
              ? 'Le prix final sera celui proposé par le chauffeur lors de l\'enchère.'
              : 'Le chauffeur assigné recevra une notification immédiatement.',
        ),
      ],
    );
  }

  Widget _buildDriverPicker() {
    if (_departureGarageId == null) {
      return ProcolisCard(
        padding: const EdgeInsets.all(14),
        child: const Center(
          child: Text(
            'Sélectionnez d\'abord un garage de départ',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    if (_isLoadingDrivers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_drivers.isEmpty) {
      return ProcolisCard(
        padding: const EdgeInsets.all(14),
        child: const Center(
          child: Text(
            'Aucun chauffeur disponible dans ce garage',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: _drivers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final driver = _drivers[index];
          final isSelected = _selectedDriver?.id == driver.id;
          return _DriverCard(
            driver: driver,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedDriver = driver),
          );
        },
      ),
    );
  }

  // ==================== STEP 3: COLIS ====================

  Widget _buildStep3Parcel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
            icon: Icons.inventory_2_rounded, title: 'Détails du colis'),
        const SizedBox(height: 12),
        ProcolisCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              const Text(
                'Type de colis',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ParcelType.values.map((type) {
                  final isSelected = _parcelType == type;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(type.icon, size: 16),
                        const SizedBox(width: 6),
                        Text(type.label),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _parcelType = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Weight + Price
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Poids (kg)',
                        suffixText: 'kg',
                        prefixIcon: Icon(Icons.monitor_weight_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _proposedPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prix proposé',
                        suffixText: 'FCFA',
                        prefixIcon: Icon(Icons.sell_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 3,
                maxLength: 280,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Décrivez le contenu du colis...',
                  prefixIcon: Icon(Icons.description_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(icon: Icons.tune_rounded, title: 'Options'),
        const SizedBox(height: 12),
        ProcolisCard(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            children: [
              _OptionTile(
                icon: Icons.flash_on_rounded,
                title: 'Livraison Express',
                subtitle: 'Priorité haute, supplément 2 000 FCFA',
                value: _isUrgent,
                onChanged: (v) => setState(() => _isUrgent = v),
                activeColor: AppTheme.red500,
                activeBackground: AppTheme.red50,
              ),
              Container(
                height: 1,
                color: AppTheme.slate200,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              _OptionTile(
                icon: Icons.shield_rounded,
                title: 'Assurance',
                subtitle: 'Couvre jusqu\'à 200 000 FCFA',
                value: _isInsured,
                onChanged: (v) => setState(() => _isInsured = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(
            icon: Icons.perm_media_rounded, title: 'Médias (optionnel)'),
        const SizedBox(height: 12),
        ProcolisCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _MediaActionsGrid(
                onGallery: _pickPhoto,
                onCamera: _takePhoto,
                onVideo: _pickVideo,
                onAudio: _toggleRecording,
                isRecording: _isRecording,
                recordingDuration: _recordingDuration,
              ),
              if (_photos.isNotEmpty ||
                  _videos.isNotEmpty ||
                  _voiceMessages.isNotEmpty) ...[
                const SizedBox(height: 14),
                _MediaPreviewList(
                  photos: _photos,
                  videos: _videos,
                  voices: _voiceMessages,
                  onRemovePhoto: _removePhoto,
                  onRemoveVideo: _removeVideo,
                  onRemoveVoice: _removeVoice,
                  onPlayVoice: _playVoicePreview,
                  isPlayingVoice: _isPlayingVoice,
                  playingVoiceIndex: _playingVoiceIndex,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ==================== STEP 4: RECAPITULATIF ====================

  Widget _buildStep4Recap() {
    final departure = _garageById(_departureGarageId);
    final arrival = _garageById(_arrivalGarageId);
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    final price = double.tryParse(_proposedPriceCtrl.text.trim()) ?? 0;
    final description = _descriptionCtrl.text.trim().isEmpty
        ? 'Colis à transporter'
        : _descriptionCtrl.text.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
            icon: Icons.receipt_long_rounded, title: 'Récapitulatif'),
        const SizedBox(height: 12),

        // Destinataire
        _RecapSection(
          title: 'Destinataire',
          icon: Icons.person_pin_rounded,
          onEdit: () => _goToStep(0),
          children: [
            _RecapRow('Nom', _receiverNameCtrl.text.trim()),
            _RecapRow('Téléphone', _receiverPhoneCtrl.text.trim()),
            if (_receiverAddressCtrl.text.trim().isNotEmpty)
              _RecapRow(
                  'Adresse', _receiverAddressCtrl.text.trim()),
          ],
        ),
        const SizedBox(height: 12),

        // Trajet
        _RecapSection(
          title: 'Trajet',
          icon: Icons.route_rounded,
          onEdit: () => _goToStep(1),
          children: [
            _RecapRow(
              'De',
              departure?.name ?? 'Non défini',
            ),
            _RecapRow('À', arrival?.name ?? 'Non défini'),
            _RecapRow(
              'Mode',
              _isFreeMode
                  ? 'Libre service (enchères)'
                  : 'Chauffeur assigné',
            ),
            if (!_isFreeMode && _selectedDriver != null)
              _RecapRow(
                'Chauffeur',
                _selectedDriver!.fullName,
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Colis
        _RecapSection(
          title: 'Colis',
          icon: Icons.inventory_2_rounded,
          onEdit: () => _goToStep(2),
          children: [
            _RecapRow('Type', _parcelType.label),
            _RecapRow('Poids', '${weight.toStringAsFixed(1)} kg'),
            if (price > 0)
              _RecapRow('Prix proposé', '${_formatPrice(price.toInt())} FCFA'),
            _RecapRow('Description',
                description.length > 60
                    ? '${description.substring(0, 60)}...'
                    : description),
          ],
        ),
        const SizedBox(height: 12),

        // Options
        _RecapSection(
          title: 'Options',
          icon: Icons.tune_rounded,
          onEdit: () => _goToStep(2),
          children: [
            _RecapBadgeRow(
              'Express',
              _isUrgent,
              activeLabel: 'Oui',
              inactiveLabel: 'Non',
              activeColor: AppTheme.red500,
            ),
            _RecapBadgeRow(
              'Assurance',
              _isInsured,
              activeLabel: 'Oui (200 000 FCFA)',
              inactiveLabel: 'Non',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Médias
        _RecapSection(
          title: 'Médias',
          icon: Icons.perm_media_rounded,
          onEdit: () => _goToStep(2),
          children: [
            _RecapRow('Photos', '${_photos.length}'),
            _RecapRow('Vidéos', '${_videos.length}'),
            _RecapRow(
              'Notes vocales',
              _voiceMessages.isNotEmpty
                  ? '${_voiceMessages.length}'
                  : 'Aucune',
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ==================== PRIVATE WIDGETS ====================

}

// ==================== STEP INDICATOR ====================

class _StepIndicator extends StatelessWidget {
  final int stepNumber;
  final String label;
  final bool isActive;
  final bool isCompleted;

  const _StepIndicator({
    required this.stepNumber,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;

    if (isActive) {
      bg = AppTheme.primary;
      fg = Colors.white;
      border = AppTheme.primary;
    } else if (isCompleted) {
      bg = AppTheme.green500;
      fg = Colors.white;
      border = AppTheme.green500;
    } else {
      bg = Colors.transparent;
      fg = AppTheme.slate400;
      border = AppTheme.slate300;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? AppTheme.textPrimary : AppTheme.slate400,
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool completed;

  const _StepConnector({required this.completed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: completed ? AppTheme.green500 : AppTheme.slate200,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

// ==================== SECTION HEADER ====================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ==================== INFO TIP ====================

class _InfoTip extends StatelessWidget {
  final String message;

  const _InfoTip({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppTheme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.teal700,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== GARAGE DROPDOWN ====================

class _GarageDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<Garage> garages;
  final bool isLoading;
  final ValueChanged<String?> onChanged;

  const _GarageDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.garages,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: garages.any((g) => g.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      hint: Text(isLoading ? 'Chargement...' : 'Ville'),
      items: garages
          .map((g) => DropdownMenuItem(
                value: g.id,
                child: Text(g.name, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: garages.isEmpty ? null : onChanged,
    );
  }
}

// ==================== DELIVERY MODE TILE ====================

class _DeliveryModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeliveryModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppTheme.primaryLight
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.slate100,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : AppTheme.slate500,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? AppTheme.primary : AppTheme.slate300,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== DRIVER CARD ====================

class _DriverCard extends StatelessWidget {
  final User driver;
  final bool isSelected;
  final VoidCallback onTap;

  const _DriverCard({
    required this.driver,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = driver.driverStatus == DriverStatus.available;
    final statusColor = isAvailable ? AppTheme.green500 : AppTheme.red400;
    final statusLabel = isAvailable ? 'Disponible' : 'Occupé';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.slate200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: AppTheme.softShadow(alpha: 0.04),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryLight,
                backgroundImage: driver.hasProfilePhoto
                    ? NetworkImage(driver.profilePhoto!)
                    : null,
                child: driver.hasProfilePhoto
                    ? null
                    : Text(
                        driver.initials,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                driver.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded,
                      color: AppTheme.amber400, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    driver.formattedRating,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity( 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${driver.formattedTotalDeliveries} livraisons',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== OPTION TILE ====================

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final Color? activeBackground;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.activeBackground,
  });

  @override
  Widget build(BuildContext context) {
    final accent = activeColor ?? AppTheme.primary;
    final accentBg = activeBackground ?? AppTheme.primaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value ? accent.withOpacity( 0.12) : AppTheme.slate100,
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            ),
            child: Icon(
              icon,
              size: 18,
              color: value ? accent : AppTheme.slate500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: value ? accent : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accent,
          ),
        ],
      ),
    );
  }
}

// ==================== MEDIA ACTIONS GRID ====================

class _MediaActionsGrid extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onVideo;
  final VoidCallback onAudio;
  final bool isRecording;
  final int recordingDuration;

  const _MediaActionsGrid({
    required this.onGallery,
    required this.onCamera,
    required this.onVideo,
    required this.onAudio,
    required this.isRecording,
    required this.recordingDuration,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.65,
      children: [
        _MediaBtn(
            icon: Icons.photo_library_rounded,
            label: 'Photo galerie',
            onTap: onGallery),
        _MediaBtn(
            icon: Icons.photo_camera_rounded,
            label: 'Caméra',
            onTap: onCamera),
        _MediaBtn(
            icon: Icons.videocam_rounded,
            label: 'Vidéo',
            onTap: onVideo),
        _MediaBtn(
          icon: isRecording
              ? Icons.stop_rounded
              : Icons.mic_rounded,
          label: isRecording
              ? 'Stop ${_format(recordingDuration)}'
              : 'Note vocale',
          onTap: onAudio,
          active: isRecording,
        ),
      ],
    );
  }

  String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _MediaBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.red500 : AppTheme.primary;
    final background = active ? AppTheme.red50 : AppTheme.primaryLight;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== MEDIA PREVIEW LIST ====================

class _MediaPreviewList extends StatelessWidget {
  final List<XFile> photos;
  final List<XFile> videos;
  final List<VoiceMessage> voices;
  final ValueChanged<int> onRemovePhoto;
  final ValueChanged<int> onRemoveVideo;
  final ValueChanged<int> onRemoveVoice;
  final ValueChanged<int> onPlayVoice;
  final bool isPlayingVoice;
  final int playingVoiceIndex;

  const _MediaPreviewList({
    required this.photos,
    required this.videos,
    required this.voices,
    required this.onRemovePhoto,
    required this.onRemoveVideo,
    required this.onRemoveVoice,
    required this.onPlayVoice,
    required this.isPlayingVoice,
    required this.playingVoiceIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < photos.length; i++)
          _MediaPreviewChip(
            icon: Icons.image_rounded,
            label: 'Photo ${i + 1}',
            imagePath: photos[i].path,
            onRemove: () => onRemovePhoto(i),
          ),
        for (var i = 0; i < videos.length; i++)
          _MediaPreviewChip(
            icon: Icons.videocam_rounded,
            label: 'Vidéo ${i + 1}',
            onRemove: () => onRemoveVideo(i),
          ),
        for (var i = 0; i < voices.length; i++)
          _MediaPreviewChip(
            icon: isPlayingVoice && playingVoiceIndex == i
                ? Icons.stop_rounded
                : Icons.graphic_eq_rounded,
            label: 'Audio ${_formatDur(voices[i].duration)}',
            onTap: () => onPlayVoice(i),
            onRemove: () => onRemoveVoice(i),
          ),
      ],
    );
  }

  String _formatDur(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _MediaPreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? imagePath;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _MediaPreviewChip({
    required this.icon,
    required this.label,
    required this.onRemove,
    this.imagePath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 96,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imagePath == null
                      ? Icon(icon, color: AppTheme.primary, size: 28)
                      : Image.file(
                          File(imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(icon, color: AppTheme.primary, size: 28),
                        ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.cancel_rounded),
                  color: AppTheme.red500,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.slate700,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== RECAP WIDGETS ====================

class _RecapSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onEdit;
  final List<Widget> children;

  const _RecapSection({
    required this.title,
    required this.icon,
    required this.onEdit,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ProcolisCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded,
                          size: 14, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text(
                        'Modifier',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  final String label;
  final String value;

  const _RecapRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapBadgeRow extends StatelessWidget {
  final String label;
  final bool value;
  final String activeLabel;
  final String inactiveLabel;
  final Color? activeColor;

  const _RecapBadgeRow(
    this.label,
    this.value, {
    required this.activeLabel,
    required this.inactiveLabel,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = value ? (activeColor ?? AppTheme.green500) : AppTheme.slate400;
    final bg = value
        ? (activeColor ?? AppTheme.green500).withOpacity( 0.12)
        : AppTheme.slate100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value ? activeLabel : inactiveLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
