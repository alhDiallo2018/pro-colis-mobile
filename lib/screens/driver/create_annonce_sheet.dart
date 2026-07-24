// lib/screens/driver/create_annonce_sheet.dart
//
// Modal multi-étapes de création d'une annonce de trajet (chauffeur).
// Étape 1 : Trajet (départ / arrivée / date).  Étape 2 : Capacité & prix.
// Aligné sur le CreateAnnonceDialog du web, en flux 2 étapes.

import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/garage.dart';
import '../../services/api_service.dart';
import '../../services/places_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/route_picker.dart';
import '../../widgets/location_autocomplete.dart';

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

class _CreateAnnonceSheet extends StatefulWidget {
  const _CreateAnnonceSheet();

  @override
  State<_CreateAnnonceSheet> createState() => _CreateAnnonceSheetState();
}

class _CreateAnnonceSheetState extends State<_CreateAnnonceSheet> {
  final ApiService _api = ApiService();

  int _step = 0; // 0 = trajet, 1 = capacité & prix
  bool _loadingGarages = true;
  bool _submitting = false;
  String? _error;

  List<Garage> _garages = [];
  String? _departureId;
  String? _arrivalId;
  DateTime? _departureAt;

  // Repli "Autre lieu" : résolution Google Places → zone (pending).
  final _departurePlaceCtrl = TextEditingController();
  final _arrivalPlaceCtrl = TextEditingController();
  PlaceResult? _pendingDepPlace;
  PlaceResult? _pendingArrPlace;
  bool _resolvingDep = false;
  bool _resolvingArr = false;

  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGarages();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _departurePlaceCtrl.dispose();
    _arrivalPlaceCtrl.dispose();
    super.dispose();
  }

  /// Résout le lieu Places choisi en zone (pending), l'ajoute à la liste et
  /// l'affecte au départ ou à l'arrivée.
  Future<void> _resolvePlaceToField({required bool departure, required double lat, required double lng}) async {
    final place = departure ? _pendingDepPlace : _pendingArrPlace;
    if (place == null) return;
    setState(() {
      if (departure) {
        _resolvingDep = true;
      } else {
        _resolvingArr = true;
      }
    });
    final garage = await _api.resolvePlaceZone(
      placeId: place.placeId.isNotEmpty ? place.placeId : null,
      name: place.mainText.isNotEmpty ? place.mainText : place.description,
      latitude: lat,
      longitude: lng,
    );
    if (!mounted) return;
    setState(() {
      if (departure) {
        _resolvingDep = false;
      } else {
        _resolvingArr = false;
      }
      if (garage != null) {
        if (!_garages.any((g) => g.id == garage.id)) {
          _garages = [..._garages, garage];
        }
        if (departure) {
          _departureId = garage.id;
        } else {
          _arrivalId = garage.id;
        }
      }
    });
  }

  Future<void> _loadGarages() async {
    try {
      final garages = await _api.getAllGarages();
      if (mounted) {
        setState(() {
          _garages = garages;
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
      _departureId != _arrivalId;

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
  }

  Future<void> _submit() async {
    if (!_step1Valid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final dep = _garageById(_departureId);
    final arr = _garageById(_arrivalId);
    final data = <String, dynamic>{
      'departureGarageId': _departureId,
      'arrivalGarageId': _arrivalId,
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
      setState(() => _error =
          result['message']?.toString() ?? 'Publication impossible.');
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
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
                          child:
                              _step == 0 ? _buildStep1() : _buildStep2(),
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
            child: const Icon(Icons.route_rounded,
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
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded, color: AppTheme.slate500),
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
        const SizedBox(height: 8),
        RoutePicker(
          garages: _garages,
          initialDeparture: _garageById(_departureId),
          initialArrival: _garageById(_arrivalId),
          onDepartureChanged: (g) {
            setState(() => _departureId = g?.id);
          },
          onArrivalChanged: (g) {
            setState(() => _arrivalId = g?.id);
          },
        ),
        const SizedBox(height: 12),
        Text('Zone introuvable ? Ajoutez un lieu (Google Places)',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.slate500)),
        const SizedBox(height: 8),
        LocationAutocomplete(
          controller: _departurePlaceCtrl,
          label: _resolvingDep ? 'Résolution…' : 'Autre lieu de départ',
          prefixIcon: Icons.add_location_alt_rounded,
          hint: 'Ville / adresse de départ',
          googleApiKey: PlacesService.googleApiKey,
          onPlaceSelected: (p) => _pendingDepPlace = p,
          onCoordinates: (lat, lng) => _resolvePlaceToField(departure: true, lat: lat, lng: lng),
        ),
        const SizedBox(height: 8),
        LocationAutocomplete(
          controller: _arrivalPlaceCtrl,
          label: _resolvingArr ? 'Résolution…' : "Autre lieu d'arrivée",
          prefixIcon: Icons.add_location_alt_rounded,
          hint: "Ville / adresse d'arrivée",
          googleApiKey: PlacesService.googleApiKey,
          onPlaceSelected: (p) => _pendingArrPlace = p,
          onCoordinates: (lat, lng) => _resolvePlaceToField(departure: false, lat: lat, lng: lng),
        ),
        const SizedBox(height: 14),
        _fieldLabel('Date et heure de départ'),
        _dateField(),
        if (_departureId != null && _departureId == _arrivalId) ...[
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
                  _numberField(_weightController, 'Ex : 50', Icons.scale_rounded),
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
        const SizedBox(height: 14),
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
              const Icon(Icons.route_rounded,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_garageById(_departureId)?.city ?? '—'}  →  ${_garageById(_arrivalId)?.city ?? '—'}'
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
              onPressed:
                  _step1Valid ? () => setState(() => _step = 1) : null,
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
        ],
      ),
    );
  }

  static const _months = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
    'juil', 'août', 'sep', 'oct', 'nov', 'déc'
  ];

  String _formatDate(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} · $hh:$mm';
  }
}
