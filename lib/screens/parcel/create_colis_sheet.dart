// lib/screens/parcel/create_colis_sheet.dart
//
// Modal multi-étapes de création d'un colis (client, libre service).
// Étape 1 : Trajet & destinataire.  Étape 2 : Colis & options.  Étape 3 : Récap.

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/user.dart';
import '../../models/voice_message.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

/// Ouvre le modal de création de colis. Renvoie `true` si le colis a été publié.
Future<bool?> showCreateColisSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CreateColisSheet(),
  );
}

class _CreateColisSheet extends ConsumerStatefulWidget {
  const _CreateColisSheet();

  @override
  ConsumerState<_CreateColisSheet> createState() => _CreateColisSheetState();
}

class _CreateColisSheetState extends ConsumerState<_CreateColisSheet> {
  final ApiService _api = ApiService();

  // Pièces jointes (photo / vidéo / note vocale).
  final ImagePicker _picker = ImagePicker();
  final Record _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<XFile> _photos = [];
  final List<XFile> _videos = [];
  final List<VoiceMessage> _voiceMessages = [];
  Timer? _recordingTimer;
  bool _isRecording = false;
  int _recordingDuration = 0;
  String? _playingPath;
  String? _mediaNote;

  int _step = 0;
  bool _loadingGarages = true;
  bool _submitting = false;
  String? _error;

  List<Garage> _garages = [];
  String? _departureId;
  String? _arrivalId;

  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  final _receiverAddress = TextEditingController();
  ParcelType _type = ParcelType.package;
  final _weight = TextEditingController();
  final _description = TextEditingController();
  bool _insurance = true;
  bool _urgent = false;

  // Prix proposé (éditable).
  final _priceController = TextEditingController();
  bool _priceEdited = false;

  // Mode de livraison : 'free' (annonce) ou 'driver' (chauffeur choisi).
  String _mode = 'free';
  String? _driverId;
  List<User> _drivers = [];
  bool _driversLoaded = false;
  bool _loadingDrivers = false;

  int get _estimatedPrice => _urgent ? 14500 : 12500;

  @override
  void initState() {
    super.initState();
    _priceController.text = _estimatedPrice.toString();
    _loadGarages();
  }

  @override
  void dispose() {
    _receiverName.dispose();
    _receiverPhone.dispose();
    _receiverAddress.dispose();
    _weight.dispose();
    _description.dispose();
    _priceController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    for (final voice in _voiceMessages) {
      _deleteLocalFile(voice.path);
    }
    super.dispose();
  }

  // ---- Pièces jointes : capture / enregistrement ----

