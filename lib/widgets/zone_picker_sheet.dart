// mobile/lib/widgets/zone_picker_sheet.dart
// Ajout d'une zone de départ / arrivée absente de la liste, par recherche
// Google Places ou par pointage direct sur la carte.
//
// La zone créée part en "pending" côté API : utilisable tout de suite par son
// auteur, visible des autres une fois validée.

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:procolis/theme/fonts.dart';

import '../models/garage.dart';
import '../services/api_service.dart';
import '../services/places_service.dart';
import '../theme/app_theme.dart';
import 'location_autocomplete.dart';
import 'pc_components.dart';

class ZonePickerSheet {
  /// Renvoie le **garage miroir** de la zone retenue : c'est cet identifiant
  /// qu'attendent `departureZoneId` / `arrivalZoneId`.
  static Future<Garage?> show({
    required BuildContext context,
    String? initialQuery,
    String title = 'Ajouter une zone',
  }) {
    return showModalBottomSheet<Garage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ZonePickerContent(initialQuery: initialQuery, title: title),
    );
  }
}

class _ZonePickerContent extends StatefulWidget {
  final String? initialQuery;
  final String title;

  const _ZonePickerContent({this.initialQuery, required this.title});

  @override
  State<_ZonePickerContent> createState() => _ZonePickerContentState();
}

const LatLng _defaultCenter = LatLng(14.6928, -17.4467); // Dakar
const double _defaultZoom = 6;
const double _pickedZoom = 13;

