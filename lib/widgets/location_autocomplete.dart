import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

class PlaceResult {
  final String description;
  final String placeId;
  final String mainText;
  final String secondaryText;

  PlaceResult({
    required this.description,
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] as Map<String, dynamic>?;
    return PlaceResult(
      description: json['description'] as String? ?? '',
      placeId: json['place_id'] as String? ?? '',
      mainText: structured?['main_text'] as String? ?? '',
      secondaryText: structured?['secondary_text'] as String? ?? '',
    );
  }
}

class LocationAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? placeholder;
  final IconData? prefixIcon;
  final String googleApiKey;
  final void Function(PlaceResult place)? onPlaceSelected;
  final void Function(double lat, double lng)? onCoordinates;
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
    required this.googleApiKey,
    this.onPlaceSelected,
    this.onCoordinates,
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
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
  bool _billingWarningShown = false;
  bool _isGeolocating = false;

  String _buildAddressFromComponents(List components) {
    final parts = <String>[];
    for (final c in components) {
      final types = (c['types'] as List?)?.cast<String>() ?? [];
      if (types.contains('plus_code')) continue;
      if (types.any((t) => ['route', 'street_number', 'neighborhood', 'sublocality'].contains(t))) {
        if (parts.isEmpty) parts.add(c['long_name'] as String);
      }
    }
    for (final c in components) {
      final types = (c['types'] as List?)?.cast<String>() ?? [];
      if (types.contains('plus_code')) continue;
      if (types.any((t) => ['locality', 'postal_town'].contains(t))) {
        parts.add(c['long_name'] as String);
        break;
      }
    }
    for (final c in components) {
      final types = (c['types'] as List?)?.cast<String>() ?? [];
      if (types.contains('country')) {
        parts.add(c['long_name'] as String);
        break;
      }
    }
    return parts.isNotEmpty ? parts.join(', ') : 'Position actuelle';
  }

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
        if (!_focusNode.hasFocus) _hideOverlay();
      });
    }
  }

  void _onTextChange() {
    _debounce?.cancel();
    final text = widget.controller.text;
    if (text == 'Position actuelle' || _isGeolocating) return;
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(text);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().length < 2 || widget.googleApiKey.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': query,
          'key': widget.googleApiKey,
          'language': 'fr',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((p) => PlaceResult.fromJson(p as Map<String, dynamic>))
              .take(6)
              .toList();
          setState(() {
            _suggestions = predictions;
            _showSuggestions = predictions.isNotEmpty;
          });
          if (_showSuggestions) _showOverlay();
        } else {
          if (data['status'] == 'REQUEST_DENIED' && mounted && !_billingWarningShown) {
            _billingWarningShown = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('API Google Maps : billing non activé sur le projet Google Cloud.'),
                duration: Duration(seconds: 6),
              ),
            );
          }
          setState(() {
            _suggestions = [];
            _showSuggestions = false;
          });
          _removeOverlay();
        }
      }
    } catch (_) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      _removeOverlay();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectPlace(PlaceResult place) {
    widget.controller.text = place.description;
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
    _hideOverlay();
    widget.onPlaceSelected?.call(place);

    _fetchPlaceCoordinates(place.placeId);
  }

  Future<void> _fetchPlaceCoordinates(String placeId) async {
    if (widget.onCoordinates == null) return;
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields': 'geometry',
          'key': widget.googleApiKey,
        },
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          if (location != null) {
            widget.onCoordinates?.call(
              (location['lat'] as num).toDouble(),
              (location['lng'] as num).toDouble(),
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _geolocate() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final lat = position.latitude;
      final lng = position.longitude;
      widget.onCoordinates?.call(lat, lng);

      try {
        _isGeolocating = true;
        final response = await _dio.get(
          'https://maps.googleapis.com/maps/api/geocode/json',
          queryParameters: {
            'latlng': '$lat,$lng',
            'key': widget.googleApiKey,
            'language': 'fr',
          },
        );
        _isGeolocating = false;
        if (response.statusCode == 200) {
          final data = response.data;
          if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
            final components = data['results'][0]['address_components'] as List?;
            final addr = components != null
                ? _buildAddressFromComponents(components)
                : data['results'][0]['formatted_address'] as String?;
            if (addr != null) {
              widget.controller.text = addr;
            }
          } else {
            if (data['status'] == 'REQUEST_DENIED' && mounted && !_billingWarningShown) {
              _billingWarningShown = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('API Google Maps : billing non activé sur le projet Google Cloud.'),
                  duration: Duration(seconds: 6),
                ),
              );
            }
            widget.controller.text = 'Position actuelle';
          }
        }
      } catch (_) {
        _isGeolocating = false;
        widget.controller.text = 'Position actuelle';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Géolocalisation: ${e.toString()}')),
        );
      }
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
          hintText: widget.hint ?? widget.placeholder ?? 'Rechercher une adresse ou une ville...',
          helperText: widget.helperText,
          labelStyle: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.withOpacity(0.5),
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
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: widget.validator,
      ),
    );
  }
}
