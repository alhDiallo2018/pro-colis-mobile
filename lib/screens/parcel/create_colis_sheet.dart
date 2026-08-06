// lib/screens/parcel/create_colis_sheet.dart
//
// Modal multi-étapes de création d'un colis (client, libre service).
// Étape 1 : Trajet & destinataire.  Étape 2 : Colis & options.  Étape 3 : Récap.

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
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
import '../../services/api/client.dart';
import '../../services/api/parcels_api.dart';
import '../../services/api_service.dart';
import '../../services/form_draft_store.dart';
import '../../services/places_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/form_draft_ui.dart';
import '../../widgets/payment_channel_selector.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/phone_contact_picker.dart';
import '../../widgets/route_picker.dart';
import '../../widgets/location_autocomplete.dart';

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
  StreamSubscription<void>? _audioCompleteSubscription;
  bool _isRecording = false;
  int _recordingDuration = 0;
  String? _playingPath;
  String? _mediaNote;

  int _step = 0;
  bool _loadingGarages = true;
  bool _submitting = false;
  String? _error;

  List<Garage> _zones = [];
  String? _departureZoneId;
  String? _arrivalZoneId;

  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  final _receiverEmail = TextEditingController();
  final _receiverAddress = TextEditingController();
  ParcelType _type = ParcelType.package;
  final _weight = TextEditingController();
  final _description = TextEditingController();
  bool _insurance = true;
  bool _urgent = false;

  // Prix proposé (éditable).
  final _priceController = TextEditingController();
  bool _priceEdited = false;

  // Règlement : canal choisi, et en espèces qui remet l'argent au chauffeur.
  PaymentChannel _paymentChannel = PaymentChannel.cash;
  CashCollectionPoint _cashCollectionPoint =
      CashCollectionPoint.receiverDelivery;

  // Mode de livraison : 'free' (annonce) ou 'driver' (chauffeur choisi).
  String _mode = 'free';
  String? _driverId;
  List<User> _drivers = [];
  bool _driversLoaded = false;
  bool _loadingDrivers = false;

  /// Estimation renvoyée par l'API, arrondie à l'entier.
  ///
  /// Le barème vit dans `SystemConfig` côté serveur : la valeur était codée en
  /// dur ici (`14500` / `12500`), si bien qu'elle ignorait le poids saisi et
  /// qu'un tarif réglé par l'administrateur n'avait aucun effet sur l'écran.
  /// Le repli ne sert qu'avant la première réponse et hors connexion —
  /// l'utilisateur reste libre de fixer son prix.
  static const int _fallbackEstimate = 12500;
  int _estimatedPrice = _fallbackEstimate;

  /// Dernière estimation reçue, conservée pour afficher le supplément réel
  /// d'urgence plutôt qu'un montant écrit en dur dans l'interface.
  ParcelEstimate? _lastEstimate;

  final ParcelsApi _parcelsApi = ParcelsApi(ApiClient());

  /// Le poids se saisit caractère par caractère : on laisse la frappe se poser
  /// avant d'interroger le serveur.
  Timer? _estimateTimer;

  // ---- Brouillon ----
  late final FormDraftStore _draftStore;
  Timer? _draftSaveTimer;

  /// Brouillon retrouvé à l'ouverture, tant que l'utilisateur n'a pas dit s'il
  /// voulait le reprendre. La sauvegarde automatique reste en pause d'ici là,
  /// pour ne pas écraser la saisie proposée avant qu'il l'ait vue.
  FormDraft? _pendingDraft;
  bool get _draftPending => _pendingDraft != null;

  /// Quand le brouillon est conservé, les notes vocales lui appartiennent : il
  /// ne faut surtout pas les effacer en quittant, sinon on garde un brouillon
  /// qui référence des fichiers disparus.
  bool _keepVoiceFiles = false;

  @override
  void initState() {
    super.initState();
    _priceController.text = _estimatedPrice.toString();
    _draftStore = FormDraftStore(
      slot: 'colis',
      ownerId: ref.read(authProvider).user?.id,
    );
    // Les écouteurs sont posés après le prix par défaut : sinon ce pré-remplissage
    // déclencherait une sauvegarde d'un formulaire encore vide.
    for (final controller in [
      _receiverName,
      _receiverPhone,
      _receiverEmail,
      _receiverAddress,
      _weight,
      _description,
      _priceController,
    ]) {
      controller.addListener(_scheduleDraftSave);
    }
    // Le poids fait varier l'estimation : on la redemande quand il change.
    _weight.addListener(_scheduleEstimate);
    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingPath = null);
    });
    _loadZones();
    _loadDraft();
    _refreshEstimate();
  }

  /// Laisse la frappe se poser avant d'interroger le serveur.
  void _scheduleEstimate() {
    _estimateTimer?.cancel();
    _estimateTimer =
        Timer(const Duration(milliseconds: 500), _refreshEstimate);
  }

  Future<void> _refreshEstimate() async {
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    final estimate = await _parcelsApi.estimate(
      // Sans poids saisi, l'API applique son défaut d'un kilo.
      weight: weight == null || weight <= 0 ? 1 : weight,
      isUrgent: _urgent,
      isInsured: _insurance,
    );
    if (!mounted || estimate == null) return;

    setState(() {
      _estimatedPrice = estimate.amount.round();
      _lastEstimate = estimate;
    });
    // Un prix déjà retouché par l'utilisateur ne doit jamais être écrasé.
    if (!_priceEdited) {
      _priceController.text = _estimatedPrice.toString();
    }
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _estimateTimer?.cancel();
    _receiverName.dispose();
    _receiverPhone.dispose();
    _receiverEmail.dispose();
    _receiverAddress.dispose();
    _weight.dispose();
    _description.dispose();
    _priceController.dispose();
    _recordingTimer?.cancel();
    _audioCompleteSubscription?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    if (!_keepVoiceFiles) {
      for (final voice in _voiceMessages) {
        _deleteLocalFile(voice.path);
      }
    }
    super.dispose();
  }

  // ---- Brouillon : lecture, écriture, reprise ----

  Future<void> _loadDraft() async {
    final draft = await _draftStore.load();
    if (!mounted || draft == null) return;
    setState(() => _pendingDraft = draft);
  }

  /// Vrai dès qu'un champ significatif est renseigné. Le trajet par défaut et
  /// le prix estimé ne comptent pas : ils sont pré-remplis, pas saisis.
  bool get _hasContent =>
      _receiverName.text.trim().isNotEmpty ||
      _receiverPhone.text.trim().isNotEmpty ||
      _receiverEmail.text.trim().isNotEmpty ||
      _receiverAddress.text.trim().isNotEmpty ||
      _weight.text.trim().isNotEmpty ||
      _description.text.trim().isNotEmpty ||
      _priceEdited ||
      _type != ParcelType.package ||
      _urgent ||
      !_insurance ||
      _mode != 'free' ||
      _driverId != null ||
      _photos.isNotEmpty ||
      _videos.isNotEmpty ||
      _voiceMessages.isNotEmpty;

  Map<String, dynamic> _draftPayload({
    List<String> photos = const [],
    List<String> videos = const [],
    List<Map<String, dynamic>> voices = const [],
  }) =>
      {
        'step': _step,
        'departureZoneId': _departureZoneId,
        'arrivalZoneId': _arrivalZoneId,
        'receiverName': _receiverName.text,
        'receiverPhone': _receiverPhone.text,
        'receiverEmail': _receiverEmail.text,
        'receiverAddress': _receiverAddress.text,
        'type': _type.value,
        'weight': _weight.text,
        'description': _description.text,
        'insurance': _insurance,
        'urgent': _urgent,
        'price': _priceController.text,
        'priceEdited': _priceEdited,
        'paymentChannel': _paymentChannel.value,
        'cashCollectionPoint': _cashCollectionPoint.value,
        'mode': _mode,
        'driverId': _driverId,
        'photos': photos,
        'videos': videos,
        'voices': voices,
      };

  void _scheduleDraftSave() {
    if (_draftPending || _submitting) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 600), _saveDraft);
  }

  /// Écrit le brouillon en mettant d'abord les pièces jointes à l'abri.
  /// `adoptMedia` est idempotent, donc les sauvegardes successives ne recopient
  /// que les fichiers réellement nouveaux.
  Future<void> _saveDraft() async {
    if (_draftPending || _submitting || !_hasContent) return;

    // Cas courant : aucune pièce jointe. On écrit sans toucher au disque, et le
    // ménage d'anciennes pièces retirées se fait en arrière-plan — la sauvegarde
    // se déclenche à chaque frappe, elle ne doit pas attendre le système de
    // fichiers.
    if (_photos.isEmpty && _videos.isEmpty && _voiceMessages.isEmpty) {
      await _draftStore.save(_draftPayload());
      unawaited(_draftStore.purgeMedia());
      return;
    }

    final photos = await _draftStore.adoptAll(_photos.map((f) => f.path));
    final videos = await _draftStore.adoptAll(_videos.map((f) => f.path));

    // Les notes vocales sont déplacées, pas copiées : l'enregistreur les écrit
    // dans le dossier documents, et laisser l'original en place accumulerait des
    // fichiers que plus personne ne référence.
    final voices = <VoiceMessage>[];
    for (final voice in _voiceMessages) {
      final path = await _draftStore.adoptMedia(voice.path);
      if (path == null) continue;
      if (path != voice.path) _deleteLocalFile(voice.path);
      voices.add(VoiceMessage(
        path: path,
        duration: voice.duration,
        createdAt: voice.createdAt,
      ));
    }

    await _draftStore.pruneMediaExcept([
      ...photos,
      ...videos,
      ...voices.map((v) => v.path),
    ]);
    await _draftStore.save(_draftPayload(
      photos: photos,
      videos: videos,
      voices: voices
          .map((v) => {
                'path': v.path,
                'duration': v.duration,
                'createdAt': v.createdAt.toIso8601String(),
              })
          .toList(),
    ));

    // L'état en mémoire suit les fichiers : sans ça, l'écran continuerait de
    // pointer vers des chemins temporaires que l'OS peut purger en cours de
    // saisie. L'adoption étant idempotente, cela ne se produit qu'une fois par
    // pièce jointe.
    if (!mounted) return;
    final movedVoice = <String, String>{
      for (var i = 0; i < voices.length && i < _voiceMessages.length; i++)
        _voiceMessages[i].path: voices[i].path,
    };
    if (_samePaths(_photos, photos) &&
        _samePaths(_videos, videos) &&
        movedVoice.entries.every((e) => e.key == e.value)) {
      return;
    }
    setState(() {
      _photos
        ..clear()
        ..addAll(photos.map(XFile.new));
      _videos
        ..clear()
        ..addAll(videos.map(XFile.new));
      _voiceMessages
        ..clear()
        ..addAll(voices);
      if (_playingPath != null) _playingPath = movedVoice[_playingPath!];
    });
  }

  static bool _samePaths(List<XFile> current, List<String> next) {
    if (current.length != next.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (current[i].path != next[i]) return false;
    }
    return true;
  }

  void _restoreDraft() {
    final draft = _pendingDraft;
    if (draft == null) return;
    final data = draft.data;

    // Une pièce jointe peut avoir disparu entre-temps (purge de l'OS,
    // désinstallation partielle) : on ne restaure que ce qui existe encore et
    // on le dit, plutôt que d'afficher des vignettes mortes.
    final photos = _existingPaths(data['photos']);
    final videos = _existingPaths(data['videos']);
    final voices = <VoiceMessage>[];
    final rawVoices = data['voices'];
    if (rawVoices is List) {
      for (final entry in rawVoices) {
        if (entry is! Map) continue;
        final path = entry['path']?.toString();
        if (path == null || !File(path).existsSync()) continue;
        voices.add(VoiceMessage(
          path: path,
          duration: (entry['duration'] as num?)?.toInt() ?? 0,
          createdAt: DateTime.tryParse(entry['createdAt']?.toString() ?? '') ??
              DateTime.now(),
        ));
      }
    }

    final expectedMedia = _countOf(data['photos']) +
        _countOf(data['videos']) +
        _countOf(data['voices']);
    final restoredMedia = photos.length + videos.length + voices.length;

    setState(() {
      _step = (data['step'] as num?)?.toInt() ?? 0;
      _departureZoneId = data['departureZoneId']?.toString() ?? _departureZoneId;
      _arrivalZoneId = data['arrivalZoneId']?.toString() ?? _arrivalZoneId;
      _receiverName.text = data['receiverName']?.toString() ?? '';
      _receiverPhone.text = data['receiverPhone']?.toString() ?? '';
      _receiverEmail.text = data['receiverEmail']?.toString() ?? '';
      _receiverAddress.text = data['receiverAddress']?.toString() ?? '';
      _type = ParcelType.fromString(data['type']?.toString() ?? '');
      _weight.text = data['weight']?.toString() ?? '';
      _description.text = data['description']?.toString() ?? '';
      _insurance = data['insurance'] as bool? ?? true;
      _urgent = data['urgent'] as bool? ?? false;
      _priceEdited = data['priceEdited'] as bool? ?? false;
      _priceController.text =
          data['price']?.toString() ?? _estimatedPrice.toString();
      _paymentChannel = PaymentChannel.fromString(data['paymentChannel']);
      _cashCollectionPoint =
          CashCollectionPoint.tryParse(data['cashCollectionPoint']) ??
              CashCollectionPoint.receiverDelivery;
      _mode = data['mode']?.toString() ?? 'free';
      _driverId = data['driverId']?.toString();

      _photos
        ..clear()
        ..addAll(photos.map(XFile.new));
      _videos
        ..clear()
        ..addAll(videos.map(XFile.new));
      _voiceMessages
        ..clear()
        ..addAll(voices);

      _pendingDraft = null;
    });

    if (_mode == 'driver') _loadDrivers();
    if (restoredMedia < expectedMedia) {
      _showMediaNote(
        '${expectedMedia - restoredMedia} pièce(s) jointe(s) du brouillon '
        'n’étaient plus disponibles.',
      );
    }
  }

  static List<String> _existingPaths(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString() ?? '')
        .where((p) => p.isNotEmpty && File(p).existsSync())
        .toList();
  }

  static int _countOf(dynamic raw) => raw is List ? raw.length : 0;

  Future<void> _discardDraft() async {
    setState(() => _pendingDraft = null);
    await _draftStore.clear();
  }

  /// Sortie du formulaire : on ne propose de garder que s'il y a quelque chose
  /// à perdre. Fermer une saisie vide ne doit poser aucune question.
  Future<void> _handleClose() async {
    if (_submitting) return;
    if (!_hasContent) {
      if (mounted) Navigator.pop(context, false);
      return;
    }

    _draftSaveTimer?.cancel();
    final choice = await showDraftExitDialog(
      context,
      message: 'Votre colis n’est pas encore publié. Gardez-le en brouillon '
          'pour reprendre la saisie plus tard.',
    );
    if (!mounted) return;

    switch (choice) {
      case DraftExitChoice.keep:
        // Si le bandeau de reprise est encore affiché, la saisie en cours prime
        // sur le brouillon proposé : sans ça la garde `_draftPending` annulerait
        // l'écriture et « Garder » ne garderait rien.
        _pendingDraft = null;
        // Écrit avant de fermer, sans passer par le débounce : la fenêtre
        // serait annulée par la destruction de l'état.
        await _saveDraft();
        _keepVoiceFiles = true;
        if (mounted) Navigator.pop(context, false);
      case DraftExitChoice.discard:
        // Fermer d'abord : l'utilisateur a tranché, il n'a pas à attendre le
        // nettoyage disque. Le magasin survit à la destruction de l'état.
        Navigator.pop(context, false);
        await _draftStore.clear();
      case DraftExitChoice.cancel:
      case null:
        break;
    }
  }

  Future<void> _importReceiverFromContacts() async {
    final contact = await showPhoneContactPicker(
      context: context,
      selectedPhone: _receiverPhone.text,
    );
    if (!mounted || contact == null) return;

    // Le nom et le numéro sont appliqués ensemble pour éviter de conserver
    // accidentellement le nom d'un précédent destinataire.
    setState(() {
      _receiverName.text = contact.contactName;
      _receiverPhone.text = contact.phoneNumber;
    });
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
      _scheduleDraftSave();
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
              leading: Icon(Icons.photo_camera_rounded,
                  color: AppTheme.primary),
              title: Text('Prendre une photo',
                  style: AppFonts.manrope(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded,
                  color: AppTheme.primary),
              title: Text('Choisir dans la galerie',
                  style: AppFonts.manrope(fontWeight: FontWeight.w600)),
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
      _scheduleDraftSave();
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
    if (kIsWeb) {
      _showMediaNote('Enregistrement non disponible sur le web');
      return;
    }
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
      _scheduleDraftSave();
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
    } catch (error) {
      debugPrint('Erreur lecture audio colis: $error');
      if (mounted) setState(() => _playingPath = null);
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
    _scheduleDraftSave();
  }

  void _removeVideo(int index) {
    setState(() => _videos.removeAt(index));
    _scheduleDraftSave();
  }

  void _removeVoice(int index) {
    final voice = _voiceMessages[index];
    if (_playingPath == voice.path) {
      _audioPlayer.stop();
      _playingPath = null;
    }
    _deleteLocalFile(voice.path);
    setState(() => _voiceMessages.removeAt(index));
    _scheduleDraftSave();
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
    _scheduleDraftSave();
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

  Future<void> _loadZones() async {
    try {
      final zones = await _api.getAllZones();
      if (mounted) {
        setState(() {
          _zones = zones;
          // Le pré-remplissage ne doit pas écraser un trajet déjà restauré
          // depuis un brouillon.
          if (zones.isNotEmpty && _departureZoneId == null) {
            _departureZoneId = zones.first.id;
          }
          if (zones.length > 1 && _arrivalZoneId == null) {
            _arrivalZoneId = zones[1].id;
          }
          _loadingGarages = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGarages = false);
    }
  }

  Garage? _zoneById(String? id) {
    if (id == null) return null;
    for (final z in _zones) {
      if (z.id == id) return z;
    }
    return null;
  }

  /// Zone ajoutée à la volée : elle n'est pas encore dans la liste publique
  /// (validation en attente), on l'injecte localement pour la rendre
  /// sélectionnable immédiatement.
  void _addResolvedZone(Garage zone) {
    setState(() {
      _zones = [..._zones.where((z) => z.id != zone.id), zone];
    });
  }

  bool get _step1Valid =>
      _departureZoneId != null &&
      _arrivalZoneId != null &&
      _departureZoneId != _arrivalZoneId &&
      _receiverName.text.trim().isNotEmpty &&
      _receiverPhone.text.trim().isNotEmpty &&
      (_mode != 'driver' || _driverId != null);

  Future<void> _submit() async {
    if (_submitting) return;
    final dep = _zoneById(_departureZoneId);
    final arr = _zoneById(_arrivalZoneId);
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
      'receiverEmail': _receiverEmail.text.trim().isEmpty
          ? null
          : _receiverEmail.text.trim(),
      'receiverAddress': _receiverAddress.text.trim().isEmpty
          ? null
          : _receiverAddress.text.trim(),
      'description':
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      'weight': double.tryParse(_weight.text.trim()) ?? 0,
      'type': _type.value,
      'status': isDriverMode ? 'negotiating' : 'free',
      'departureZoneId': dep.id,
      'departureZoneName': dep.name,
      'arrivalZoneId': arr.id,
      'arrivalZoneName': arr.name,
      'price': price,
      'proposedPrice': price,
      'isUrgent': _urgent,
      'isInsured': _insurance,
      'isFreeForBidding': !isDriverMode,
      'audioUrls': <String>[],
      // Règlement : le canal fait foi ; `paymentMethod` reste renseigné pour la
      // compatibilité avec l'API et les écrans qui le lisent encore.
      'paymentChannel': _paymentChannel.value,
      'paymentMethod': _paymentChannel.defaultMethod.value,
      if (_paymentChannel.isCash)
        'cashCollectionPoint': _cashCollectionPoint.value,
    };

    if (isDriverMode && driver != null) {
      data['driverId'] = driver.id;
      data['driverName'] = driver.fullName;
    }

    final result = await ref.read(parcelProvider.notifier).createParcel(data);
    if (!mounted) return;

    if (result != null) {
      // Le spinner reste actif pendant l'envoi des pièces jointes.
      try {
        await _uploadMediaForParcel(result.id);
      } catch (error) {
        debugPrint('Erreur upload médias colis: $error');
      }
      // Publié : le brouillon et ses pièces jointes n'ont plus de raison d'être.
      _draftSaveTimer?.cancel();
      await _draftStore.clear();
      await ref.read(parcelProvider.notifier).loadSentParcels();
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // `canPop: false` intercepte aussi bien le swipe vers le bas que le retour
    // système : c'est là que la saisie se perdait silencieusement.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  _handle(),
                  _header(),
                  Expanded(
                    child: _loadingGarages
                        ? Center(
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
            child: Icon(Icons.local_shipping_rounded,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nouveau colis',
                    style: AppFonts.plusJakartaSans(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Étape ${_step + 1} sur 3 · ${_stepTitle(_step)}',
                    style: AppFonts.manrope(
                        fontSize: 12.5, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            onPressed: _handleClose,
            icon: Icon(Icons.close_rounded, color: AppTheme.slate500),
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
        if (_pendingDraft != null)
          DraftRestoreBanner(
            savedAt: _pendingDraft!.savedAt,
            onRestore: _restoreDraft,
            onDiscard: _discardDraft,
          ),
        const SizedBox(height: 8),
        RoutePicker(
          garages: _zones,
          initialDeparture: _zoneById(_departureZoneId),
          initialArrival: _zoneById(_arrivalZoneId),
          onDepartureChanged: (g) {
            setState(() => _departureZoneId = g?.id);
            _scheduleDraftSave();
          },
          onArrivalChanged: (g) {
            setState(() => _arrivalZoneId = g?.id);
            _scheduleDraftSave();
          },
          onZoneAdded: _addResolvedZone,
        ),
        if (_departureZoneId != null && _departureZoneId == _arrivalZoneId) ...[
          const SizedBox(height: 12),
          _warning('Le départ et l’arrivée doivent être différents.'),
        ],
        const SizedBox(height: 16),
        PcButton(
          'Choisir dans mes contacts',
          onPressed: _importReceiverFromContacts,
          variant: PcButtonVariant.secondary,
          icon: Icons.contact_phone_rounded,
          block: true,
        ),
        const SizedBox(height: 16),
        _label('Nom du destinataire'),
        _textField(_receiverName, 'Ex : Awa Ndiaye', Icons.badge_rounded),
        const SizedBox(height: 14),
        _label('Téléphone du destinataire'),
        _textField(_receiverPhone, 'Ex : 77 000 00 00', Icons.call_rounded,
            mono: true, phone: true),
        const SizedBox(height: 14),
        _label('Email du destinataire (optionnel)'),
        _textField(
            _receiverEmail, 'Ex : exemple@email.com', Icons.email_rounded),
        const SizedBox(height: 14),
        LocationAutocomplete(
          controller: _receiverAddress,
          label: 'Adresse de livraison (optionnel)',
          prefixIcon: Icons.home_rounded,
          hint: 'Quartier, repère…',
          googleApiKey: PlacesService.googleApiKey,
        ),
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
                  size: 22, color: selected ? Colors.white : AppTheme.slate500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: AppFonts.manrope(
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
          style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary));
    }
    if (_drivers.isEmpty) {
      return Text('Aucun chauffeur disponible pour le moment.',
          style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary));
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
            decoration: BoxDecoration(
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
        style: AppFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.teal700),
      );

  Widget _driverCard(User d) {
    final selected = _driverId == d.id;
    final status = _driverStatusMeta(d);
    final rating = (d.rating ?? 0).toStringAsFixed(1);
    final completed = d.completedDeliveries ?? 0;
    final subtitle = (d.zoneName ?? '').trim().isNotEmpty
        ? d.zoneName!.trim()
        : ((d.city ?? '').trim().isNotEmpty ? d.city!.trim() : 'Indépendant');
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: () {
        setState(() => _driverId = selected ? null : d.id);
        _scheduleDraftSave();
      },
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
                          style: AppFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.manrope(
                              fontSize: 12.5, color: AppTheme.textSecondary)),
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
                Icon(Icons.star_rounded,
                    size: 16, color: AppTheme.amber500),
                const SizedBox(width: 3),
                Text(rating,
                    style: AppFonts.plusJakartaSans(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Text('· $completed livr.',
                    style: AppFonts.manrope(
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
                    style: AppFonts.manrope(
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
          style: AppFonts.manrope(fontSize: 14),
          decoration: _dec('Ex : documents, fragile…', null),
        ),
        const SizedBox(height: 4),
        _switchRow(
          'Assurer le colis',
          'Couvre jusqu’à 200 000 FCFA',
          _insurance,
          (v) {
            setState(() => _insurance = v);
            _refreshEstimate();
            _scheduleDraftSave();
          },
        ),
        const PcDivider(),
        _switchRow(
          'Livraison urgente',
          // Le montant vient du barème serveur : ne l'annoncer que lorsqu'il
          // est connu, plutôt que d'écrire un chiffre qui pourrait être faux.
          _urgent && (_lastEstimate?.urgentFee ?? 0) > 0
              ? 'Supplément ${formatFcfa(_lastEstimate!.urgentFee)}'
              : 'Prise en charge prioritaire',
          _urgent,
          (v) {
            setState(() => _urgent = v);
            // Le supplément d'urgence est réglé côté serveur : c'est lui qui
            // recalcule le prix par défaut, si l'utilisateur ne l'a pas fixé.
            _refreshEstimate();
            _scheduleDraftSave();
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
          // La sauvegarde est déjà déclenchée par l'écouteur du contrôleur.
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
          style: AppFonts.manrope(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        PaymentChannelField(
          value: _paymentChannel,
          onChanged: (channel) {
            setState(() => _paymentChannel = channel);
            _scheduleDraftSave();
          },
          footnote: _mode == 'driver'
              ? 'Le chauffeur doit accepter ce mode pour confirmer la course.'
              : 'Les chauffeurs qui n’acceptent pas ce mode ne pourront pas '
                  'répondre à votre annonce.',
        ),
        if (_paymentChannel.isCash) ...[
          const SizedBox(height: 16),
          CashCollectionPointField(
            value: _cashCollectionPoint,
            onChanged: (point) {
              setState(() => _cashCollectionPoint = point);
              _scheduleDraftSave();
            },
          ),
        ],
        const SizedBox(height: 18),
        _buildAttachments(),
      ],
    );
  }

  Widget _buildRecap() {
    final dep = _zoneById(_departureZoneId);
    final arr = _zoneById(_arrivalZoneId);
    final driver = _driverById(_driverId);
    final isDriverMode = _mode == 'driver';
    final mediaCount = _photos.length + _videos.length + _voiceMessages.length;
    final priceText = '${_enteredPrice.toStringAsFixed(0)} FCFA';
    final address = _receiverAddress.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepBar(),
        Text('Vérifiez avant de publier',
            style: AppFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('Un dernier coup d’œil ; touchez « Modifier » pour corriger.',
            style: AppFonts.manrope(
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
            _recapRow(
                'Nom',
                _receiverName.text.trim().isEmpty
                    ? '—'
                    : _receiverName.text.trim()),
            _recapRow(
                'Téléphone',
                _receiverPhone.text.trim().isEmpty
                    ? '—'
                    : _receiverPhone.text.trim(),
                mono: true),
            if (_receiverEmail.text.trim().isNotEmpty)
              _recapRow('Email', _receiverEmail.text.trim()),
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
            _recapRow(
              'Paiement',
              _paymentChannel.isCash
                  ? '${_paymentChannel.label} · ${_cashCollectionPoint.payerLabel.toLowerCase()}'
                  : _paymentChannel.label,
            ),
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
                    style: AppFonts.plusJakartaSans(
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
                      Icon(Icons.edit_rounded,
                          size: 15, color: AppTheme.primary),
                      const SizedBox(width: 3),
                      Text('Modifier',
                          style: AppFonts.plusJakartaSans(
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
              style: AppFonts.manrope(
                  fontSize: 12.5, color: AppTheme.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: mono
                  ? AppTheme.mono(fontSize: 13, fontWeight: FontWeight.w700)
                  : AppFonts.plusJakartaSans(
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
              style: AppFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.teal700)),
        ],
      ),
    );
  }

  Widget _buildAttachments() {
    final hasItems =
        _photos.isNotEmpty || _videos.isNotEmpty || _voiceMessages.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file_rounded,
                size: 18, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text('Pièces jointes',
                style: AppFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700)),
            const SizedBox(width: 6),
            Text('(optionnel)',
                style: AppFonts.manrope(
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
              style: AppFonts.manrope(
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
                  style: AppFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w800, color: color)),
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
                    : kIsWeb
                        ? Image.network(
                            imagePath,
                            fit: BoxFit.cover,
                            width: 88,
                            height: 54,
                            errorBuilder: (_, __, ___) =>
                                Icon(icon, color: AppTheme.primary, size: 26),
                          )
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
                    child: Icon(Icons.cancel_rounded,
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
              style: AppFonts.plusJakartaSans(
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
              onPressed: _step1Valid ? () => setState(() => _step = 1) : null,
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
            style: AppFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate700)),
      );

  InputDecoration _dec(String hint, IconData? icon) => InputDecoration(
        hintText: hint,
        hintStyle: AppFonts.manrope(fontSize: 14, color: AppTheme.slate400),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: AppTheme.slate400)
            : null,
        filled: true,
        fillColor: AppTheme.cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(color: AppTheme.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(color: AppTheme.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
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
          : AppFonts.manrope(fontSize: 14),
      decoration: _dec(hint, icon),
    );
  }

  Widget _typeDropdown() {
    return DropdownButtonFormField<ParcelType>(
      initialValue: _type,
      isExpanded: true,
      icon: Icon(Icons.expand_more_rounded, color: AppTheme.slate500),
      decoration: _dec('', Icons.category_rounded),
      style: AppFonts.manrope(fontSize: 13.5, color: AppTheme.textPrimary),
      items: ParcelType.values
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(t.label, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) {
        setState(() => _type = v ?? ParcelType.package);
        _scheduleDraftSave();
      },
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
                    style: AppFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppFonts.manrope(
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
                style: AppFonts.manrope(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}
