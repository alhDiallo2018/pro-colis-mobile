import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/location_fix.dart';
import '../services/places_service.dart';
import '../theme/app_theme.dart';

export '../models/place.dart';

/// Champ de recherche d'un lieu (Google Places Autocomplete) avec, en option,
/// un bouton « utiliser ma position actuelle ».
///
/// Une sélection ou une géolocalisation produit toujours un [PlaceDetails]
/// complet (nom, adresse, coordonnées, `placeId`) exposé via [onPlace] ; les
/// rappels [onPlaceSelected], [onCoordinates] et [onPlaceDetails] sont
/// conservés pour la rétro-compatibilité des écrans existants.
class LocationAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? placeholder;
  final IconData? prefixIcon;

  /// Prédiction brute choisie dans les suggestions.
  final void Function(PlaceResult place)? onPlaceSelected;

  /// Coordonnées du lieu résolu (rétro-compatibilité).
  final void Function(double lat, double lng)? onCoordinates;

  /// Coordonnées + détails administratifs (rétro-compatibilité).
  final void Function(double lat, double lng, PlaceDetails details)?
      onPlaceDetails;

  /// Lieu complet résolu — le rappel à privilégier : il ne perd ni le nom, ni
  /// l'adresse, ni le `placeId`, ni les coordonnées.
  final void Function(PlaceDetails place)? onPlace;

  final bool showGeolocate;
  final String? Function(String?)? validator;
  final bool autofocus;
  final String? helperText;

  const LocationAutocomplete({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.placeholder,
    this.prefixIcon = Icons.location_on_outlined,
    this.onPlaceSelected,
    this.onCoordinates,
    this.onPlaceDetails,
    this.onPlace,
    this.showGeolocate = true,
    this.validator,
    this.autofocus = false,
    this.helperText,
  });

  @override
  State<LocationAutocomplete> createState() => _LocationAutocompleteState();
}

class _LocationAutocompleteState extends State<LocationAutocomplete> {
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  List<PlaceResult> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  Timer? _debounce;
  bool _billingWarningShown = false;
  bool _suppressListener = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      if (_suggestions.isNotEmpty) _showOverlay();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        // Le délai laisse le clic sur une suggestion se terminer ; le garde
        // mounted évite d'accéder au FocusNode après sa destruction.
        if (mounted && !_focusNode.hasFocus) _hideOverlay();
      });
    }
  }

  void _onTextChange() {
    if (_suppressListener) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(widget.controller.text);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final predictions = await PlacesService.autocomplete(query);
      if (!mounted) return;
      setState(() {
        _suggestions = predictions;
        _showSuggestions = predictions.isNotEmpty;
      });
      if (_showSuggestions) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } on PlacesApiException catch (error) {
      if (!mounted) return;
      _warnBillingIfNeeded(error);
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      _removeOverlay();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      _removeOverlay();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _warnBillingIfNeeded(PlacesApiException error) {
    if (_billingWarningShown) return;
    _billingWarningShown = true;
    final message = error.isConfigError
        ? 'API Google Maps : clé invalide ou non configurée.'
        : 'API Google Maps : service temporairement indisponible.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }

  void _selectPlace(PlaceResult place) {
    _suppressListener = true;
    widget.controller.text = place.description;
    _suppressListener = false;
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
    _hideOverlay();
    widget.onPlaceSelected?.call(place);

    _resolvePlace(place);
  }

  Future<void> _resolvePlace(PlaceResult place) async {
    if (widget.onCoordinates == null &&
        widget.onPlaceDetails == null &&
        widget.onPlace == null) {
      return;
    }
    final details = await PlacesService.placeDetails(place.placeId);
    if (!mounted) return;
    if (details == null || !details.hasCoordinates) {
      developer.log(
        'Détails ou coordonnées introuvables pour ${place.placeId}',
        name: 'LocationAutocomplete',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce lieu n’a pas pu être localisé précisément.'),
        ),
      );
      return;
    }

    // Le champ `name` des détails peut être vide : on retombe alors sur le
    // libellé principal de la prédiction, qui est le nom réel du lieu.
    final resolved = (details.name?.trim().isNotEmpty ?? false)
        ? details
        : details.copyWith(name: place.mainText);

    if (resolved.hasCoordinates) {
      widget.onCoordinates?.call(resolved.latitude!, resolved.longitude!);
      widget.onPlaceDetails
          ?.call(resolved.latitude!, resolved.longitude!, resolved);
    }
    widget.onPlace?.call(resolved);
  }

  /// Utilise la position GPS courante et tente d'en déduire un libellé lisible
  /// par géocodage inverse. Les coordonnées restent la source technique ; le
  /// texte affiché n'est qu'une représentation, jamais un remplacement.
  Future<void> _geolocate() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final position = await resolveCurrentPosition();
      final lat = position.latitude;
      final lng = position.longitude;

      final details = await PlacesService.reverseGeocode(lat, lng);
      if (!mounted) return;
      final label = details?.label;
      if (details == null || label == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Votre position est trouvée, mais sa localité est introuvable. '
              'Recherchez l’adresse par son nom.',
            ),
          ),
        );
        return;
      }

      _suppressListener = true;
      widget.controller.text = label;
      _suppressListener = false;

      widget.onCoordinates?.call(lat, lng);
      widget.onPlaceDetails?.call(lat, lng, details);
      widget.onPlace?.call(details);
    } catch (error, stackTrace) {
      developer.log(
        'Impossible de localiser et nommer la position courante',
        name: 'LocationAutocomplete',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(locationErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 2),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(_suggestions.length, (i) {
                    final s = _suggestions[i];
                    return InkWell(
                      onTap: () => _selectPlace(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.mainText,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (s.secondaryText.isNotEmpty)
                                    Text(
                                      s.secondaryText,
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Image.asset(
                      'assets/icons/powered_by_google.png',
                      height: 12,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _hideOverlay() {
    _removeOverlay();
    setState(() => _showSuggestions = false);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint ??
              widget.placeholder ??
              'Rechercher une adresse ou une ville...',
          helperText: widget.helperText,
          labelStyle: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, size: 20, color: Colors.blue)
              : null,
          suffixIcon: widget.showGeolocate
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.my_location,
                          size: 20, color: Colors.blue),
                      onPressed: _geolocate,
                      tooltip: 'Utiliser ma position actuelle',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                )
              : null,
          filled: true,
          fillColor: AppTheme.cardColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: widget.validator,
      ),
    );
  }
}
