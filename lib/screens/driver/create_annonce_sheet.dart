import 'route_templates_screen.dart';
import '../../models/vehicle_type.dart';
// lib/screens/driver/create_annonce_sheet.dart
//
// Modal multi-étapes de création d'une annonce de trajet (chauffeur).
// Étape 1 : Trajet (départ / arrivée / date).  Étape 2 : Capacité & prix.
// Aligné sur le CreateAnnonceDialog du web, en flux 2 étapes.

import 'dart:async';
import 'dart:convert';
import '../../widgets/trip_plan_editor.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/garage.dart';
import '../../providers/advertisement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/form_draft_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/form_draft_ui.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/route_picker.dart';
import '../../widgets/voice_note_field.dart';

/// Ouvre le modal de création d'annonce. Renvoie `true` si une annonce a été
/// publiée (le parent peut alors rafraîchir sa liste).
Future<bool?> showCreateAnnonceSheet(BuildContext context, {ApiService? api}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateAnnonceSheet(api: api),
  );
}

/// Rouvre le même formulaire sur une annonce existante. [advertisement] est la
/// forme brute renvoyée par l'API — elle porte les identifiants de zone, que le
/// modèle `Advertisement` n'expose pas.
///
/// Renvoie `true` si l'annonce a été modifiée.
Future<bool?> showEditAnnonceSheet(
  BuildContext context,
  Map<String, dynamic> advertisement,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateAnnonceSheet(existing: advertisement),
  );
}

class _CreateAnnonceSheet extends ConsumerStatefulWidget {
  /// Annonce à modifier. `null` en création.
  final Map<String, dynamic>? existing;

  // Le client peut être injecté pour tester la publication sans dépendre
  // du réseau ni du stockage sécurisé global.
  final ApiService? api;
  const _CreateAnnonceSheet({this.existing, this.api});

  @override
  ConsumerState<_CreateAnnonceSheet> createState() =>
      _CreateAnnonceSheetState();
}

class _CreateAnnonceSheetState extends ConsumerState<_CreateAnnonceSheet> {
  late final ApiService _api = widget.api ?? ApiService();

  // ---- Brouillon ----
  late final FormDraftStore _draftStore;
  Timer? _draftSaveTimer;

  /// Brouillon retrouvé à l'ouverture, tant que l'utilisateur n'a pas dit s'il
  /// voulait le reprendre. La sauvegarde automatique reste en pause d'ici là,
  /// pour ne pas écraser la saisie proposée avant qu'il l'ait vue.
  FormDraft? _pendingDraft;
  bool get _draftPending => _pendingDraft != null;

  int _step = 0; // 0 = trajet, 1 = capacité & prix
  bool _loadingGarages = true;
  bool _submitting = false;
  String? _error;
  String? _audioUrl;
  bool _voiceBusy = false;

  List<Garage> _zones = [];
  String? _departureZoneId;
  String? _arrivalZoneId;
  DateTime? _departureAt;
  String? _profileVehicleId;
  String? _profileVehicleError;
  Map<String, dynamic>? _tripPlan = {
    'serviceType': 'trip',
    'intermediateStops': []
  };

  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool get _isEditing => widget.existing != null;
  String? get _editedAdId => widget.existing?['id']?.toString();

  /// État initial de l'annonce en cours de modification. Sert à n'envoyer que
  /// les champs réellement changés : renvoyer une `departureAt` déjà passée que
  /// l'utilisateur n'a pas touchée ferait échouer la requête, l'API exigeant une
  /// date future.
  Map<String, dynamic> _initialValues = const {};

  @override
  void initState() {
    super.initState();
    _draftStore = FormDraftStore(
      slot: 'annonce',
      ownerId: ref.read(authProvider).user?.id,
    );
    _loadZones();
    if (!_isEditing) {
      final user = ref.read(authProvider).user;
      final type = vehicleTypeCode(user?.vehicleType);
      _tripPlan = {...?_tripPlan, 'serviceType': _serviceFor(type)};
      if ((user?.vehicleCapacity ?? 0) > 0)
        _weightController.text = user!.vehicleCapacity.toString();
      _loadRegisteredTransport();
    }

    if (_isEditing) {
      // Pas de brouillon en modification : il porterait la saisie d'une
      // création précédente et écraserait l'annonce chargée.
      _prefillFromExisting(widget.existing!);
      return;
    }

    for (final controller in [
      _weightController,
      _priceController,
      _descriptionController,
    ]) {
      controller.addListener(_scheduleDraftSave);
    }
    _loadDraft();
  }

