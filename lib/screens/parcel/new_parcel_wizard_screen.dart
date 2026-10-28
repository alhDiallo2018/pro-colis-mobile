import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../services/api/experience_api.dart';
import '../../services/form_draft_store.dart';
import '../../models/driver_discovery.dart';
import '../../widgets/delivery_discovery_view.dart';
// 4-step parcel creation wizard matching the web app
// Trajet et disponibilité → Colis et prix proposé → Destinataire → Confirmation

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/payment.dart';
import '../../models/user.dart';
import '../../models/zone.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api/client.dart';
import '../../services/api/parcels_api.dart';
import '../../services/api/zones_api.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/debt_block.dart';
import '../../widgets/payment_channel_selector.dart';
import '../../widgets/pay_client_debt_sheet.dart';
import '../../widgets/phone_contact_picker.dart';
import '../../widgets/procolis_design_system.dart';
import '../../widgets/location_autocomplete.dart';

final _apiService = ApiService();

// Tous les accès à la création utilisent le même parcours cartographique.
Future<bool?> showDeliveryCreation(BuildContext context) async {
  final result = await Navigator.of(context).push<Parcel>(
    MaterialPageRoute(builder: (_) => const NewParcelWizardScreen()),
  );
  return result != null;
}

class NewParcelWizardScreen extends ConsumerStatefulWidget {
  /// Chauffeur pré-sélectionné depuis une fiche (accès direct `/parcel/new?driver=`).
  final String? preselectedDriverId;
  final String? sourceParcelId;
  final String? sourceDraftId;
  final String? recipientId;

  const NewParcelWizardScreen(
      {super.key,
      this.preselectedDriverId,
      this.sourceParcelId,
      this.sourceDraftId,
      this.recipientId});

  @override
  ConsumerState<NewParcelWizardScreen> createState() =>
      _NewParcelWizardScreenState();
}

class _NewParcelWizardScreenState extends ConsumerState<NewParcelWizardScreen> {
  late final FormDraftStore _draftStore;
  Timer? _draftTimer;
  Map<String, dynamic>? _pendingData;
  String? _restoreError;
  bool _draftReady = false;
  bool _sourceApplied = false;
  Parcel? _createdParcel;
  late final FormDraftStore _outbox;
  Map<String, dynamic>? _pendingRequest;
  final String _attemptId = const Uuid().v4();
  bool _started = false;
  void _event(String event) {
    unawaited(ExperienceApi().request('/events', method: 'POST', data: {
      'attemptId': _pendingRequest?['requestId'] ?? _attemptId,
      'event': event,
      'platform': 'mobile'
    }).catchError((_) => <String, dynamic>{}));
  }

  List<TextEditingController> get _draftControllers => [
        _receiverNameCtrl,
        _receiverPhoneCtrl,
        _receiverEmailCtrl,
        _receiverAddressCtrl,
        _descriptionCtrl,
        _weightCtrl,
        _proposedPriceCtrl
      ];

  Map<String, dynamic> _draftData() => {
        'receiverName': _receiverNameCtrl.text,
        'receiverPhone': _receiverPhoneCtrl.text,
        'receiverEmail': _receiverEmailCtrl.text,
        'receiverAddress': _receiverAddressCtrl.text,
        'description': _descriptionCtrl.text,
        'weight': _weightCtrl.text,
        'price': _proposedPriceCtrl.text,
        'departureZoneId': _departureZoneId,
        'arrivalZoneId': _arrivalZoneId,
        'type': _parcelType.value,
        'isUrgent': _isUrgent,
        'isInsured': _isInsured,
        'photos': _photos.map((f) => f.path).toList(),
        'videos': _videos.map((f) => f.path).toList(),
        'voices': _voiceMessages
            .map((v) => {'path': v.path, 'duration': v.duration})
            .toList(),
      };
  Future<void> _saveDraft() async {
    if (!_draftReady ||
        _pendingData != null ||
        _pendingRequest != null ||
        _isPublishing) return;
    final data = _draftData();
    if (_draftControllers.any((c) => c.text.isNotEmpty))
      await _draftStore.save(data);
  }

