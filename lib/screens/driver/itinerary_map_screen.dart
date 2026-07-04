import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/procolis_design_system.dart';

class ItineraryMapScreen extends StatefulWidget {
  final double? departureLat;
  final double? departureLng;
  final double? arrivalLat;
  final double? arrivalLng;
  final String departureName;
  final String arrivalName;

  const ItineraryMapScreen({
    super.key,
    this.departureLat,
    this.departureLng,
    this.arrivalLat,
    this.arrivalLng,
    required this.departureName,
    required this.arrivalName,
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
  };

  static const _defaultCity = _CityCoords(5.3600, -4.0083);

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
      _resolveCity(widget.departureName).latitude;

  double get _resolvedDepartureLng =>
      widget.departureLng ??
      _resolveCity(widget.departureName).longitude;

  double get _resolvedArrivalLat =>
      widget.arrivalLat ??
      _resolveCity(widget.arrivalName).latitude;

  double get _resolvedArrivalLng =>
      widget.arrivalLng ??
      _resolveCity(widget.arrivalName).longitude;

  _CityCoords _resolveCity(String name) {
    final key = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return _cityFallbacks[key] ?? _defaultCity;
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

  bool get _sameLocation =>
      (_resolvedDepartureLat == _resolvedArrivalLat &&
          _resolvedDepartureLng == _resolvedArrivalLng);

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
          if (_sameLocation)
            Center(
              child: ProcolisCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        size: 40, color: AppTheme.teal500),
                    const SizedBox(height: 12),
                    Text(
                      'Même ville',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.departureName} → ${widget.arrivalName}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.slate500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
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
                        if (!hasBothCoords &&
                            !_sameLocation) ...[
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
                    if (_sameLocation) ...[
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