  String _serviceFor(String? type) => type == 'bus'
      ? 'shuttle'
      : type == 'gp'
          ? 'gp'
          : 'trip';
  Future<void> _loadRegisteredTransport() async {
    try {
      final vehicle = await _api.getDriverVehicle();
      if (!mounted) return;
      setState(() {
        _profileVehicleId = vehicle?['id']?.toString();
        _profileVehicleError = vehicle == null
            ? 'Véhicule indisponible. Vérifiez votre connexion ou complétez votre profil chauffeur.'
            : null;
        if (vehicle != null && _tripPlan != null) {
          _tripPlan = {
            ..._tripPlan!,
            'serviceType':
                _serviceFor(vehicleTypeCode(vehicle['type']?.toString()))
          };
          if (_weightController.text.isEmpty &&
              (num.tryParse('${vehicle['capacity']}') ?? 0) > 0)
            _weightController.text = vehicle['capacity'].toString();
        }
      });
    } catch (error, stack) {
      debugPrint(
          '[CreateTrip] Profil véhicule indisponible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      if (mounted)
        setState(() => _profileVehicleError =
            'Impossible de charger votre véhicule. Réessayez.');
    }
  }

  void _prefillFromExisting(Map<String, dynamic> ad) {
    String? asText(dynamic value) {
      final text = value?.toString().trim();
      return (text == null || text.isEmpty) ? null : text;
    }

    // Les décimaux arrivent en chaîne depuis l'API ; on les réaffiche sans
    // zéros superflus pour que le champ reste éditable au clavier numérique.
    String numberText(dynamic value) {
      final parsed = num.tryParse(value?.toString() ?? '');
      if (parsed == null) return '';
      return parsed == parsed.roundToDouble()
          ? parsed.round().toString()
          : parsed.toString();
    }

    _departureZoneId = asText(ad['departureZoneId']);
    _arrivalZoneId = asText(ad['arrivalZoneId']);
    // Une zone pending n'est pas dans /public/zones. Réutiliser le lieu de
    // l'annonce pour que la modification conserve son libellé et son UUID.
    for (final side in ['departure', 'arrival']) {
      final id = asText(ad['${side}ZoneId']);
      final name = asText(ad['${side}Name']) ??
          asText(ad['${side}ZoneName']) ??
          asText(ad['${side}City']);
      if (id != null && name != null) {
        _zones.add(Garage.fromJson(
            {'id': id, 'name': name, 'city': ad['${side}City']}));
      }
    }
    _tripPlan = tripPlanFromItinerary(ad['itinerary']);
    _departureAt = DateTime.tryParse(ad['departureAt']?.toString() ?? '');
    _weightController.text = numberText(ad['availableWeight']);
    _priceController.text = numberText(ad['proposedPrice']);
    _descriptionController.text = asText(ad['description']) ?? '';
    _audioUrl = asText(ad['audioUrl']);

    _initialValues = {
      'departureZoneId': _departureZoneId,
      'arrivalZoneId': _arrivalZoneId,
      'departureAt': _departureAt?.toIso8601String(),
      'availableWeight': _weightController.text,
      'proposedPrice': _priceController.text,
      'description': _descriptionController.text,
      'audioUrl': _audioUrl,
      'tripPlan': jsonEncode(_tripPlan),
    };
  }

  /// Vrai si la saisie diverge de l'annonce chargée.
  bool get _hasEdits {
    if (!_isEditing) return false;
    return _initialValues['tripPlan'] != jsonEncode(_tripPlan) ||
        _initialValues['departureZoneId'] != _departureZoneId ||
        _initialValues['arrivalZoneId'] != _arrivalZoneId ||
        _initialValues['departureAt'] != _departureAt?.toIso8601String() ||
        _initialValues['availableWeight'] != _weightController.text ||
        _initialValues['proposedPrice'] != _priceController.text ||
        _initialValues['description'] != _descriptionController.text ||
        _initialValues['audioUrl'] != _audioUrl;
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _weightController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ---- Brouillon : lecture, écriture, reprise ----

  Future<void> _loadDraft() async {
    final draft = await _draftStore.load();
    if (!mounted || draft == null) return;
    setState(() => _pendingDraft = draft);
  }

  /// Vrai dès qu'un champ significatif est renseigné. Le seul `_step` ne compte
  /// pas : avancer d'une étape sans rien saisir ne mérite pas de brouillon.
  bool get _hasContent =>
      _departureZoneId != null ||
      _arrivalZoneId != null ||
      _departureAt != null ||
      _weightController.text.trim().isNotEmpty ||
      _priceController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _audioUrl != null;

  Map<String, dynamic> _draftPayload() => {
        'step': _step,
        'tripPlan': _tripPlan,
        'departureZoneId': _departureZoneId,
        'arrivalZoneId': _arrivalZoneId,
        'departureAt': _departureAt?.toIso8601String(),
        'weight': _weightController.text,
        'price': _priceController.text,
        'description': _descriptionController.text,
        'audioUrl': _audioUrl,
      };

  void _scheduleDraftSave() {
    // Les sélecteurs de trajet et de date appellent cette méthode sans savoir
    // dans quel mode ils sont : la modification d'une annonce publiée ne doit
    // jamais alimenter le brouillon de création.
    if (_isEditing || _draftPending || _submitting) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 600), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (_draftPending || _submitting) return;
    // Supprimer la dernière note d'un brouillon vide doit aussi effacer son
    // ancienne URL, sinon elle réapparaîtrait à la prochaine ouverture.
    if (!_hasContent) {
      await _draftStore.clear();
      return;
    }
    await _draftStore.save(_draftPayload());
  }

  void _restoreDraft() {
    final draft = _pendingDraft;
    if (draft == null) return;
    final data = draft.data;

    setState(() {
      _tripPlan = data['tripPlan'] is Map
          ? Map<String, dynamic>.from(data['tripPlan'])
          : null;
      _step = (data['step'] as num?)?.toInt() ?? 0;
      _departureZoneId = data['departureZoneId']?.toString();
      _arrivalZoneId = data['arrivalZoneId']?.toString();
      _departureAt = DateTime.tryParse(data['departureAt']?.toString() ?? '');
      _weightController.text = data['weight']?.toString() ?? '';
      _priceController.text = data['price']?.toString() ?? '';
      _descriptionController.text = data['description']?.toString() ?? '';
      _audioUrl = data['audioUrl']?.toString();
      _pendingDraft = null;
    });
    if (!_isEditing) _loadRegisteredTransport();
  }

  Future<void> _discardDraft() async {
    setState(() => _pendingDraft = null);
    await _draftStore.clear();
  }

  /// Zone ajoutée à la volée depuis le sélecteur de trajet : absente de la
  /// liste publique tant qu'elle n'est pas validée, on l'injecte localement
  /// pour qu'elle reste sélectionnable.
  void _addResolvedZone(Garage zone) {
    setState(() {
      _zones = [..._zones.where((z) => z.id != zone.id), zone];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('« ${zone.name} » ajoutée — validation en attente.')),
    );
  }

  Future<void> _loadZones() async {
    try {
      final zones = await _api.getAllZones();
      if (mounted) {
        setState(() {
          _zones = [
            ...zones,
            ..._zones
                .where((local) => !zones.any((zone) => zone.id == local.id))
          ];
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

  bool get _step1Valid =>
      (_isEditing || _profileVehicleId != null) &&
      _departureZoneId != null &&
      _arrivalZoneId != null &&
      _departureZoneId != _arrivalZoneId &&
      _validTripPlan;

  // Le serveur reste autoritaire ; ce contrôle évite une publication vouée
  // à l’échec et garde le brouillon tant que le trajet n’est pas complet.
  bool get _validTripPlan {
    if (_tripPlan == null) return true;
    if (_departureAt == null) return false;
    if (_tripPlan!['serviceType'] == 'shuttle' &&
        (_tripPlan!['lineNumber']?.toString().trim().isEmpty ?? true))
      return false;
    final stops = _tripPlan!['intermediateStops'] as List? ?? [];
    final ids = <String?>{_departureZoneId, _arrivalZoneId};
    int previous = 0;
    for (final stop in stops) {
      final minutes = stop['offsetMinutes'];
      if (minutes is! int ||
          minutes <= previous ||
          !ids.add(stop['zoneId']?.toString())) return false;
      previous = minutes;
    }
    final arrival = _tripPlan!['arrivalOffsetMinutes'];
    return arrival is int && arrival > previous && arrival <= 43200;
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _departureAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departureAt ?? now),
    );
    if (!mounted) return;
    setState(() {
      _departureAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 8,
        time?.minute ?? 0,
      );
    });
    _scheduleDraftSave();
  }

  /// Sortie du formulaire : on ne propose de garder que s'il y a quelque chose
  /// à perdre. Fermer une saisie vide ne doit poser aucune question.
  Future<void> _handleClose() async {
    if (_submitting) return;
    if (_voiceBusy) {
      setState(() =>
          _error = 'Terminez ou supprimez la note vocale avant de quitter.');
      return;
    }

    // En modification il n'y a pas de brouillon à garder : on confirme
    // seulement, et uniquement si quelque chose a bougé.
    if (_isEditing) {
      if (!_hasEdits) {
        if (mounted) Navigator.pop(context, false);
        return;
      }
      final abandon = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          title: const Text('Abandonner les modifications ?'),
          content: const Text('Vos changements ne seront pas enregistrés.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuer')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Abandonner',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (abandon == true && mounted) Navigator.pop(context, false);
      return;
    }

    if (!_hasContent) {
      // Une suppression suivie d'une fermeture immédiate précède le délai
      // d'autosauvegarde : efface aussi l'ancien brouillon dans ce cas.
      _draftSaveTimer?.cancel();
      if (mounted) Navigator.pop(context, false);
      // Un brouillon seulement proposé n'a pas été abandonné par l'utilisateur.
      if (!_draftPending) await _draftStore.clear();
      return;
    }

    _draftSaveTimer?.cancel();
    final choice = await showDraftExitDialog(
      context,
      message: 'Votre annonce n’est pas encore publiée. Gardez-la en brouillon '
          'pour la reprendre plus tard.',
    );
    if (!mounted) return;

    switch (choice) {
      case DraftExitChoice.keep:
        // Écrit avant de fermer, sans passer par le débounce : la fenêtre
        // serait annulée par la destruction de l'état.
        await _draftStore.save(_draftPayload());
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

  /// Charge utile complète, pour la création.
  Map<String, dynamic> _createPayload() {
    final dep = _zoneById(_departureZoneId);
    final arr = _zoneById(_arrivalZoneId);
    return <String, dynamic>{
      if (_tripPlan != null)
        'itinerary':
            itineraryFromTripPlan(_tripPlan!, _departureZoneId, _arrivalZoneId),
      'departureZoneId': _departureZoneId,
      'arrivalZoneId': _arrivalZoneId,
      if (_profileVehicleId != null) 'vehicleId': _profileVehicleId,
      'departureCity': dep?.locationLabel,
      'arrivalCity': arr?.locationLabel,
      'departureAt': _departureAt?.toIso8601String(),
      'availableWeight': double.tryParse(_weightController.text.trim()),
      // Le prix se négocie après réception du colis proposé par le client.
      'proposedPrice': null,
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      if (_audioUrl != null) 'audioUrl': _audioUrl,
    };
  }

  /// Charge utile différentielle, pour la modification : seuls les champs
  /// touchés partent. L'API traite l'absence d'un champ comme « inchangé », et
  /// refuserait une date de départ déjà passée qu'on lui renverrait à
  /// l'identique.
  Map<String, dynamic> _updatePayload() {
    final data = <String, dynamic>{};
    if (_initialValues['tripPlan'] != jsonEncode(_tripPlan) ||
        (_tripPlan != null &&
            (_initialValues['departureZoneId'] != _departureZoneId ||
                _initialValues['arrivalZoneId'] != _arrivalZoneId))) {
      data['itinerary'] = _tripPlan == null
          ? null
          : itineraryFromTripPlan(_tripPlan!, _departureZoneId, _arrivalZoneId);
    }

    if (_initialValues['departureZoneId'] != _departureZoneId) {
      data['departureZoneId'] = _departureZoneId;
      data['departureCity'] = _zoneById(_departureZoneId)?.locationLabel;
    }
    if (_initialValues['arrivalZoneId'] != _arrivalZoneId) {
      data['arrivalZoneId'] = _arrivalZoneId;
      data['arrivalCity'] = _zoneById(_arrivalZoneId)?.locationLabel;
    }
    if (_initialValues['departureAt'] != _departureAt?.toIso8601String()) {
      data['departureAt'] = _departureAt?.toIso8601String();
    }
    if (_initialValues['availableWeight'] != _weightController.text) {
      data['availableWeight'] = double.tryParse(_weightController.text.trim());
    }
    if (_initialValues['proposedPrice'] != _priceController.text) {
      data['proposedPrice'] = double.tryParse(_priceController.text.trim());
    }
    if (_initialValues['description'] != _descriptionController.text) {
      final description = _descriptionController.text.trim();
      data['description'] = description.isEmpty ? null : description;
    }

    // null supprime une note existante ; l'absence de clé la conserve.
    if (_initialValues['audioUrl'] != _audioUrl) {
      data['audioUrl'] = _audioUrl;
    }

    return data;
  }

  Future<void> _submit() async {
    if (!_step1Valid || _submitting || _voiceBusy) return;

    final notifier = ref.read(advertisementProvider.notifier);
    final adId = _editedAdId;

    if (_isEditing) {
      if (adId == null) {
        setState(() => _error = 'Annonce introuvable.');
        return;
      }
      if (!_hasEdits) {
        Navigator.pop(context, false);
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = _isEditing
        ? await notifier.updateAdvertisement(adId!, _updatePayload())
        : await notifier.createAdvertisement(_createPayload());

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] != true) {
      setState(() => _error = result['message']?.toString() ??
          (_isEditing
              ? 'Modification impossible.'
              : 'Publication impossible.'));
      return;
    }

    if (!_isEditing) {
      // Publiée : le brouillon n'a plus de raison d'être.
      _draftSaveTimer?.cancel();
      await _draftStore.clear();
      if (!mounted) return;
    }
    Navigator.pop(context, true);
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
          initialChildSize: 0.82,
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
                            child: _step == 0 ? _buildStep1() : _buildStep2(),
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
            child: Icon(_isEditing ? Icons.edit_rounded : Icons.route_rounded,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEditing ? 'Modifier l’annonce' : 'Créer une annonce',
                    style: AppFonts.plusJakartaSans(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Étape ${_step + 1} sur 2',
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

  Widget _stepBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(child: _stepSegment(active: true)),
          const SizedBox(width: 8),
          Expanded(child: _stepSegment(active: _step >= 1)),
        ],
      ),
    );
  }

  Widget _stepSegment({required bool active}) => Container(
        height: 4,
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.slate200,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Future<void> _openHabitualRoutes() async {
    // Le formulaire en cours garde son brouillon ; choisir un trajet habituel
    // ne doit pas effacer des lieux saisis pour un autre voyage.
    if (!_isEditing && !_draftPending) await _saveDraft();
    if (!mounted) return;
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const RouteTemplatesScreen()));
    if (created == true && mounted) Navigator.pop(context, true);
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepBar(),
        if (!_isEditing) ...[
          FilledButton.tonalIcon(
              onPressed: _openHabitualRoutes,
              icon: const Icon(Icons.bookmarks_outlined),
              label: const Text('Utiliser un trajet habituel')),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                  'Les nouveaux trajets seront mémorisés automatiquement pour vos prochains départs.')),
        ],
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
          // L'ajout d'un lieu absent se fait depuis le sélecteur lui-même
          // (recherche Google Places + pointage sur carte).
          onZoneAdded: _addResolvedZone,
        ),
        const SizedBox(height: 14),
        _fieldLabel('Date et heure de départ'),
        _dateField(),
        if (_profileVehicleError != null) ...[
          Text(_profileVehicleError!),
          TextButton(
              onPressed: _loadRegisteredTransport,
              child: const Text('Réessayer')),
        ],
        if (_tripPlan != null)
          TripPlanEditor(
              value: _tripPlan!,
              zones: _zones,
              onChanged: (value) {
                setState(() => _tripPlan = value);
                _scheduleDraftSave();
              })
        else
          TextButton(
              onPressed: () => setState(() =>
                  _tripPlan = {'serviceType': 'trip', 'intermediateStops': []}),
              child: const Text('Ajouter le service et les arrêts')),
        if (_departureZoneId != null && _departureZoneId == _arrivalZoneId) ...[
          const SizedBox(height: 12),
          _warning('Le départ et l’arrivée doivent être différents.'),
        ],
      ],
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
                  _fieldLabel('Poids dispo. (kg)'),
                  _numberField(
                      _weightController, 'Ex : 50', Icons.scale_rounded),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isEditing) ...[
                    _fieldLabel('Ancien prix proposé (FCFA)'),
                    _numberField(
                        _priceController, 'À négocier', Icons.payments_rounded),
                  ] else ...[
                    _fieldLabel('Prix à négocier'),
                    const Text(
                        'Le client propose son colis et son offre. Vous négociez ensuite le tarif.'),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _fieldLabel('Description'),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: 200,
          style: AppFonts.manrope(fontSize: 14),
          decoration: _inputDecoration(
              'Ex : véhicule climatisé, départ confirmé.', null),
        ),
        const SizedBox(height: 18),
        _fieldLabel('Note vocale (optionnel)'),
        VoiceNoteField(
          value: _audioUrl,
          enabled: !_submitting,
          onChanged: (url) {
            setState(() {
              _audioUrl = url;
              _error = null;
            });
            // L'URL distante survit à la fermeture/reprise du brouillon,
            // contrairement au fichier temporaire du microphone.
            _scheduleDraftSave();
          },
          onBusyChanged: (busy) => setState(() => _voiceBusy = busy),
        ),
        if (_voiceBusy)
          const Text('Terminez ou supprimez la note vocale avant de publier.'),
        const SizedBox(height: 12),
        if (_error != null) ...[
          const SizedBox(height: 6),
          _warning(_error!, danger: true),
        ],
        const SizedBox(height: 4),
        // Récap du trajet.
        PcCard(
          color: AppTheme.teal50,
          child: Row(
            children: [
              Icon(Icons.route_rounded, color: AppTheme.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_zoneById(_departureZoneId)?.locationLabel ?? '—'}  →  ${_zoneById(_arrivalZoneId)?.locationLabel ?? '—'}'
                  '${_departureAt != null ? '  ·  ${_formatDate(_departureAt!)}' : ''}',
                  style: AppFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.teal700),
                ),
              ),
            ],
          ),
        ),
      ],
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
          : Row(
              children: [
                Expanded(
                  child: PcButton(
                    'Précédent',
                    variant: PcButtonVariant.secondary,
                    size: PcButtonSize.lg,
                    block: true,
                    onPressed: _voiceBusy || _submitting
                        ? null
                        : () => setState(() => _step = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: PcButton(
                    _isEditing ? 'Enregistrer' : 'Publier l’annonce',
                    icon: _isEditing
                        ? Icons.check_rounded
                        : Icons.campaign_rounded,
                    size: PcButtonSize.lg,
                    block: true,
                    loading: _submitting,
                    onPressed: _voiceBusy ? null : _submit,
                  ),
                ),
              ],
            ),
    );
  }

  // ---- Champs ----

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: AppFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate700)),
      );

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppFonts.manrope(fontSize: 14, color: AppTheme.slate400),
      prefixIcon:
          icon != null ? Icon(icon, size: 20, color: AppTheme.slate400) : null,
      filled: true,
      fillColor: AppTheme.cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
  }

  Widget _numberField(
      TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: _inputDecoration(hint, icon),
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickDateTime,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InputDecorator(
        decoration: _inputDecoration('', Icons.schedule_rounded),
        child: Text(
          _departureAt != null ? _formatDate(_departureAt!) : 'Choisir…',
          style: _departureAt != null
              ? AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w600)
              : AppFonts.manrope(fontSize: 14, color: AppTheme.slate400),
        ),
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

  static const _months = [
    'jan',
    'fév',
    'mar',
    'avr',
    'mai',
    'juin',
    'juil',
    'août',
    'sep',
    'oct',
    'nov',
    'déc'
  ];

  String _formatDate(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} · $hh:$mm';
  }
}
