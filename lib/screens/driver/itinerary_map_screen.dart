import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/garage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/procolis_design_system.dart';

class ItineraryMapScreen extends StatefulWidget {
  final double? departureLat;
  final double? departureLng;
  final double? arrivalLat;
  final double? arrivalLng;
  final String departureName;
  final String arrivalName;
  final List<Garage>? garages;

  const ItineraryMapScreen({
    super.key,
    this.departureLat,
    this.departureLng,
    this.arrivalLat,
    this.arrivalLng,
    required this.departureName,
    required this.arrivalName,
    this.garages,
  });

  @override
  State<ItineraryMapScreen> createState() => _ItineraryMapScreenState();
}

class _ItineraryMapScreenState extends State<ItineraryMapScreen> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _departureMarkerIcon;
  BitmapDescriptor? _arrivalMarkerIcon;
  bool _iconsLoaded = false;

  static const Map<String, _CityCoords> _cityFallbacks = {
    // Sénégal
    'dakar': _CityCoords(14.6937, -17.4441),
    'dakar plateau': _CityCoords(14.6937, -17.4441),
    'pikine': _CityCoords(14.7645, -17.3988),
    'guediawaye': _CityCoords(14.7745, -17.3956),
    'rufisque': _CityCoords(14.7155, -17.2725),
    'thiès': _CityCoords(14.7894, -16.9277),
    'thies': _CityCoords(14.7894, -16.9277),
    'mbour': _CityCoords(14.4189, -16.9667),
    'saly': _CityCoords(14.4390, -17.0137),
    'joal': _CityCoords(14.1744, -16.8478),
    'fadiouth': _CityCoords(14.1529, -16.8200),
    'saint-louis': _CityCoords(16.0179, -16.4896),
    'saint louis': _CityCoords(16.0179, -16.4896),
    'ndar': _CityCoords(16.0179, -16.4896),
    'touba': _CityCoords(14.8622, -15.8743),
    'diourbel': _CityCoords(14.6487, -16.2337),
    'kaolack': _CityCoords(14.1822, -16.2532),
    'fatick': _CityCoords(14.3335, -16.4115),
    'ziguinchor': _CityCoords(12.5608, -16.2753),
    'kolda': _CityCoords(12.8919, -14.9414),
    'tambacounda': _CityCoords(13.7721, -13.6711),
    'tamba': _CityCoords(13.7721, -13.6711),
    'ké dou gou': _CityCoords(12.5577, -12.1806),
    'kedougou': _CityCoords(12.5577, -12.1806),
    'matam': _CityCoords(15.6555, -13.2556),
    'luga': _CityCoords(15.6187, -16.2278),
    'louga': _CityCoords(15.6187, -16.2278),
    'bambey': _CityCoords(14.7000, -16.4667),
    'tivaouane': _CityCoords(14.9500, -16.8167),
    'mbacké': _CityCoords(14.8000, -15.9000),
    'mbacke': _CityCoords(14.8000, -15.9000),
    'mbaké': _CityCoords(14.8000, -15.9000),
    'sébikotane': _CityCoords(14.7333, -17.1333),
    'sebikotane': _CityCoords(14.7333, -17.1333),
    'bargny': _CityCoords(14.7000, -17.2333),
    'diamniadio': _CityCoords(14.7167, -17.1833),
    // Mali
    'bamako': _CityCoords(12.6392, -8.0029),
    'sikasso': _CityCoords(11.3176, -5.6665),
    'kayes': _CityCoords(14.4443, -11.0989),
    'mopti': _CityCoords(14.4897, -4.1833),
    'ségou': _CityCoords(13.4317, -6.2157),
    'segou': _CityCoords(13.4317, -6.2157),
    'gao': _CityCoords(16.2667, -0.0500),
    'tombouctou': _CityCoords(16.7666, -3.0026),
    // Guinée
    'conakry': _CityCoords(9.6412, -13.5784),
    'nzérékoré': _CityCoords(7.7478, -8.8256),
    'nzerekore': _CityCoords(7.7478, -8.8256),
    'kankan': _CityCoords(10.3833, -9.3000),
    'kindia': _CityCoords(10.0473, -12.8598),
    'labé': _CityCoords(11.3167, -12.2833),
    'labe': _CityCoords(11.3167, -12.2833),
    // Côte d'Ivoire (existants)
    'abidjan': _CityCoords(5.3600, -4.0083),
    'yamoussoukro': _CityCoords(6.8276, -5.2893),
    'bouaké': _CityCoords(7.6905, -5.0304),
    'bouake': _CityCoords(7.6905, -5.0304),
    'daloa': _CityCoords(6.8774, -6.4503),
    'san-pédro': _CityCoords(4.7485, -6.6363),
    'san-pedro': _CityCoords(4.7485, -6.6363),
    'san pedro': _CityCoords(4.7485, -6.6363),
    'korhogo': _CityCoords(9.4580, -5.6298),
    'man': _CityCoords(7.4125, -7.5538),
    'abengourou': _CityCoords(6.7283, -3.4964),
    'gagnoa': _CityCoords(6.1318, -5.9506),
    'divo': _CityCoords(5.8377, -5.3575),
    // Burkina Faso
    'ouagadougou': _CityCoords(12.3714, -1.5197),
    'ouaga': _CityCoords(12.3714, -1.5197),
    'bobo-dioulasso': _CityCoords(11.1781, -4.2978),
    'bobo': _CityCoords(11.1781, -4.2978),
    // Bénin
    'cotonou': _CityCoords(6.3703, 2.3912),
    'porto-novo': _CityCoords(6.4969, 2.6289),
    'parakou': _CityCoords(9.3370, 2.6337),
    // Gambie
    'banjul': _CityCoords(13.4549, -16.5790),
    'serrekunda': _CityCoords(13.4384, -16.6743),
    'serekunda': _CityCoords(13.4384, -16.6743),
    'brikama': _CityCoords(13.2754, -16.6485),
    // France (pour les envois internationaux)
    'paris': _CityCoords(48.8566, 2.3522),
  };

  static const _defaultCity = _CityCoords(14.6937, -17.4441); // Dakar par défaut

  @override
  void initState() {
    super.initState();
    _createMarkerIcons();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _createMarkerIcons() async {
    _departureMarkerIcon = await _buildLabeledMarker(
      'D',
      AppTheme.green500,
      Colors.white,
    );
    _arrivalMarkerIcon = await _buildLabeledMarker(
      'A',
      AppTheme.red400,
      Colors.white,
    );
    if (mounted) {
      setState(() => _iconsLoaded = true);
    }
  }

  Future<BitmapDescriptor> _buildLabeledMarker(
    String label,
    Color bgColor,
    Color textColor,
  ) async {
    const size = 64.0;
    const borderWidth = 4.0;
    const borderRadius = 16.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, size, size),
        const Radius.circular(borderRadius),
      ),
      paint..color = Colors.white,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          borderWidth,
          borderWidth,
          size - borderWidth * 2,
          size - borderWidth * 2,
        ),
        const Radius.circular(borderRadius - 2),
      ),
      paint..color = bgColor,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          fontFamily: 'Poppins',
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  double get _resolvedDepartureLat =>
      widget.departureLat ??
      _resolveGarageLat(widget.departureName) ??
      _resolveCity(widget.departureName).latitude;

  double get _resolvedDepartureLng =>
      widget.departureLng ??
      _resolveGarageLng(widget.departureName) ??
      _resolveCity(widget.departureName).longitude;

  double get _resolvedArrivalLat =>
      widget.arrivalLat ??
      _resolveGarageLat(widget.arrivalName) ??
      _resolveCity(widget.arrivalName).latitude;

  double get _resolvedArrivalLng =>
      widget.arrivalLng ??
      _resolveGarageLng(widget.arrivalName) ??
      _resolveCity(widget.arrivalName).longitude;

  Garage? _findGarage(String name) {
    if (widget.garages == null || widget.garages!.isEmpty) return null;
    final key = name.trim().toLowerCase();
    for (final g in widget.garages!) {
      if (g.name.trim().toLowerCase() == key || g.city.trim().toLowerCase() == key) {
        return g;
      }
    }
    return null;
  }

  double? _resolveGarageLat(String name) => _findGarage(name)?.latitude;
  double? _resolveGarageLng(String name) => _findGarage(name)?.longitude;

  _CityCoords _resolveCity(String name) {
    // 1) Exact match
    final key = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (_cityFallbacks.containsKey(key)) return _cityFallbacks[key]!;

    // 2) Parse city from garage names like "Garage Dakar Centre" → extract "Dakar"
    final words = key.split(' ').where((w) => w.length > 2).toList();
    for (final word in words) {
      if (_cityFallbacks.containsKey(word)) return _cityFallbacks[word]!;
    }

    // 3) Try substring matching: check each fallback key if it appears in the name
    for (final entry in _cityFallbacks.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }

    return _defaultCity;
  }

  LatLng get _departureLatLng =>
      LatLng(_resolvedDepartureLat, _resolvedDepartureLng);

  LatLng get _arrivalLatLng =>
      LatLng(_resolvedArrivalLat, _resolvedArrivalLng);

  BitmapDescriptor get _departureIcon =>
      _departureMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

  BitmapDescriptor get _arrivalIcon =>
      _arrivalMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('departure'),
        position: _departureLatLng,
        icon: _departureIcon,
        infoWindow: InfoWindow(
          title: 'Départ',
          snippet: widget.departureName,
        ),
      ),
      Marker(
        markerId: const MarkerId('arrival'),
        position: _arrivalLatLng,
        icon: _arrivalIcon,
        infoWindow: InfoWindow(
          title: 'Arrivée',
          snippet: widget.arrivalName,
        ),
      ),
    };
  }

  Set<Polyline> _buildPolyline() {
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_departureLatLng, _arrivalLatLng],
        color: AppTheme.teal500,
        width: 4,
        geodesic: true,
      ),
    };
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  String _formatDuration(double distanceKm) {
    final avgSpeedKmh = 60.0;
    final hours = distanceKm / avgSpeedKmh;
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h == 0 && m == 0) return 'Moins d\'1 min';
    if (h == 0) return '${m} min';
    if (m == 0) return '$h h';
    return '${h}h ${m.toString().padLeft(2, '0')} min';
  }

  void _fitBounds() {
    if (_mapController == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        min(_departureLatLng.latitude, _arrivalLatLng.latitude) - 0.5,
        min(_departureLatLng.longitude, _arrivalLatLng.longitude) - 0.5,
      ),
      northeast: LatLng(
        max(_departureLatLng.latitude, _arrivalLatLng.latitude) + 0.5,
        max(_departureLatLng.longitude, _arrivalLatLng.longitude) + 0.5,
      ),
    );
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance(
      _resolvedDepartureLat,
      _resolvedDepartureLng,
      _resolvedArrivalLat,
      _resolvedArrivalLng,
    );

    final distanceText =
        distance < 0.1 ? '-- km' : '${distance.toStringAsFixed(1)} km';
    final durationText =
        distance < 0.1 ? '--' : _formatDuration(distance);

    final hasBothCoords =
        widget.departureLat != null &&
        widget.departureLng != null &&
        widget.arrivalLat != null &&
        widget.arrivalLng != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Itinéraire'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.trip_origin, size: 16, color: AppTheme.green500),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.departureName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 18, color: AppTheme.slate400),
                ),
                Flexible(
                  child: Text(
                    widget.arrivalName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.location_on,
                    size: 18, color: AppTheme.red400),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (_resolvedDepartureLat + _resolvedArrivalLat) / 2,
                (_resolvedDepartureLng + _resolvedArrivalLng) / 2,
              ),
              zoom: 7,
            ),
            markers: _iconsLoaded ? _buildMarkers() : {},
            polylines: _buildPolyline(),
            mapType: MapType.normal,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              Future.delayed(const Duration(milliseconds: 300), _fitBounds);
            },
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: ProcolisCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.route,
                            size: 20, color: AppTheme.teal500),
                        const SizedBox(width: 8),
                        Text(
                          'Détails du trajet',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                        ),
                        if (!hasBothCoords) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.amber50,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusXs),
                            ),
                            child: Text(
                              'Estimé',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.amber700,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    _RouteDetailRow(
                      label: 'Distance',
                      value: distanceText,
                      icon: Icons.straighten_rounded,
                    ),
                    const Divider(height: 18),
                    _RouteDetailRow(
                      label: 'Durée estimée',
                      value: durationText,
                      icon: Icons.schedule_rounded,
                    ),
                    const Divider(height: 18),
                    _RouteDetailRow(
                      label: 'Départ',
                      value: widget.departureName,
                      icon: Icons.trip_origin,
                    ),
                    const Divider(height: 18),
                    _RouteDetailRow(
                      label: 'Arrivée',
                      value: widget.arrivalName,
                      icon: Icons.location_on,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityCoords {
  final double latitude;
  final double longitude;
  const _CityCoords(this.latitude, this.longitude);
}

class _RouteDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RouteDetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.slate400),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.slate500,
                fontSize: 12,
              ),
        ),
        const Spacer(),
        SelectableText(
          value,
          style: AppTheme.mono(fontSize: 14, color: AppTheme.textPrimary),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}