  Future<void> _pickPhotoFrom(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 82);
      if (file == null || !mounted) return;
      setState(() {
        _photos.add(file);
        _mediaNote = null;
      });
    } catch (error) {
      debugPrint('Erreur sélection photo colis: $error');
      _showMediaNote('Photo indisponible (permission refusée ?)');
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppTheme.primary),
              title: Text('Prendre une photo',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppTheme.primary),
              title: Text('Choisir dans la galerie',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhotoFrom(source);
  }

  Future<void> _pickVideo() async {
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 45),
      );
      if (file == null || !mounted) return;
      setState(() {
        _videos.add(file);
        _mediaNote = null;
      });
    } catch (error) {
      debugPrint('Erreur sélection vidéo colis: $error');
      _showMediaNote('Vidéo indisponible (permission refusée ?)');
    }
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
        _showMediaNote('Permission micro refusée');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/parcel_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
        _mediaNote = null;
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
      _showMediaNote('Enregistrement impossible');
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

  Future<void> _togglePlay(VoiceMessage voice) async {
    try {
      if (_playingPath == voice.path) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playingPath = null);
        return;
      }
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(voice.path));
      if (mounted) setState(() => _playingPath = voice.path);
      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _playingPath = null);
      });
    } catch (error) {
      debugPrint('Erreur lecture audio colis: $error');
      if (mounted) setState(() => _playingPath = null);
    }
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));
  void _removeVideo(int index) => setState(() => _videos.removeAt(index));

  void _removeVoice(int index) {
    final voice = _voiceMessages[index];
    if (_playingPath == voice.path) {
      _audioPlayer.stop();
      _playingPath = null;
    }
    _deleteLocalFile(voice.path);
    setState(() => _voiceMessages.removeAt(index));
  }

  void _deleteLocalFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (error) {
      debugPrint('Erreur suppression fichier local: $error');
    }
  }

  void _showMediaNote(String message) {
    if (!mounted) return;
    setState(() => _mediaNote = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _uploadMediaForParcel(String parcelId) async {
    if (_photos.isEmpty && _videos.isEmpty && _voiceMessages.isEmpty) return;

    for (final photo in _photos) {
      await _api.uploadFile(
          file: photo, mediaType: 'photo', parcelId: parcelId);
    }
    for (final video in _videos) {
      await _api.uploadFile(
          file: video, mediaType: 'video', parcelId: parcelId);
    }
    for (final voice in _voiceMessages) {
      await _api.uploadFile(
          file: XFile(voice.path), mediaType: 'audio', parcelId: parcelId);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDrivers() async {
    if (_driversLoaded || _loadingDrivers) return;
    setState(() => _loadingDrivers = true);
    try {
      final drivers = await _api.searchDriversPublic();
      if (mounted) {
        setState(() {
          _drivers = drivers;
          _driversLoaded = true;
          _loadingDrivers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _driversLoaded = true;
          _loadingDrivers = false;
        });
      }
    }
  }

  void _chooseMode(String mode) {
    setState(() {
      _mode = mode;
      if (mode == 'free') _driverId = null;
    });
    if (mode == 'driver') _loadDrivers();
  }

  User? _driverById(String? id) {
    if (id == null) return null;
    for (final d in _drivers) {
      if (d.id == id) return d;
    }
    return null;
  }

  double get _enteredPrice {
    final raw = _priceController.text.trim().replaceAll(' ', '');
    return double.tryParse(raw) ?? _estimatedPrice.toDouble();
  }

  Future<void> _loadGarages() async {
    try {
      final garages = await _api.getAllGarages();
      if (mounted) {
        setState(() {
          _garages = garages;
          if (garages.isNotEmpty) _departureId = garages.first.id;
          if (garages.length > 1) _arrivalId = garages[1].id;
          _loadingGarages = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGarages = false);
    }
  }

  Garage? _garageById(String? id) {
    if (id == null) return null;
    for (final g in _garages) {
      if (g.id == id) return g;
    }
    return null;
  }

  bool get _step1Valid =>
      _departureId != null &&
      _arrivalId != null &&
      _departureId != _arrivalId &&
      _receiverName.text.trim().isNotEmpty &&
      _receiverPhone.text.trim().isNotEmpty &&
      (_mode != 'driver' || _driverId != null);

  Future<void> _submit() async {
    if (_submitting) return;
    final dep = _garageById(_departureId);
    final arr = _garageById(_arrivalId);
    if (dep == null || arr == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final price = _enteredPrice;
    final driver = _driverById(_driverId);
    final isDriverMode = _mode == 'driver';

    final data = <String, dynamic>{
      'receiverName': _receiverName.text.trim(),
      'receiverPhone': _receiverPhone.text.trim(),
      'receiverAddress': _receiverAddress.text.trim().isEmpty
          ? null
          : _receiverAddress.text.trim(),
      'description': _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      'weight': double.tryParse(_weight.text.trim()) ?? 0,
      'type': _type.value,
      'status': isDriverMode ? 'confirmed' : 'free',
      'departureGarageId': dep.id,
      'departureGarageName': dep.name,
      'arrivalGarageId': arr.id,
      'arrivalGarageName': arr.name,
      'price': price,
      'proposedPrice': price,
      'isUrgent': _urgent,
      'isInsured': _insurance,
      'isFreeForBidding': !isDriverMode,
      'audioUrls': <String>[],
    };

    if (isDriverMode && driver != null) {
      data['driverId'] = driver.id;
      data['driverName'] = driver.fullName;
    }

    final result =
        await ref.read(parcelProvider.notifier).createParcel(data);
    if (!mounted) return;

    if (result != null) {
      // Le spinner reste actif pendant l'envoi des pièces jointes.
      try {
        await _uploadMediaForParcel(result.id);
      } catch (error) {
        debugPrint('Erreur upload médias colis: $error');
      }
      await ref.read(parcelProvider.notifier).loadMyParcels();
      if (!mounted) return;
      setState(() => _submitting = false);
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() => _submitting = false);
      final err = ref.read(parcelProvider).error;
      setState(() => _error = err ?? 'Publication impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                _handle(),
                _header(),
                Expanded(
                  child: _loadingGarages
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary))
                      : SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: _step == 0
                              ? _buildStep1()
                              : _step == 1
                                  ? _buildStep2()
                                  : _buildRecap(),
                        ),
                ),
                _footer(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _handle() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.slate300,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.teal50,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nouveau colis',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Étape ${_step + 1} sur 3 · ${_stepTitle(_step)}',
                    style: GoogleFonts.manrope(
                        fontSize: 12.5, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded, color: AppTheme.slate500),
          ),
        ],
      ),
    );
  }

  String _stepTitle(int step) {
    switch (step) {
      case 0:
        return 'Trajet & destinataire';
      case 1:
        return 'Colis & options';
      default:
        return 'Récapitulatif';
    }
  }

  Widget _stepBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(child: _seg(active: true)),
          const SizedBox(width: 8),
          Expanded(child: _seg(active: _step >= 1)),
          const SizedBox(width: 8),
          Expanded(child: _seg(active: _step >= 2)),
        ],
      ),
    );
  }

  Widget _seg({required bool active}) => Container(
        height: 4,
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.slate200,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepBar(),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Départ'),
                  _garageDropdown(
                    value: _departureId,
                    hint: 'Zone',
                    icon: Icons.trip_origin_rounded,
                    onChanged: (v) => setState(() => _departureId = v),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Arrivée'),
                  _garageDropdown(
                    value: _arrivalId,
                    hint: 'Zone',
                    icon: Icons.pin_drop_rounded,
                    onChanged: (v) => setState(() => _arrivalId = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_departureId != null && _departureId == _arrivalId) ...[
          const SizedBox(height: 12),
          _warning('Le départ et l’arrivée doivent être différents.'),
        ],
        const SizedBox(height: 16),
        _label('Nom du destinataire'),
        _textField(_receiverName, 'Ex : Awa Ndiaye', Icons.badge_rounded),
        const SizedBox(height: 14),
        _label('Téléphone du destinataire'),
        _textField(_receiverPhone, 'Ex : 77 000 00 00', Icons.call_rounded,
            mono: true, phone: true),
        const SizedBox(height: 14),
        _label('Adresse de livraison (optionnel)'),
        _textField(_receiverAddress, 'Quartier, repère…', Icons.home_rounded),
        const SizedBox(height: 18),
        _label('Mode de livraison'),
        _modeTile(
          mode: 'free',
          icon: Icons.campaign_rounded,
          title: 'Publier une annonce',
          desc: 'Les chauffeurs proposent un prix, vous choisissez.',
        ),
        const SizedBox(height: 10),
        _modeTile(
          mode: 'driver',
          icon: Icons.local_shipping_rounded,
          title: 'Confier à un chauffeur',
          desc: 'Choisissez un chauffeur ; il devra confirmer.',
        ),
        if (_mode == 'driver') ...[
          const SizedBox(height: 14),
          _label('Chauffeur'),
          _driverField(),
        ],
      ],
    );
  }

  Widget _modeTile({
    required String mode,
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final selected = _mode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: () => _chooseMode(mode),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.teal50 : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.slate200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : AppTheme.slate100,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon,
                  size: 22,
                  color: selected ? Colors.white : AppTheme.slate500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: GoogleFonts.manrope(
                          fontSize: 12.5, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppTheme.primary : AppTheme.slate300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverField() {
    if (_loadingDrivers) {
      return Text('Chargement des chauffeurs…',
          style: GoogleFonts.manrope(
              fontSize: 13, color: AppTheme.textSecondary));
    }
    if (_drivers.isEmpty) {
      return Text('Aucun chauffeur disponible pour le moment.',
          style: GoogleFonts.manrope(
              fontSize: 13, color: AppTheme.textSecondary));
    }
    return Column(
      children: [
        for (var i = 0; i < _drivers.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _driverCard(_drivers[i]),
        ],
      ],
    );
  }

  // ---- Statut de disponibilité du chauffeur (libellé + couleur) ----
  ({String label, Color color}) _driverStatusMeta(User d) {
    switch (d.driverStatus) {
      case DriverStatus.available:
        return (label: 'Disponible', color: AppTheme.green600);
      case DriverStatus.busy:
        return (label: 'Occupé', color: AppTheme.amber600);
      default:
        return (label: 'Hors ligne', color: AppTheme.slate400);
    }
  }

  Widget _driverAvatar(User d) {
    final statusColor = _driverStatusMeta(d).color;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.teal50,
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: d.hasProfilePhoto
                ? Image.network(
                    d.profilePhoto!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _driverInitials(d),
                  )
                : _driverInitials(d),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                border: Border.all(color: AppTheme.cardColor, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverInitials(User d) => Text(
        d.initials,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.teal700),
      );

  Widget _driverCard(User d) {
    final selected = _driverId == d.id;
    final status = _driverStatusMeta(d);
    final rating = (d.rating ?? 0).toStringAsFixed(1);
    final completed = d.completedDeliveries ?? 0;
    final subtitle = (d.garageName ?? '').trim().isNotEmpty
        ? d.garageName!.trim()
        : ((d.city ?? '').trim().isNotEmpty ? d.city!.trim() : 'Indépendant');
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: () => setState(() => _driverId = selected ? null : d.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.teal50 : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.slate200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _driverAvatar(d),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? AppTheme.primary : AppTheme.slate300,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    size: 16, color: AppTheme.amber500),
                const SizedBox(width: 3),
                Text(rating,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Text('· $completed livr.',
                    style: GoogleFonts.manrope(
                        fontSize: 12.5, color: AppTheme.textSecondary)),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status.color,
                  ),
                ),
                const SizedBox(width: 5),
                Text(status.label,
                    style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: status.color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepBar(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Type'),
                  _typeDropdown(),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Poids (kg)'),
                  _textField(_weight, 'Ex : 5', Icons.scale_rounded,
                      mono: true, number: true),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _label('Description (optionnel)'),
        TextField(
          controller: _description,
          maxLines: 2,
          maxLength: 200,
          style: GoogleFonts.manrope(fontSize: 14),
          decoration: _dec('Ex : documents, fragile…', null),
        ),
        const SizedBox(height: 4),
        _switchRow(
          'Assurer le colis',
          'Couvre jusqu’à 200 000 FCFA',
          _insurance,
          (v) => setState(() => _insurance = v),
        ),
        const PcDivider(),
        _switchRow(
          'Livraison urgente',
          'Supplément 2 000 FCFA',
          _urgent,
          (v) {
            setState(() {
              _urgent = v;
              // Si l'utilisateur n'a pas saisi de prix personnalisé, on met à
              // jour la valeur par défaut selon l'option urgente.
              if (!_priceEdited) _priceController.text = _estimatedPrice.toString();
            });
          },
        ),
        const SizedBox(height: 16),
        // Prix proposé (éditable).
        Row(
          children: [
            Expanded(child: _label('Prix proposé (FCFA)')),
            _urgent ? const PcTag.express() : const PcTag('Standard'),
          ],
        ),
        TextField(
          controller: _priceController,
          onChanged: (_) => setState(() => _priceEdited = true),
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          style: AppTheme.mono(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.teal700),
          decoration: _dec('Ex : $_estimatedPrice', Icons.payments_rounded),
        ),
        const SizedBox(height: 6),
        Text(
          _mode == 'driver'
              ? 'Le montant convenu avec le chauffeur.'
              : 'Indicatif — les chauffeurs peuvent surenchérir.',
          style: GoogleFonts.manrope(
              fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 18),
        _buildAttachments(),
      ],
    );
  }

  Widget _buildRecap() {
    final dep = _garageById(_departureId);
    final arr = _garageById(_arrivalId);
    final driver = _driverById(_driverId);
    final isDriverMode = _mode == 'driver';
    final mediaCount = _photos.length + _videos.length + _voiceMessages.length;
    final priceText =
        '${_enteredPrice.toStringAsFixed(0)} FCFA';
    final address = _receiverAddress.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepBar(),
        Text('Vérifiez avant de publier',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('Un dernier coup d’œil ; touchez « Modifier » pour corriger.',
            style: GoogleFonts.manrope(
                fontSize: 12.5, color: AppTheme.textSecondary)),
        const SizedBox(height: 16),

        // Trajet
        _recapSection(
          icon: Icons.route_rounded,
          title: 'Trajet',
          onEdit: () => setState(() => _step = 0),
          rows: [
            _recapRow('Départ', dep?.city ?? '—'),
            _recapRow('Arrivée', arr?.city ?? '—'),
          ],
        ),
        const SizedBox(height: 12),

        // Destinataire
        _recapSection(
          icon: Icons.person_rounded,
          title: 'Destinataire',
          onEdit: () => setState(() => _step = 0),
          rows: [
            _recapRow('Nom', _receiverName.text.trim().isEmpty
                ? '—'
                : _receiverName.text.trim()),
            _recapRow('Téléphone', _receiverPhone.text.trim().isEmpty
                ? '—'
                : _receiverPhone.text.trim(), mono: true),
            if (address.isNotEmpty) _recapRow('Adresse', address),
          ],
        ),
        const SizedBox(height: 12),

        // Livraison
        _recapSection(
          icon: Icons.local_shipping_rounded,
          title: 'Livraison',
          onEdit: () => setState(() => _step = 0),
          rows: [
            _recapRow(
              'Mode',
              isDriverMode
                  ? 'Chauffeur · ${driver?.fullName ?? '—'}'
                  : 'Annonce (ouverte aux offres)',
            ),
            if (isDriverMode)
              _recapRow('Statut', 'En attente de confirmation du chauffeur'),
          ],
        ),
        const SizedBox(height: 12),

        // Colis
        _recapSection(
          icon: Icons.inventory_2_rounded,
          title: 'Colis',
          onEdit: () => setState(() => _step = 1),
          rows: [
            _recapRow('Type', _type.label),
            _recapRow(
                'Poids',
                _weight.text.trim().isEmpty
                    ? '—'
                    : '${_weight.text.trim()} kg'),
            _recapRow('Prix', priceText, mono: true),
            if (_description.text.trim().isNotEmpty)
              _recapRow('Description', _description.text.trim()),
          ],
          footer: (_urgent || _insurance || mediaCount > 0)
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (_urgent) const PcTag.express(),
                      if (_insurance)
                        _recapChip(Icons.verified_user_rounded, 'Assuré'),
                      if (mediaCount > 0)
                        _recapChip(Icons.attachment_rounded,
                            '$mediaCount pièce${mediaCount > 1 ? 's' : ''} jointe${mediaCount > 1 ? 's' : ''}'),
                    ],
                  ),
                )
              : null,
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          _warning(_error!, danger: true),
        ],
      ],
    );
  }

  Widget _recapSection({
    required IconData icon,
    required String title,
    required VoidCallback onEdit,
    required List<Widget> rows,
    Widget? footer,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                onTap: onEdit,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded,
                          size: 15, color: AppTheme.primary),
                      const SizedBox(width: 3),
                      Text('Modifier',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows,
          if (footer != null) footer,
        ],
      ),
    );
  }

  Widget _recapRow(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.manrope(
                  fontSize: 12.5, color: AppTheme.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: mono
                  ? AppTheme.mono(
                      fontSize: 13, fontWeight: FontWeight.w700)
                  : GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recapChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.teal50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.teal700),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.teal700)),
        ],
      ),
    );
  }

  Widget _buildAttachments() {
    final hasItems = _photos.isNotEmpty ||
        _videos.isNotEmpty ||
        _voiceMessages.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_file_rounded,
                size: 18, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text('Pièces jointes',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700)),
            const SizedBox(width: 6),
            Text('(optionnel)',
                style: GoogleFonts.manrope(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _mediaTile(
                icon: Icons.photo_camera_rounded,
                label: 'Photo',
                onTap: _choosePhotoSource,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _mediaTile(
                icon: Icons.videocam_rounded,
                label: 'Vidéo',
                onTap: _pickVideo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _mediaTile(
                icon: _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                label: _isRecording
                    ? _formatDuration(_recordingDuration)
                    : 'Vocal',
                onTap: _toggleRecording,
                active: _isRecording,
              ),
            ),
          ],
        ),
        if (_mediaNote != null) ...[
          const SizedBox(height: 8),
          Text(_mediaNote!,
              style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.red400)),
        ],
        if (hasItems) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _photos.length; i++)
                _mediaChip(
                  imagePath: _photos[i].path,
                  icon: Icons.image_rounded,
                  label: 'Photo ${i + 1}',
                  onRemove: () => _removePhoto(i),
                ),
              for (var i = 0; i < _videos.length; i++)
                _mediaChip(
                  icon: Icons.videocam_rounded,
                  label: 'Vidéo ${i + 1}',
                  onRemove: () => _removeVideo(i),
                ),
              for (var i = 0; i < _voiceMessages.length; i++)
                _voiceChip(_voiceMessages[i], i),
            ],
          ),
        ],
      ],
    );
  }

  Widget _mediaTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final color = active ? AppTheme.red500 : AppTheme.primary;
    final bg = active ? AppTheme.red50 : AppTheme.teal50;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 5),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaChip({
    String? imagePath,
    required IconData icon,
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      width: 104,
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
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 88,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                clipBehavior: Clip.antiAlias,
                child: imagePath == null
                    ? Icon(icon, color: AppTheme.primary, size: 26)
                    : Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        width: 88,
                        height: 54,
                        errorBuilder: (_, __, ___) =>
                            Icon(icon, color: AppTheme.primary, size: 26),
                      ),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cancel_rounded,
                        color: AppTheme.red500, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate700)),
        ],
      ),
    );
  }

  Widget _voiceChip(VoiceMessage voice, int index) {
    final playing = _playingPath == voice.path;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppTheme.teal50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.teal100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _togglePlay(voice),
            borderRadius: BorderRadius.circular(20),
            child: Icon(
              playing
                  ? Icons.stop_circle_rounded
                  : Icons.play_circle_fill_rounded,
              color: AppTheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 6),
          Text(_formatDuration(voice.duration),
              style: AppTheme.mono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.teal700)),
          IconButton(
            onPressed: () => _removeVoice(index),
            icon: const Icon(Icons.cancel_rounded),
            color: AppTheme.red500,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: _step == 0
          ? PcButton(
              'Suivant',
              iconTrailing: Icons.arrow_forward_rounded,
              size: PcButtonSize.lg,
              block: true,
              onPressed:
                  _step1Valid ? () => setState(() => _step = 1) : null,
            )
          : _step == 1
              ? Row(
                  children: [
                    Expanded(
                      child: PcButton(
                        'Précédent',
                        variant: PcButtonVariant.secondary,
                        size: PcButtonSize.lg,
                        block: true,
                        onPressed: () => setState(() => _step = 0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: PcButton(
                        'Vérifier',
                        iconTrailing: Icons.arrow_forward_rounded,
                        size: PcButtonSize.lg,
                        block: true,
                        onPressed: () => setState(() => _step = 2),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: PcButton(
                        'Précédent',
                        variant: PcButtonVariant.secondary,
                        size: PcButtonSize.lg,
                        block: true,
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _step = 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: PcButton(
                        _mode == 'driver'
                            ? 'Confier le colis'
                            : 'Publier en libre service',
                        icon: _mode == 'driver'
                            ? Icons.local_shipping_rounded
                            : Icons.sell_rounded,
                        size: PcButtonSize.lg,
                        block: true,
                        loading: _submitting,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
    );
  }

  // ---- Helpers ----

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate700)),
      );

  InputDecoration _dec(String hint, IconData? icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(fontSize: 14, color: AppTheme.slate400),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: AppTheme.slate400)
            : null,
        filled: true,
        fillColor: AppTheme.cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        counterText: '',
      );

  Widget _textField(TextEditingController c, String hint, IconData icon,
      {bool mono = false, bool number = false, bool phone = false}) {
    return TextField(
      controller: c,
      onChanged: (_) => setState(() {}),
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : (phone ? TextInputType.phone : TextInputType.text),
      style: mono
          ? AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w600)
          : GoogleFonts.manrope(fontSize: 14),
      decoration: _dec(hint, icon),
    );
  }

  Widget _garageDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded, color: AppTheme.slate500),
      decoration: _dec(hint, icon),
      style: GoogleFonts.manrope(fontSize: 13.5, color: AppTheme.textPrimary),
      items: _garages
          .map((g) => DropdownMenuItem(
                value: g.id,
                child: Text(g.city, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _typeDropdown() {
    return DropdownButtonFormField<ParcelType>(
      initialValue: _type,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded, color: AppTheme.slate500),
      decoration: _dec('', Icons.category_rounded),
      style: GoogleFonts.manrope(fontSize: 13.5, color: AppTheme.textPrimary),
      items: ParcelType.values
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(t.label, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) => setState(() => _type = v ?? ParcelType.package),
    );
  }

  Widget _switchRow(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.manrope(
                        fontSize: 12.5, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _warning(String text, {bool danger = false}) {
    final color = danger ? AppTheme.red400 : AppTheme.amber600;
    final bg = danger ? AppTheme.red50 : AppTheme.amber50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Icon(danger ? Icons.error_rounded : Icons.warning_amber_rounded,
              size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
        ],
      ),
    );
  }
}