class _ZonePickerContentState extends State<_ZonePickerContent> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  GoogleMapController? _mapCtrl;
  LatLng? _picked;
  PlaceDetails? _details;
  // L'utilisateur a-t-il repris la main sur le nom ? Si oui, on cesse de
  // l'écraser à chaque déplacement du repère.
  bool _nameTouched = false;
  bool _settingSuggestedName = false;
  bool _busy = false;
  bool _geocoding = false;
  String? _error;
  int _geocodeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialQuery ?? '';
    _nameCtrl.addListener(() {
      if (!_settingSuggestedName &&
          _nameCtrl.text != (widget.initialQuery ?? '')) {
        _nameTouched = true;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  void _applyPlace(PlaceDetails place) {
    final lat = place.latitude;
    final lng = place.longitude;
    if (lat == null || lng == null) return;
    if (!place.hasGeographicLabel) {
      setState(() => _error =
          'Ce point ne contient pas de localité identifiable. Essayez une autre adresse.');
      return;
    }
    final target = LatLng(lat, lng);
    setState(() {
      _picked = target;
      _details = place;
      _error = null;
      final suggested = _placeName(place);
      if (!_nameTouched && suggested != null && suggested.isNotEmpty) {
        _setSuggestedName(suggested);
      }
    });
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(target, _pickedZoom));
  }

  /// Modifie le nom depuis le géocodeur sans le confondre avec une saisie
  /// manuelle. L'utilisateur pourra ensuite toujours personnaliser ce nom.
  void _setSuggestedName(String value) {
    _settingSuggestedName = true;
    _nameCtrl.text = value;
    _settingSuggestedName = false;
  }

  String? _placeName(PlaceDetails place) => place.zoneName;

  /// Géocodage inverse d'un point pointé sur la carte : sans lui, la zone
  /// partirait sans ville ni pays.
  Future<void> _reverseGeocode(LatLng target) async {
    final generation = ++_geocodeGeneration;
    setState(() {
      _picked = target;
      _details = null;
      _geocoding = true;
      _error = null;
      if (!_nameTouched) _setSuggestedName('');
    });
    PlaceDetails? details;
    try {
      details =
          await PlacesService.reverseGeocode(target.latitude, target.longitude);
    } catch (error, stackTrace) {
      developer.log(
        'Échec du géocodage inverse du point choisi',
        name: 'ZonePickerSheet',
        error: error,
        stackTrace: stackTrace,
      );
      details = null;
    }
    // Deux clics rapides peuvent terminer dans le désordre : seule la réponse
    // associée au dernier repère a le droit de modifier la localité affichée.
    if (!mounted || generation != _geocodeGeneration) return;
    setState(() {
      _geocoding = false;
      _details = details?.hasGeographicLabel == true ? details : null;
      final suggested = details == null ? null : _placeName(details);
      if (!_nameTouched && suggested != null && suggested.isNotEmpty) {
        _setSuggestedName(suggested);
      }
      if (_details == null) {
        _error = 'Localité introuvable pour ce point. Touchez un lieu voisin '
            'ou recherchez son adresse par son nom.';
      }
    });
  }

  Future<void> _submit() async {
    final target = _picked;
    if (target == null) {
      setState(
          () => _error = 'Choisissez un lieu sur la carte ou dans la liste.');
      return;
    }
    if (_details == null || !_details!.hasGeographicLabel) {
      setState(() => _error =
          'Attendez que le nom de la localité soit identifié avant de valider.');
      return;
    }
    final label = _nameCtrl.text.trim();
    if (label.length < 2) {
      setState(
          () => _error = 'Donnez un nom à cette zone (2 caractères minimum).');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    Garage? garage;
    try {
      // Le backend reçoit simultanément le nom lisible et les données
      // administratives : il ne doit jamais reconstruire la zone à partir des
      // seules coordonnées.
      garage = await _api.resolvePlaceZone(
        placeId: _details?.placeId,
        name: label,
        displayName: _details?.label ?? label,
        latitude: target.latitude,
        longitude: target.longitude,
        city: _details?.city,
        region: _details?.region,
        country: _details?.country,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Impossible d’enregistrer la zone résolue',
        name: 'ZonePickerSheet',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (!mounted) return;
    if (garage == null) {
      setState(() {
        _busy = false;
        _error =
            "Impossible d'ajouter cette zone. Réessayez ou contactez le support.";
      });
      return;
    }
    Navigator.pop(context, garage);
  }

  @override
  Widget build(BuildContext context) {
    final locality = [_details?.city, _details?.region, _details?.country]
        .where((e) => e != null && e.isNotEmpty)
        .join(' · ');

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title,
                          style: AppFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                    ),
                    IconButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: AppTheme.slate400),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    Text(
                      'Recherchez le lieu, ou pointez-le sur la carte s’il n’apparaît pas '
                      'dans les suggestions. Vous pourrez l’utiliser immédiatement ; il sera '
                      'validé ensuite par l’équipe.',
                      style: AppFonts.manrope(
                          fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    LocationAutocomplete(
                      controller: _searchCtrl,
                      label: 'Rechercher un lieu',
                      prefixIcon: Icons.search_rounded,
                      hint: 'Ville, quartier, repère…',
                      onPlace: _applyPlace,
                    ),
                    if (_details != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.teal50,
                          border: Border.all(color: AppTheme.teal100),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Localité sélectionnée',
                                style: AppFonts.manrope(
                                    fontSize: 11, color: AppTheme.slate500)),
                            const SizedBox(height: 2),
                            Text(
                              _details!.zoneName!,
                              style: AppFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary),
                            ),
                            if (_details!.formattedAddress != null &&
                                _details!.formattedAddress != _details!.name)
                              Text(
                                _details!.formattedAddress!,
                                style: AppFonts.manrope(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: SizedBox(
                        height: 220,
                        child: Stack(
                          children: [
                            GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _picked ?? _defaultCenter,
                                zoom: _picked != null
                                    ? _pickedZoom
                                    : _defaultZoom,
                              ),
                              onMapCreated: (c) => _mapCtrl = c,
                              onTap: _busy ? null : _reverseGeocode,
                              markers: _picked == null
                                  ? {}
                                  : {
                                      Marker(
                                        markerId: const MarkerId('zone'),
                                        position: _picked!,
                                        draggable: !_busy,
                                        onDragEnd: _reverseGeocode,
                                      ),
                                    },
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                            ),
                            Positioned(
                              left: 8,
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusSm),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                        _geocoding
                                            ? Icons.sync_rounded
                                            : Icons.touch_app_rounded,
                                        size: 14,
                                        color: AppTheme.slate500),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _geocoding
                                            ? 'Lecture de l’adresse…'
                                            : 'Touchez la carte ou déplacez le repère pour ajuster.',
                                        style: AppFonts.manrope(
                                            fontSize: 11,
                                            color: AppTheme.slate500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameCtrl,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: 'Nom de la zone',
                        hintText: 'Ex : Mbour, Gare routière',
                        helperText: locality.isNotEmpty ? locality : null,
                        prefixIcon:
                            const Icon(Icons.pin_drop_rounded, size: 20),
                      ),
                    ),
                    if (_details?.label != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 14, color: AppTheme.slate400),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _details!.label!,
                              style: AppFonts.manrope(
                                  fontSize: 11.5, color: AppTheme.slate500),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.red50,
                          border: Border.all(color: AppTheme.red100),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(_error!,
                            style: AppFonts.manrope(
                                fontSize: 12.5, color: AppTheme.red500)),
                      ),
                    ],
                    const SizedBox(height: 18),
                    PcButton(
                      'Utiliser cette zone',
                      icon: Icons.check_rounded,
                      block: true,
                      loading: _busy,
                      onPressed: _picked == null ||
                              _details == null ||
                              _geocoding ||
                              _busy
                          ? null
                          : _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
