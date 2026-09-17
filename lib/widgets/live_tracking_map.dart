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
    this.departureLabel,
    this.arrivalLabel,
  });

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  GoogleMapController? _mapController;

  LatLng? get _departure => _point(
      widget.departureLatitude, widget.departureLongitude);
  LatLng? get _arrival => _point(widget.arrivalLatitude, widget.arrivalLongitude);
  LatLng? get _driver => _point(widget.driverLatitude, widget.driverLongitude);

  LatLng? _point(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat, lng);
  }

  /// Tous les points réellement disponibles, pour centrer la carte.
  List<LatLng> get _points => [
        if (_departure != null) _departure!,
        if (_arrival != null) _arrival!,
        if (_driver != null) _driver!,
      ];

  /// Un seul point exploitable : il faut au moins deux coordonnées connues
  /// pour rendre une carte utile (départ/destination ou départ/chauffeur…).
  bool get _canRenderMap => _points.length >= 2;

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
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Départ',
            snippet: widget.departureLabel ?? '',
          ),
        ),
      if (_arrival != null)
        Marker(
          markerId: const MarkerId('arrival'),
          position: _arrival!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRose),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: widget.arrivalLabel ?? '',
          ),
        ),
      if (_driver != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driver!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure),
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
    if (points.length < 2) return;
    controller.animateCamera(CameraUpdate.newLatLngBounds(_boundsFor(points), 80));
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
        initialCameraPosition: CameraPosition(target: initialTarget, zoom: 7),
        markers: _buildMarkers(),
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
