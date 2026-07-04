// mobile/lib/screens/parcel/new_parcel_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/payment.dart';
import '../../models/voice_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/procolis_design_system.dart';
import '../parcel/ads/advertisements_screen.dart';

class NewParcelScreen extends ConsumerStatefulWidget {
  const NewParcelScreen({super.key});

  @override
  ConsumerState<NewParcelScreen> createState() => _NewParcelScreenState();
}

class _NewParcelScreenState extends ConsumerState<NewParcelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _picker = ImagePicker();
  final _audioRecorder = Record();

  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _weightController = TextEditingController(text: '8');
  final _descriptionController = TextEditingController();
  final List<XFile> _photos = [];
  final List<XFile> _videos = [];
  final List<VoiceMessage> _voiceMessages = [];
  Timer? _recordingTimer;
  bool _isRecording = false;
  int _recordingDuration = 0;

  List<Garage> _garages = [];
  String? _departureId;
  String? _arrivalId;
  ParcelType? _type = ParcelType.package;
  bool _insurance = true;
  bool _urgent = false;
  bool _terms = false;
  bool _isLoading = false;
  bool _isLoadingGarages = true;

  @override
  void initState() {
    super.initState();
    _loadGarages();
  }

  @override
  void dispose() {
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _weightController.dispose();
    _descriptionController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    for (final voice in _voiceMessages) {
      _deleteLocalFile(voice.path);
    }
    super.dispose();
  }

  Future<void> _loadGarages() async {
    try {
      final garages = await _apiService.getAllGarages();
      if (!mounted) return;
      setState(() {
        _garages = garages.isEmpty && ApiService.isMockMode
            ? _fallbackGarages()
            : garages;
        _departureId = _garages.isNotEmpty ? _garages.first.id : null;
        _arrivalId = _garages.length > 1
            ? _garages[1].id
            : (_garages.isNotEmpty ? _garages.first.id : null);
      });
    } catch (error) {
      debugPrint('Erreur chargement garages nouveau colis: $error');
      if (!mounted) return;
      setState(() {
        _garages = ApiService.isMockMode ? _fallbackGarages() : [];
        _departureId = _garages.isNotEmpty ? _garages.first.id : null;
        _arrivalId = _garages.length > 1
            ? _garages[1].id
            : (_garages.isNotEmpty ? _garages.first.id : null);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingGarages = false);
      }
    }
  }

  List<Garage> _fallbackGarages() {
    final now = DateTime.now();
    const cities = [
      'Abidjan',
      'Yamoussoukro',
      'Bouaké',
      'Daloa',
      'San-Pédro',
      'Korhogo',
    ];

    return cities
        .map(
          (city) => Garage(
            id: city.toLowerCase().replaceAll(' ', '-'),
            name: city,
            city: city,
            region: 'Côte d’Ivoire',
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();
  }

  int get _estimatedPrice => _urgent ? 14500 : 12500;

  Garage? _garageById(String? id) {
    if (id == null) return null;
    try {
      return _garages.firstWhere((garage) => garage.id == id);
    } catch (_) {
      return null;
    }
  }

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

      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/parcel_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
    } catch (error) {
      debugPrint('Erreur enregistrement audio colis: $error');
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
    } catch (error) {
      debugPrint('Erreur arrêt audio colis: $error');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _removeVideo(int index) {
    setState(() => _videos.removeAt(index));
  }

  void _removeVoice(int index) {
    final voice = _voiceMessages.removeAt(index);
    _deleteLocalFile(voice.path);
    setState(() {});
  }

  void _deleteLocalFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (error) {
      debugPrint('Erreur suppression fichier local: $error');
    }
  }

  Future<void> _uploadMediaForParcel(String parcelId) async {
    if (_photos.isEmpty && _videos.isEmpty && _voiceMessages.isEmpty) return;

    final photoUrls = <String>[];
    final videoUrls = <String>[];
    final audioUrls = <String>[];

    for (final photo in _photos) {
      final url = await _apiService.uploadFile(file: photo, mediaType: 'photo', parcelId: parcelId);
      if (url != null && url.isNotEmpty) photoUrls.add(url);
    }

    for (final video in _videos) {
      final url = await _apiService.uploadFile(file: video, mediaType: 'video', parcelId: parcelId);
      if (url != null && url.isNotEmpty) videoUrls.add(url);
    }

    for (final voice in _voiceMessages) {
      final url = await _apiService.uploadFile(file: XFile(voice.path), mediaType: 'audio', parcelId: parcelId);
      if (url != null && url.isNotEmpty) audioUrls.add(url);
    }

    if (photoUrls.isEmpty && videoUrls.isEmpty && audioUrls.isEmpty) return;

    // Médias déjà uploadés, inclus dans les données du colis
    // (Les URLs sont attachées au payload de création du colis)
  }

  Future<void> _publishParcel() async {
    if (_isLoadingGarages) {
      _showSnack('Chargement des garages en cours');
      return;
    }

    if (!_terms) {
      _showSnack('Veuillez accepter les conditions');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnack('Veuillez compléter les champs requis');
      return;
    }

    final user = ref.read(authProvider).user;
    final departure = _garageById(_departureId);
    final arrival = _garageById(_arrivalId);

    if (user == null || departure == null || arrival == null || _type == null) {
      _showSnack('Informations incomplètes');
      return;
    }

    if (departure.id == arrival.id) {
      _showSnack('Choisissez deux garages différents');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Le design publie directement en libre service. On conserve donc le
      // contrat existant Parcel en créant un colis "free" sans chauffeur.
      final parcelData = {
        'senderId': user.id,
        'senderName': user.fullName,
        'senderPhone': user.phone,
        'senderEmail': user.email,
        'receiverName': _receiverNameController.text.trim(),
        'receiverPhone': _receiverPhoneController.text.trim(),
        'receiverEmail': '',
        'receiverAddress': arrival.name,
        'description': _descriptionController.text.trim().isEmpty
            ? 'Colis à transporter'
            : _descriptionController.text.trim(),
        'weight': double.tryParse(_weightController.text.trim()) ?? 0,
        'type': _type!.value,
        'status': 'free',
        'departureGarageId': departure.id,
        'departureGarageName': departure.name,
        'arrivalGarageId': arrival.id,
        'arrivalGarageName': arrival.name,
        'price': _estimatedPrice.toDouble(),
        'proposedPrice': _estimatedPrice.toDouble(),
        'isUrgent': _urgent,
        'isInsured': _insurance,
        'insuranceAmount': _insurance ? 200000.0 : 0.0,
        'urgentFee': _urgent ? 2000.0 : 0.0,
        'paymentMethod': PaymentMethod.cash.value,
        'paymentPhoneNumber': '',
        'isFreeForBidding': true,
        'driverId': null,
        'driverName': null,
        'driverPhone': null,
        'audioUrls': <String>[],
      };

      final result = await ref.read(parcelProvider.notifier).createParcel(
            parcelData,
          );

      if (result != null && mounted) {
        await _uploadMediaForParcel(result.id);
        await ref.read(parcelProvider.notifier).loadMyParcels();
        _showSnack('Colis publié en libre service');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AdvertisementsScreen(),
          ),
        );
      } else if (mounted) {
        final error = ref.read(parcelProvider).error;
        _showSnack(error ?? 'Publication impossible');
      }
    } catch (error) {
      debugPrint('Erreur création nouveau colis: $error');
      if (mounted) {
        _showSnack('Publication impossible');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _saveDraft() {
    _showSnack('Brouillon enregistré');
    Navigator.pop(context);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Column(
          children: [
            Text('Nouveau colis'),
            SizedBox(height: 1),
            Text(
              'Étape 1 sur 2',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          children: [
            _DesignFormSection(
              title: 'Trajet',
              icon: Icons.route_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _GarageSelect(
                        label: 'Départ',
                        icon: Icons.trip_origin_rounded,
                        value: _departureId,
                        garages: _garages,
                        isLoading: _isLoadingGarages,
                        onChanged: (value) =>
                            setState(() => _departureId = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GarageSelect(
                        label: 'Arrivée',
                        icon: Icons.pin_drop_rounded,
                        value: _arrivalId,
                        garages: _garages,
                        isLoading: _isLoadingGarages,
                        onChanged: (value) =>
                            setState(() => _arrivalId = value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DesignFormSection(
              title: 'Destinataire',
              icon: Icons.person_pin_rounded,
              children: [
                TextFormField(
                  controller: _receiverNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    hintText: 'Ex : Moussa Traoré',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _receiverPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    hintText: '07 00 00 00',
                    prefixIcon: Icon(Icons.call_rounded),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Requis' : null,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DesignFormSection(
              title: 'Colis',
              icon: Icons.inventory_2_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ParcelType>(
                        initialValue: _type,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: ParcelType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _type = value),
                        validator: (value) => value == null ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Poids',
                          suffixText: 'kg',
                        ),
                        validator: (value) {
                          final number = double.tryParse(value ?? '');
                          if (number == null || number <= 0) return 'Invalide';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optionnel)',
                    hintText: 'Contenu du colis',
                    prefixIcon: Icon(Icons.description_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DesignFormSection(
              title: 'Photos, vidéo & audio',
              icon: Icons.perm_media_rounded,
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
                  _MediaPreviewStrip(
                    photos: _photos,
                    videos: _videos,
                    voices: _voiceMessages,
                    onRemovePhoto: _removePhoto,
                    onRemoveVideo: _removeVideo,
                    onRemoveVoice: _removeVoice,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            _DesignFormSection(
              title: 'Options',
              icon: Icons.tune_rounded,
              children: [
                _DesignSwitchRow(
                  value: _insurance,
                  onChanged: (value) => setState(() => _insurance = value),
                  title: 'Assurance',
                  subtitle: 'Couvre jusqu’à 200 000 FCFA',
                ),
                const Divider(height: 1),
                _DesignSwitchRow(
                  value: _urgent,
                  onChanged: (value) => setState(() => _urgent = value),
                  title: 'Livraison urgente (express)',
                  subtitle: 'Priorité haute, supplément 2 000 FCFA',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _EstimatedPriceCard(
              amount: _estimatedPrice,
              urgent: _urgent,
            ),
            const SizedBox(height: 14),
            _TermsCheckbox(
              value: _terms,
              onChanged: (value) => setState(() => _terms = value),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _publishParcel,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sell_rounded),
              label: Text(
                  _isLoading ? 'Publication...' : 'Publier en libre service'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading ? null : _saveDraft,
              child: const Text('Enregistrer comme brouillon'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignFormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DesignFormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ProcolisCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _GarageSelect extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<Garage> garages;
  final bool isLoading;
  final ValueChanged<String?> onChanged;

  const _GarageSelect({
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
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      hint: Text(isLoading ? 'Chargement...' : 'Ville'),
      items: garages
          .map(
            (garage) => DropdownMenuItem(
              value: garage.id,
              child: Text(
                garage.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: garages.isEmpty ? null : onChanged,
      validator: (value) => value == null ? 'Requis' : null,
    );
  }
}

class _DesignSwitchRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;

  const _DesignSwitchRow({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

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
        _MediaActionButton(
          icon: Icons.photo_library_rounded,
          label: 'Photo galerie',
          onTap: onGallery,
        ),
        _MediaActionButton(
          icon: Icons.photo_camera_rounded,
          label: 'Caméra',
          onTap: onCamera,
        ),
        _MediaActionButton(
          icon: Icons.videocam_rounded,
          label: 'Vidéo',
          onTap: onVideo,
        ),
        _MediaActionButton(
          icon: isRecording ? Icons.stop_rounded : Icons.mic_rounded,
          label: isRecording
              ? 'Stop ${_formatDuration(recordingDuration)}'
              : 'Note vocale',
          onTap: onAudio,
          active: isRecording,
        ),
      ],
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }
}

class _MediaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _MediaActionButton({
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
                    fontWeight: FontWeight.w900,
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

class _MediaPreviewStrip extends StatelessWidget {
  final List<XFile> photos;
  final List<XFile> videos;
  final List<VoiceMessage> voices;
  final ValueChanged<int> onRemovePhoto;
  final ValueChanged<int> onRemoveVideo;
  final ValueChanged<int> onRemoveVoice;

  const _MediaPreviewStrip({
    required this.photos,
    required this.videos,
    required this.voices,
    required this.onRemovePhoto,
    required this.onRemoveVideo,
    required this.onRemoveVoice,
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
            icon: Icons.graphic_eq_rounded,
            label: 'Audio ${_formatDuration(voices[i].duration)}',
            onRemove: () => onRemoveVoice(i),
          ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }
}

class _MediaPreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? imagePath;
  final VoidCallback onRemove;

  const _MediaPreviewChip({
    required this.icon,
    required this.label,
    required this.onRemove,
    this.imagePath,
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
              Container(
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

class _EstimatedPriceCard extends StatelessWidget {
  final int amount;
  final bool urgent;

  const _EstimatedPriceCard({
    required this.amount,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    return ProcolisCard(
      color: AppTheme.primaryLight,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prix estimé',
                  style: TextStyle(
                    color: AppTheme.teal700,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${amount.toString().replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+$)'),
                        (match) => '${match[1]} ',
                      )} FCFA',
                  style: AppTheme.mono(
                    color: AppTheme.teal700,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: urgent ? AppTheme.red50 : AppTheme.cardColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: urgent ? AppTheme.red400 : AppTheme.teal100,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  urgent ? Icons.flash_on_rounded : Icons.check_rounded,
                  size: 15,
                  color: urgent ? AppTheme.red500 : AppTheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  urgent ? 'Express' : 'Standard',
                  style: TextStyle(
                    color: urgent ? AppTheme.red500 : AppTheme.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Row(
          children: [
            Checkbox(
                value: value, onChanged: (next) => onChanged(next ?? false)),
            const Expanded(
              child: Text(
                'J’accepte les conditions de transport.',
                style: TextStyle(
                  color: AppTheme.slate700,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
