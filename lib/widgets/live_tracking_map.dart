// lib/widgets/live_tracking_map.dart
//
// Carte du suivi client : départ, position réelle du chauffeur et destination.
//
// Réutilise l'intégration cartographique existante (`google_maps_flutter`) —
// aucune seconde solution cartographique n'est introduite. Chaque repère n'est
// affiché que si ses coordonnées sont réellement fournies : aucune coordonnée
// fictive n'est inventée ici. La position du chauffeur (optionnelle) apparaît
// uniquement quand le backend l'expose.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_theme.dart';

class LiveTrackingMap extends StatefulWidget {
  final double? departureLatitude;
  final double? departureLongitude;
  final double? arrivalLatitude;
  final double? arrivalLongitude;
  final double? driverLatitude;
  final double? driverLongitude;
  final double? driverAccuracy;
  final String? departureLabel;
  final String? arrivalLabel;

  const LiveTrackingMap({
    super.key,
    this.departureLatitude,
    this.departureLongitude,
    this.arrivalLatitude,
    this.arrivalLongitude,
    this.driverLatitude,
    this.driverLongitude,
    this.driverAccuracy,
    this.departureLabel,
    this.arrivalLabel,
  });

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  GoogleMapController? _mapController;

  @override
  void didUpdateWidget(covariant LiveTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Les marqueurs sont reconstruits par Flutter, puis la caméra suit la
    // nouvelle position reçue lors du polling sans intervention du client.
    if (oldWidget.driverLatitude != widget.driverLatitude ||
        oldWidget.driverLongitude != widget.driverLongitude) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitBounds();
      });
    }
  }

  LatLng? get _departure =>
      _point(widget.departureLatitude, widget.departureLongitude);
  LatLng? get _arrival =>
      _point(widget.arrivalLatitude, widget.arrivalLongitude);
  LatLng? get _driver => _point(widget.driverLatitude, widget.driverLongitude);

  LatLng? _point(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat, lng);
  }

  /// Tous les points réellement disponibles, pour centrer la carte.
  List<LatLng> get _points => [
        if (_departure != null) _departure!,
        if (_arrival != null) _arrival!,
        if (_driver != null) _driver!,
      ];

  /// Même une position chauffeur seule doit être visible : les anciennes
  /// zones ne possèdent pas toujours de coordonnées de départ/destination.
  bool get _canRenderMap => _points.isNotEmpty;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers() {
    return {
      if (_departure != null)
        Marker(
          markerId: const MarkerId('departure'),
          position: _departure!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Départ',
            snippet: widget.departureLabel ?? '',
          ),
        ),
      if (_arrival != null)
        Marker(
          markerId: const MarkerId('arrival'),
          position: _arrival!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: widget.arrivalLabel ?? '',
          ),
        ),
      if (_driver != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driver!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Position du chauffeur'),
        ),
    };
  }

  Set<Polyline> _buildPolyline() {
    final route = <LatLng>[
      if (_departure != null) _departure!,
      if (_driver != null) _driver!,
      if (_arrival != null) _arrival!,
    ];
    if (route.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: route,
        color: AppTheme.teal500,
        width: 4,
        geodesic: true,
      ),
    };
  }

  /// Cercle de précision fourni par le GPS du téléphone. Il matérialise
  /// honnêtement l'incertitude au lieu de présenter le marqueur comme un point
  /// mathématiquement exact lorsque le signal est moins précis.
  Set<Circle> _buildAccuracyCircle() {
    final driver = _driver;
    final accuracy = widget.driverAccuracy;
    if (driver == null ||
        accuracy == null ||
        !accuracy.isFinite ||
        accuracy <= 0) {
      return {};
    }
    return {
      Circle(
        circleId: const CircleId('driver_accuracy'),
        center: driver,
        radius: accuracy,
        fillColor: AppTheme.primary.withValues(alpha: 0.12),
        strokeColor: AppTheme.primary.withValues(alpha: 0.45),
        strokeWidth: 1,
      ),
    };
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final pad = math.max(maxLat - minLat, maxLng - minLng) * 0.2 + 0.01;
    return LatLngBounds(
      southwest: LatLng(minLat - pad, minLng - pad),
      northeast: LatLng(maxLat + pad, maxLng + pad),
    );
  }

  void _fitBounds() {
    final controller = _mapController;
    if (controller == null) return;
    final points = _points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 16),
      );
      return;
    }
    controller
        .animateCamera(CameraUpdate.newLatLngBounds(_boundsFor(points), 80));
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRenderMap) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.slate100,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Text(
          'Carte indisponible : coordonnées manquantes',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.slate500,
              ),
        ),
      );
    }

    final initialTarget = _points.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: initialTarget,
          zoom: _points.length == 1 ? 16 : 7,
        ),
        markers: _buildMarkers(),
        circles: _buildAccuracyCircle(),
        polylines: _buildPolyline(),
        mapType: MapType.normal,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        onMapCreated: (controller) {
          _mapController = controller;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _fitBounds();
          });
        },
      ),
    );
  }
}