  void _draftChanged() {
    if (!_started) {
      _started = true;
      _event('creation_started');
    }
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), _saveDraft);
  }

  Future<void> _loadDraft() async {
    try {
      final pending = (await _outbox.load())?.data;
      if (pending != null && mounted) {
        setState(() {
          _pendingRequest = pending;
          _draftReady = true;
        });
        return;
      }
      final external = widget.sourceParcelId != null ||
          widget.sourceDraftId != null ||
          widget.recipientId != null;
      final data = external
          ? await ExperienceApi().prefill(
              source: widget.sourceParcelId,
              draft: widget.sourceDraftId,
              recipient: widget.recipientId)
          : (await _draftStore.load())?.data;
      if (mounted)
        setState(() {
          _pendingData = data;
          _draftReady = true;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _draftReady = true;
          _restoreError =
              'Impossible de reprendre cet envoi. Réessayez avec une connexion.';
        });
    }
  }

  void _restore() {
    final data = _pendingData;
    if (data == null) return;
    setState(() {
      _receiverNameCtrl.text = data['receiverName']?.toString() ?? '';
      _receiverPhoneCtrl.text = data['receiverPhone']?.toString() ?? '';
      _receiverEmailCtrl.text = data['receiverEmail']?.toString() ?? '';
      _receiverAddressCtrl.text = data['receiverAddress']?.toString() ?? '';
      _descriptionCtrl.text = data['description']?.toString() ?? '';
      _weightCtrl.text = data['weight']?.toString() ?? '';
      _proposedPriceCtrl.text = data['price']?.toString() ?? '';
      _departureZoneId = data['departureZoneId'] as String?;
      _arrivalZoneId = data['arrivalZoneId'] as String?;
      _parcelType =
          ParcelType.values.where((v) => v.value == data['type']).firstOrNull ??
              ParcelType.package;
      _isUrgent = data['isUrgent'] == true;
      _isInsured = data['isInsured'] == true;
      _isFreeMode = true;
      _selectedDriver = null;
      _currentStep = 0;
      _sourceApplied = widget.sourceDraftId != null;
      _photos = (data['photos'] as List? ?? [])
          .cast<String>()
          .where((p) => File(p).existsSync())
          .map(XFile.new)
          .toList();
      _videos = (data['videos'] as List? ?? [])
          .cast<String>()
          .where((p) => File(p).existsSync())
          .map(XFile.new)
          .toList();
      _voiceMessages = (data['voices'] as List? ?? [])
          .where((v) => File(v['path']).existsSync())
          .map(
              (v) => VoiceMessageData(path: v['path'], duration: v['duration']))
          .toList();
      _pendingData = null;
    });
    _showSnack(
        'Informations reprises. Vérifiez les étapes, le chauffeur, le prix et les pièces jointes avant de publier.');
  }

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
  List<Garage> _zones = [];
  String? _departureZoneId;
  String? _arrivalZoneId;

  bool _isFreeMode = false;
  User? _selectedDriver;
  String? _vehicleFilter;

  // Step 2 - Colis
  ParcelType _parcelType = ParcelType.package;
  final _weightCtrl = TextEditingController();
  final _proposedPriceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _isUrgent = false;
  bool _isInsured = false;

  // Le barème reste exclusivement côté API. Le délai évite une requête à
  // chaque caractère pendant la saisie du poids.
  final ParcelsApi _parcelsApi = ParcelsApi(ApiClient());
  Timer? _estimateTimer;
  int _estimateGeneration = 0;
  ParcelEstimate? _parcelEstimate;
  bool _priceEdited = false;

  // Règlement : espèces de la main à la main, ou encaissement par la plateforme.
  PaymentChannel _paymentChannel = PaymentChannel.cash;
  CashCollectionPoint _cashCollectionPoint =
      CashCollectionPoint.receiverDelivery;

  List<XFile> _photos = [];
  List<XFile> _videos = [];
  List<VoiceMessageData> _voiceMessages = [];

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _draftStore = FormDraftStore(
        slot: 'parcel-wizard', ownerId: ref.read(authProvider).user?.id);
    _outbox = FormDraftStore(
        slot: 'parcel-outbox',
        ownerId: ref.read(authProvider).user?.id,
        allowExpired: true);
    _loadDraft();
    for (final controller in _draftControllers) {
      controller.addListener(_draftChanged);
    }
    _loadZones();
    _applyPreselectedDriver();
    _weightCtrl.addListener(_scheduleEstimate);
  }

  Future<void> _applyPreselectedDriver() async {
    final id = widget.preselectedDriverId;
    if (id == null || id.isEmpty) return;
    // Avant le premier build : affectation directe, pas de setState.
    _isFreeMode = false;
    try {
      final driver = await _apiService.getPublicDriver(id);
      if (mounted &&
          driver != null &&
          driver.driverStatus == DriverStatus.available) {
        setState(() => _selectedDriver = driver);
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[NewParcelWizard] Échec chargement chauffeur: $error\n$stackTrace',
      );
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    // Capturer le texte avant de libérer les contrôleurs. Ne jamais sauvegarder
    // de nouveau le formulaire une fois que le serveur a créé le colis.
    unawaited(_saveDraft());
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    _receiverEmailCtrl.dispose();
    _receiverAddressCtrl.dispose();
    _weightCtrl.dispose();
    _proposedPriceCtrl.dispose();
    _descriptionCtrl.dispose();
    _estimateTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _importReceiverFromContacts() async {
    final contact = await showPhoneContactPicker(
      context: context,
      selectedPhone: _receiverPhoneCtrl.text,
    );
    if (!mounted || contact == null) return;

    // Le carnet remplit les deux champs liés au destinataire en une seule
    // opération, tout en les laissant modifiables avant publication.
    setState(() {
      _receiverNameCtrl.text = contact.contactName;
      _receiverPhoneCtrl.text = contact.phoneNumber;
    });
  }

  Future<void> _loadZones() async {
    try {
      final zones = await _apiService.getAllZones();
      if (mounted) setState(() => _zones = zones);
    } catch (error, stackTrace) {
      debugPrint(
        '[NewParcelWizard] Échec chargement zones: $error\n$stackTrace',
      );
    }
  }

  Future<void> _detectZoneFromCoordinates(double lat, double lng) async {
    setState(() {
      _detectingZone = true;
      _detectedZone = null;
    });
    try {
      final zones = await _zonesApi.detectZones(lat, lng);
      if (!mounted) return;
      setState(() {
        _detectingZone = false;
        _detectedZone = zones.isNotEmpty ? zones.first : null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[NewParcelWizard] Échec détection zone: $error\n$stackTrace',
      );
      if (mounted) setState(() => _detectingZone = false);
    }
  }

  void _scheduleEstimate() {
    _estimateTimer?.cancel();
    _estimateTimer = Timer(
      const Duration(milliseconds: 500),
      _refreshEstimate,
    );
  }

  /// Charge le prix suggéré et ses suppléments auprès du serveur. Si l'appel
  /// échoue, aucun montant de remplacement n'est inventé côté mobile.
  Future<void> _refreshEstimate() async {
    final generation = ++_estimateGeneration;
    final weight = double.tryParse(
      _weightCtrl.text.trim().replaceAll(',', '.'),
    );
    if (weight == null || weight <= 0) {
      if (!mounted) return;
      setState(() => _parcelEstimate = null);
      if (!_priceEdited) _proposedPriceCtrl.clear();
      return;
    }

    // Ne jamais conserver le tarif d'une ancienne saisie lorsqu'une nouvelle
    // requête échoue ou répond plus tard que la suivante.
    if (mounted) {
      setState(() => _parcelEstimate = null);
      if (!_priceEdited) _proposedPriceCtrl.clear();
    }

    final estimate = await _parcelsApi.estimate(
      weight: weight,
      isUrgent: _isUrgent,
      isInsured: _isInsured,
    );
    if (!mounted || estimate == null || generation != _estimateGeneration) {
      return;
    }

    setState(() => _parcelEstimate = estimate);
    if (!_priceEdited) {
      _proposedPriceCtrl.text = estimate.amount.round().toString();
    }
  }

  Garage? _zoneById(String? id) {
    if (id == null) return null;
    try {
      return _zones.firstWhere((z) => z.id == id);
    } catch (_) {
      return null;
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
  }

  bool _canProceed(int step) {
    switch (step) {
      case 2:
        return _receiverNameCtrl.text.trim().isNotEmpty &&
            _receiverPhoneCtrl.text.trim().isNotEmpty;
      case 0:
        return _departureZoneId != null &&
            _arrivalZoneId != null &&
            _departureZoneId != _arrivalZoneId &&
            (_isFreeMode || _selectedDriver != null);
      case 1:
        final weight = double.tryParse(
          _weightCtrl.text.trim().replaceAll(',', '.'),
        );
        final price = double.tryParse(
          _proposedPriceCtrl.text.trim().replaceAll(',', '.'),
        );
        return weight != null && weight > 0 && price != null && price > 0;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (!_canProceed(_currentStep)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez remplir tous les champs requis')),
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
    final files = await picker.pickMultiImage(
        maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    if (files.isNotEmpty) {
      final paths = await _draftStore.adoptAll(files.map((f) => f.path));
      if (!mounted) return;
      setState(() => _photos = [..._photos, ...paths.map(XFile.new)]);
      if (paths.length != files.length)
        _showSnack(
            'Certaines photos n’ont pas pu être conservées. Ajoutez-les à nouveau.');
      _draftChanged();
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80);
    if (file != null) {
      final path = await _draftStore.adoptMedia(file.path);
      if (!mounted) return;
      if (path == null) {
        _showSnack('Photo non enregistrée. Réessayez.');
        return;
      }
      setState(() => _photos = [..._photos, XFile(path)]);
      _draftChanged();
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      final path = await _draftStore.adoptMedia(file.path);
      if (!mounted) return;
      if (path == null) {
        _showSnack('Vidéo non enregistrée. Réessayez.');
        return;
      }
      setState(() => _videos = [..._videos, XFile(path)]);
      _draftChanged();
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final recorded = await _recorder.stop();
      final path =
          recorded == null ? null : await _draftStore.adoptMedia(recorded);
      if (!mounted) return;
      _isRecording = false;
      if (path != null) {
        setState(() {
          _voiceMessages
              .add(VoiceMessageData(path: path, duration: _recordDuration));
          _recordDuration = 0;
        });
        _draftChanged();
      }
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100),
          path: filePath,
        );
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
        _draftChanged();
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
    if (_isPublishing) return;
    if (!_draftReady || _restoreError != null) {
      _showSnack(
          'Rouvrez ce formulaire pour vérifier la reprise de votre envoi.');
      return;
    }
    if (_pendingRequest != null) {
      await _resumePending();
      return;
    }
    final capacity = _selectedDriver?.vehicleCapacity ?? 0;
    final capacityWeight =
        double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? 0;
    if (!_isFreeMode && capacity > 0 && capacityWeight > capacity) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Le poids dépasse la capacité du véhicule. Choisissez un autre chauffeur.')));
      return;
    }
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    final proposedPrice = double.tryParse(
          _proposedPriceCtrl.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    final description = _descriptionCtrl.text.trim();

    setState(() => _isPublishing = true);

    try {
      final parcelData = {
        if (_sourceApplied && widget.sourceDraftId != null)
          'sourceDraftId': widget.sourceDraftId,
        'senderId': user.id,
        'senderName': user.fullName,
        'senderPhone': user.phone,
        'senderEmail': user.email,
        'receiverName': _receiverNameCtrl.text.trim(),
        'receiverPhone': _receiverPhoneCtrl.text.trim(),
        'receiverEmail': _receiverEmailCtrl.text.trim().isEmpty
            ? null
            : _receiverEmailCtrl.text.trim(),
        'receiverAddress': _receiverAddressCtrl.text.trim(),
        'description': description.isEmpty ? null : description,
        'weight': weight,
        'type': _parcelType.value,
        'status': _isFreeMode ? 'free' : 'negotiating',
        'departureZoneId': _departureZoneId,
        'arrivalZoneId': _arrivalZoneId,
        'proposedPrice': proposedPrice,
        'price': proposedPrice,
        'isUrgent': _isUrgent,
        'isInsured': _isInsured,
        'isFreeForBidding': _isFreeMode,
        // Le canal fait foi ; `paymentMethod` reste envoyé pour la compatibilité.
        'paymentChannel': _paymentChannel.value,
        'paymentMethod': _paymentChannel.defaultMethod.value,
        if (_paymentChannel.isCash)
          'cashCollectionPoint': _cashCollectionPoint.value,
        if (!_isFreeMode && _selectedDriver != null)
          'driverId': _selectedDriver!.id,
        if (!_isFreeMode && _vehicleFilter != null)
          'vehicleType': _vehicleFilter,
      };

      // Le contenu et les identifiants restent figés jusqu'à confirmation : une
      // fermeture de l'app après commit serveur rejoue la même demande.
      final media = <Map<String, dynamic>>[];
      for (final entry in [
        ..._photos.map((f) => {'path': f.path, 'kind': 'photo'}),
        ..._videos.map((f) => {'path': f.path, 'kind': 'video'}),
        ..._voiceMessages.map((v) => {'path': v.path, 'kind': 'audio'}),
      ]) {
        final path = await _outbox.adoptMedia(entry['path']!);
        if (path == null) throw StateError('Pièce jointe non enregistrée');
        media.add(
            {...entry, 'path': path, 'id': const Uuid().v4(), 'sent': false});
      }
      final pending = {
        'requestId': _attemptId,
        'payload': parcelData,
        'media': media
      };
      await _outbox.saveOrThrow(pending);
      _pendingRequest = pending;
      await _sendPending();
    } catch (e, stackTrace) {
      debugPrint(
        '[NewParcelWizard] Échec publication colis: $e\n$stackTrace',
      );
      if (mounted)
        _showSnack(_createdParcel != null
            ? 'Colis créé. Certaines pièces jointes restent à envoyer ; vous pouvez réessayer.'
            : 'Création non confirmée. Vérifiez la connexion et vos colis avant de réessayer.');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _resumePending() async {
    if (_isPublishing) return;
    setState(() => _isPublishing = true);
    try {
      await _sendPending();
    } catch (_) {
      if (mounted)
        _showSnack(
            'Envoi non confirmé. Votre demande est conservée ; vous pouvez réessayer.');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _sendPending() async {
    final pending = _pendingRequest!;
    final notifier = ref.read(parcelProvider.notifier);
    final ownerId = ref.read(authProvider).user?.id;
    void checkAccount() {
      if (!mounted || ref.read(authProvider).user?.id != ownerId)
        throw StateError('Session interrompue');
    }

    if (pending['parcel'] == null) {
      _event('creation_submitted');
      final result = await notifier.createParcel({
        ...Map<String, dynamic>.from(pending['payload']),
        'requestId': pending['requestId']
      });
      if (result == null) {
        _event('creation_failed');
        final failure = notifier.lastCreationError;
        // Seuls les refus explicites avant création libèrent la demande.
        // Une erreur réseau garde la clé et le contenu pour une reprise sûre.
        if (failure != null && [400, 422].contains(failure.statusCode)) {
          await _outbox.clear();
          _pendingRequest = null;
        }
        final debt = payableClientDebtFrom(failure);
        if (mounted)
          _showSnack(failure?.message ?? 'Création non confirmée. Réessayez.');
        if (debt != null && mounted)
          await showPayClientDebtSheet(context,
              debt: debt, onRefresh: () async {});
        return;
      }
      checkAccount();
      pending['parcel'] = result.toJson();
      await _outbox.saveOrThrow(pending);
      _event('creation_completed');
    }
    final parcel =
        Parcel.fromJson(Map<String, dynamic>.from(pending['parcel']));
    _createdParcel = parcel;
    for (final item in pending['media'] as List) {
      checkAccount();
      if (item['sent'] == true) continue;
      final url = await _apiService.uploadFile(
          file: XFile(item['path']),
          mediaType: item['kind'],
          parcelId: parcel.id,
          requestId: item['id']);
      if (url == null) throw StateError('Pièce jointe non envoyée');
      checkAccount();
      item['sent'] = true;
      await _outbox.saveOrThrow(pending);
    }
    _draftTimer?.cancel();
    await _draftStore.clear();
    await _outbox.clear();
    _pendingRequest = null;
    await notifier.loadSentParcels();
    if (mounted) {
      _showSnack('Envoi confirmé. Retrouvez son suivi dans vos colis.');
      Navigator.pop(context, parcel);
    }
  }

  String get _modeLabel =>
      _isFreeMode ? 'Publier une annonce' : 'Proposer à un chauffeur';

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
          if (_restoreError != null)
            Padding(
                padding: const EdgeInsets.all(12), child: Text(_restoreError!)),
          if (_pendingData != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Des informations sont disponibles.'),
                      TextButton(
                          onPressed: _restore, child: const Text('Reprendre')),
                      TextButton(
                          onPressed: () {
                            setState(() => _pendingData = null);
                            _draftStore.clear();
                          },
                          child: const Text('Ignorer')),
                    ])),
          if (_createdParcel != null)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  const Text(
                      'Le colis est créé. Vous pouvez réessayer les pièces jointes ou ouvrir son récapitulatif.'),
                  TextButton(
                      onPressed: _isPublishing
                          ? null
                          : () => Navigator.pop(context, _createdParcel),
                      child: const Text(
                          'Terminer sans les pièces jointes restantes')),
                ])),
          if (_pendingRequest != null)
            MaterialBanner(
                content: const Text(
                    'Un envoi reste à confirmer. Reprenez-le pour retrouver le même colis et terminer ses pièces jointes.'),
                actions: [
                  TextButton(
                      onPressed: _isPublishing ? null : _resumePending,
                      child: const Text('Reprendre l’envoi')),
                ]),
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
    final steps = ['Trajet', 'Colis', 'Destinataire', 'Confirmation'];
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
          final textColor =
              isActive || isDone ? AppTheme.textPrimary : AppTheme.slate400;
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
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? AppTheme.primary
                                      : AppTheme.slate400,
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
      case 2:
        return _buildDestinataire();
      case 0:
        return _buildLivraison();
      case 1:
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
        OutlinedButton.icon(
          onPressed: _importReceiverFromContacts,
          icon: const Icon(Icons.contact_phone_rounded),
          label: const Text('Choisir dans mes contacts'),
        ),
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
      return Row(
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
    final label =
        zone.displayName?.isNotEmpty == true ? zone.displayName! : zone.name;
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
          Icon(Icons.explore_rounded, size: 16, color: AppTheme.teal600),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Zone détectée : $label',
              style: TextStyle(
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

  Widget _buildLivraison() => DeliveryDiscoveryView(
        zones: _zones,
        initial: DeliveryDiscoverySelection(
            pickup: _zoneById(_departureZoneId),
            destination: _zoneById(_arrivalZoneId),
            driver: _selectedDriver,
            vehicleType: _vehicleFilter,
            weight: double.tryParse(_weightCtrl.text.replaceAll(',', '.')),
            openForOffers: _isFreeMode),
        onChanged: (selection) {
          // Les points précis créés sur carte ne sont pas toujours dans la liste
          // publique : les conserver localement préserve le trajet au récapitulatif.
          setState(() {
            for (final place in [selection.pickup, selection.destination]
                .whereType<Garage>()) {
              _zones = [..._zones.where((zone) => zone.id != place.id), place];
            }
            _departureZoneId = selection.pickup?.id;
            _arrivalZoneId = selection.destination?.id;
            _selectedDriver = selection.driver;
            _vehicleFilter = selection.vehicleType;
            _isFreeMode = selection.openForOffers;
            final weight = selection.weight?.toString() ?? '';
            if (_weightCtrl.text != weight) _weightCtrl.text = weight;
          });
        },
      );

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    Icon(t.$2,
                        size: 16,
                        color: selected ? AppTheme.primary : AppTheme.slate500),
                    const SizedBox(width: 6),
                    Text(t.$3,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textPrimary)),
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
                onChanged: (_) => _priceEdited = true,
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
          onChanged: (v) {
            setState(() => _isUrgent = v);
            _refreshEstimate();
          },
          title: const Text('Express / Urgent',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            _isUrgent && (_parcelEstimate?.urgentFee ?? 0) > 0
                ? 'Livraison prioritaire (+${_parcelEstimate!.urgentFee.toStringAsFixed(0)} FCFA)'
                : 'Livraison prioritaire — tarif calculé par la plateforme',
          ),
          activeThumbColor: AppTheme.red400,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          value: _isInsured,
          onChanged: (v) {
            setState(() => _isInsured = v);
            _refreshEstimate();
          },
          title: const Text('Assurance',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            _isInsured && (_parcelEstimate?.insuranceFee ?? 0) > 0
                ? 'Protection (+${_parcelEstimate!.insuranceFee.toStringAsFixed(0)} FCFA)'
                : 'Protection selon les conditions de la plateforme',
          ),
          activeThumbColor: AppTheme.green500,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 20),
        _sectionHeader('Paiement', Icons.payments_rounded),
        const SizedBox(height: 8),
        PaymentChannelField(
          value: _paymentChannel,
          onChanged: (channel) => setState(() => _paymentChannel = channel),
          footnote: _isFreeMode
              ? 'Les chauffeurs qui n’acceptent pas ce mode ne pourront pas '
                  'répondre à votre annonce.'
              : 'Le chauffeur doit accepter ce mode pour confirmer la course.',
        ),
        if (_paymentChannel.isCash) ...[
          const SizedBox(height: 16),
          CashCollectionPointField(
            value: _cashCollectionPoint,
            onChanged: (point) => setState(() => _cashCollectionPoint = point),
          ),
        ],
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
          Text('${_photos.length} photo(s)',
              style: TextStyle(fontSize: 12, color: AppTheme.slate500)),
        ],
        if (_voiceMessages.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${_voiceMessages.length} message(s) vocal(aux)',
              style: TextStyle(fontSize: 12, color: AppTheme.slate500)),
        ],
      ],
    );
  }

  Widget _mediaButton(IconData icon, String label, VoidCallback onTap,
      {bool highlight = false}) {
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
            Icon(icon,
                size: 20,
                color: highlight ? AppTheme.red400 : AppTheme.primary),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: highlight ? AppTheme.red400 : AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecap() {
    final departure = _zoneById(_departureZoneId);
    final arrival = _zoneById(_arrivalZoneId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('Récapitulatif', Icons.receipt_long_rounded),
        const SizedBox(height: 12),
        _recapSection(
            'Destinataire',
            Icons.person_pin_rounded,
            [
              _recapRow('Nom', _receiverNameCtrl.text.trim()),
              _recapRow('Téléphone', _receiverPhoneCtrl.text.trim()),
              if (_receiverEmailCtrl.text.trim().isNotEmpty)
                _recapRow('Email', _receiverEmailCtrl.text.trim()),
              if (_receiverAddressCtrl.text.trim().isNotEmpty)
                _recapRow('Adresse', _receiverAddressCtrl.text.trim()),
            ],
            onEdit: () => _goToStep(2)),
        const SizedBox(height: 12),
        _recapSection(
            'Livraison',
            Icons.route_rounded,
            [
              _recapRow('Départ', departure?.name ?? '-'),
              _recapRow('Arrivée', arrival?.name ?? '-'),
              _recapRow('Mode', _modeLabel),
              if (!_isFreeMode && _selectedDriver != null)
                _recapRow('Chauffeur', _selectedDriver!.fullName),
            ],
            onEdit: () => _goToStep(0)),
        const SizedBox(height: 12),
        _recapSection(
            'Colis',
            Icons.tune_rounded,
            [
              _recapRow('Type', _parcelType.label),
              _recapRow('Poids', '${_weightCtrl.text.trim()} kg'),
              if (_proposedPriceCtrl.text.trim().isNotEmpty)
                _recapRow('Prix', '${_proposedPriceCtrl.text.trim()} FCFA'),
              _recapRow(
                'Paiement',
                _paymentChannel.isCash
                    ? '${_paymentChannel.label} · ${_cashCollectionPoint.payerLabel.toLowerCase()}'
                    : _paymentChannel.label,
              ),
              if (_descriptionCtrl.text.trim().isNotEmpty)
                _recapRow('Description', _descriptionCtrl.text.trim()),
              _recapBadgeRow(
                'Express',
                _isUrgent,
                (_parcelEstimate?.urgentFee ?? 0) > 0
                    ? 'Oui (+${_parcelEstimate!.urgentFee.toStringAsFixed(0)} FCFA)'
                    : 'Oui',
                'Non',
              ),
              _recapBadgeRow('Assurance', _isInsured, 'Oui', 'Non'),
            ],
            onEdit: () => _goToStep(1)),
        if (_photos.isNotEmpty || _voiceMessages.isNotEmpty) ...[
          const SizedBox(height: 12),
          _recapSection('Médias', Icons.perm_media_rounded, [
            if (_photos.isNotEmpty)
              _recapRow('Photos', '${_photos.length} fichier(s)'),
            if (_videos.isNotEmpty)
              _recapRow('Vidéos', '${_videos.length} fichier(s)'),
            if (_voiceMessages.isNotEmpty)
              _recapRow('Audio', '${_voiceMessages.length} message(s)'),
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
        Text(title,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _recapSection(String title, IconData icon, List<Widget> rows,
      {VoidCallback? onEdit}) {
    return ProcolisCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Icon(Icons.edit_rounded,
                      size: 18, color: AppTheme.primary),
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
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary))),
        ],
      ),
    );
  }

  Widget _recapBadgeRow(
      String label, bool value, String activeLabel, String inactiveLabel) {
    final color = value ? AppTheme.green500 : AppTheme.slate400;
    final bg = value ? AppTheme.green50 : AppTheme.slate100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(
              value ? activeLabel : inactiveLabel,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
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
        border: Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(100, 46),
                side: BorderSide(color: AppTheme.slate300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              child: const Text('Précédent'),
            )
          else
            const SizedBox(width: 100),
          const Spacer(),
          if (_currentStep < 3)
            ElevatedButton(
              onPressed:
                  _currentStep == 0 && !_canProceed(0) ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 46),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              child: Text(_currentStep == 0 ? 'Continuer' : 'Suivant'),
            )
          else
            ElevatedButton(
              onPressed: _isPublishing ? null : _publishParcel,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(160, 46),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              child: _isPublishing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_createdParcel != null
                      ? 'Réessayer les pièces jointes'
                      : _isFreeMode
                          ? 'Publier mon annonce'
                          : 'Envoyer ma proposition'),
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
