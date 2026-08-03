// lib/screens/driver/create_annonce_sheet.dart
//
// Modal multi-étapes de création d'une annonce de trajet (chauffeur).
// Étape 1 : Trajet (départ / arrivée / date).  Étape 2 : Capacité & prix.
// Aligné sur le CreateAnnonceDialog du web, en flux 2 étapes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/garage.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/form_draft_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/form_draft_ui.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/route_picker.dart';

/// Ouvre le modal de création d'annonce. Renvoie `true` si une annonce a été
/// publiée (le parent peut alors rafraîchir sa liste).
Future<bool?> showCreateAnnonceSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CreateAnnonceSheet(),
  );
}

class _CreateAnnonceSheet extends ConsumerStatefulWidget {
  const _CreateAnnonceSheet();

  @override
  ConsumerState<_CreateAnnonceSheet> createState() =>
      _CreateAnnonceSheetState();
}

class _CreateAnnonceSheetState extends ConsumerState<_CreateAnnonceSheet> {
  final ApiService _api = ApiService();

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

  List<Garage> _zones = [];
  String? _departureZoneId;
  String? _arrivalZoneId;
  DateTime? _departureAt;

  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draftStore = FormDraftStore(
      slot: 'annonce',
      ownerId: ref.read(authProvider).user?.id,
    );
    for (final controller in [
      _weightController,
      _priceController,
      _descriptionController,
    ]) {
      controller.addListener(_scheduleDraftSave);
    }
    _loadZones();
    _loadDraft();
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
      _descriptionController.text.trim().isNotEmpty;

  Map<String, dynamic> _draftPayload() => {
        'step': _step,
        'departureZoneId': _departureZoneId,
        'arrivalZoneId': _arrivalZoneId,
        'departureAt': _departureAt?.toIso8601String(),
        'weight': _weightController.text,
        'price': _priceController.text,
        'description': _descriptionController.text,
      };

  void _scheduleDraftSave() {
    if (_draftPending || _submitting) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 600), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (_draftPending || _submitting || !_hasContent) return;
    await _draftStore.save(_draftPayload());
  }

  void _restoreDraft() {
    final draft = _pendingDraft;
    if (draft == null) return;
    final data = draft.data;

    setState(() {
      _step = (data['step'] as num?)?.toInt() ?? 0;
      _departureZoneId = data['departureZoneId']?.toString();
      _arrivalZoneId = data['arrivalZoneId']?.toString();
      _departureAt = DateTime.tryParse(data['departureAt']?.toString() ?? '');
      _weightController.text = data['weight']?.toString() ?? '';
      _priceController.text = data['price']?.toString() ?? '';
      _descriptionController.text = data['description']?.toString() ?? '';
      _pendingDraft = null;
    });
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
          _zones = zones;
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
      _departureZoneId != null && _arrivalZoneId != null && _departureZoneId != _arrivalZoneId;

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
    if (!_hasContent) {
      if (mounted) Navigator.pop(context, false);
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

  Future<void> _submit() async {
    if (!_step1Valid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final dep = _zoneById(_departureZoneId);
    final arr = _zoneById(_arrivalZoneId);
    final data = <String, dynamic>{
      'departureZoneId': _departureZoneId,
      'arrivalZoneId': _arrivalZoneId,
      'departureCity': dep?.city,
      'arrivalCity': arr?.city,
      'departureAt': _departureAt?.toIso8601String(),
      'availableWeight': double.tryParse(_weightController.text.trim()),
      'proposedPrice': double.tryParse(_priceController.text.trim()),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    };

    final result = await _api.createAdvertisement(data);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == false) {
      setState(() =>
          _error = result['message']?.toString() ?? 'Publication impossible.');
      return;
    }

    // Publiée : le brouillon n'a plus de raison d'être.
    _draftSaveTimer?.cancel();
    await _draftStore.clear();
    if (!mounted) return;
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
            child: Icon(Icons.route_rounded,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Créer une annonce',
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
          // L'ajout d'un lieu absent se fait depuis le sélecteur lui-même
          // (recherche Google Places + pointage sur carte).
          onZoneAdded: _addResolvedZone,
        ),
        const SizedBox(height: 14),
        _fieldLabel('Date et heure de départ'),
        _dateField(),
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
                  _fieldLabel('Prix proposé (FCFA)'),
                  _numberField(
                      _priceController, 'Ex : 15000', Icons.payments_rounded),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _fieldLabel('Description (optionnel)'),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: 200,
          style: AppFonts.manrope(fontSize: 14),
          decoration: _inputDecoration(
              'Ex : véhicule climatisé, départ confirmé.', null),
        ),
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
              Icon(Icons.route_rounded,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_zoneById(_departureZoneId)?.city ?? '—'}  →  ${_zoneById(_arrivalZoneId)?.city ?? '—'}'
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
                    onPressed: () => setState(() => _step = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: PcButton(
                    'Publier l’annonce',
                    icon: Icons.campaign_rounded,
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
