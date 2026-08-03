// mobile/lib/widgets/zone_picker_sheet.dart
// Ajout d'une zone de départ / arrivée absente de la liste, par recherche
// Google Places ou par pointage direct sur la carte.
//
// La zone créée part en "pending" côté API : utilisable tout de suite par son
// auteur, visible des autres une fois validée.

import 'package:dio/dio.dart';
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
      builder: (_) => _ZonePickerContent(initialQuery: initialQuery, title: title),
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
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  GoogleMapController? _mapCtrl;
  LatLng? _picked;
  PlaceDetails? _details;
  // L'utilisateur a-t-il repris la main sur le nom ? Si oui, on cesse de
  // l'écraser à chaque déplacement du repère.
  bool _nameTouched = false;
  bool _busy = false;
  bool _geocoding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialQuery ?? '';
    _nameCtrl.addListener(() {
      if (_nameCtrl.text != (widget.initialQuery ?? '')) _nameTouched = true;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  void _applyPlace(double lat, double lng, PlaceDetails? details) {
    final target = LatLng(lat, lng);
    setState(() {
      _picked = target;
      _details = details;
      _error = null;
      final suggested = details?.city ?? details?.formattedAddress?.split(',').first;
      if (!_nameTouched && suggested != null && suggested.isNotEmpty) {
        _nameCtrl.text = suggested;
      }
    });
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(target, _pickedZoom));
  }

  /// Géocodage inverse d'un point pointé sur la carte : sans lui, la zone
  /// partirait sans ville ni pays.
  Future<void> _reverseGeocode(LatLng target) async {
    setState(() {
      _picked = target;
      _geocoding = true;
      _error = null;
    });
    PlaceDetails? details;
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '${target.latitude},${target.longitude}',
          'key': PlacesService.googleApiKey,
          'language': 'fr',
        },
      );
      final data = res.data;
      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final first = data['results'][0];
        details = PlaceDetails.fromComponents(
          first['address_components'] as List?,
          placeId: first['place_id'] as String?,
          formattedAddress: first['formatted_address'] as String?,
        );
      }
    } catch (_) {
      // Quota ou billing absent : on garde les coordonnées, sans libellé.
    }
    if (!mounted) return;
    setState(() {
      _geocoding = false;
      _details = details;
      final suggested = details?.city ?? details?.formattedAddress?.split(',').first;
      if (!_nameTouched && suggested != null && suggested.isNotEmpty) {
        _nameCtrl.text = suggested;
      }
    });
  }

  Future<void> _submit() async {
    final target = _picked;
    if (target == null) {
      setState(() => _error = 'Choisissez un lieu sur la carte ou dans la liste.');
      return;
    }
    final label = _nameCtrl.text.trim();
    if (label.length < 2) {
      setState(() => _error = 'Donnez un nom à cette zone (2 caractères minimum).');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final garage = await _api.resolvePlaceZone(
      placeId: _details?.placeId,
      name: label,
      displayName: _details?.formattedAddress ?? label,
      latitude: target.latitude,
      longitude: target.longitude,
      city: _details?.city,
      region: _details?.region,
      country: _details?.country,
    );

    if (!mounted) return;
    if (garage == null) {
      setState(() {
        _busy = false;
        _error = "Impossible d'ajouter cette zone. Réessayez ou contactez le support.";
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
                      googleApiKey: PlacesService.googleApiKey,
                      onPlaceDetails: (lat, lng, details) => _applyPlace(lat, lng, details),
                    ),
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
                                zoom: _picked != null ? _pickedZoom : _defaultZoom,
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
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
                                            fontSize: 11, color: AppTheme.slate500),
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
                        prefixIcon: const Icon(Icons.pin_drop_rounded, size: 20),
                      ),
                    ),
                    if (_picked != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.my_location_rounded,
                              size: 14, color: AppTheme.slate400),
                          const SizedBox(width: 6),
                          Text(
                            '${_picked!.latitude.toStringAsFixed(5)}, '
                            '${_picked!.longitude.toStringAsFixed(5)}',
                            style: AppFonts.manrope(
                                fontSize: 11.5, color: AppTheme.slate500),
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
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
                      onPressed: _picked == null || _busy ? null : _submit,
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
