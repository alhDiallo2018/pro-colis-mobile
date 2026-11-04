// Carte Citymapper-style : titre + StopList verticale avec DataQualityTag,
// option carte en bottom sheet. Préserve le lien vers le suivi GPS live.
import 'live_journeys_map.dart';
import 'transit/data_quality_tag.dart';
import 'transit/line_badge.dart' as ui;
import 'transit/stop_list.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/advertisement.dart';
import '../theme/app_theme.dart';

class JourneyStopsCard extends StatelessWidget {
  const JourneyStopsCard({super.key, required this.journey});
  final Advertisement journey;

  // On lit le numéro de ligne + opérateur du metadata si publié via TransitLine.
  ui.TransitOperator? get _operator {
    final meta = journey.transitLine;
    if (meta == null) return null;
    return meta['operator'] == 'aftu' ? ui.TransitOperator.aftu : ui.TransitOperator.ddd;
  }

  @override
  Widget build(BuildContext context) {
    if (journey.stops.isEmpty) return const SizedBox.shrink();
    final op = _operator;
    final number = journey.lineNumber;
    final points = journey.stops
        .where((s) => s['latitude'] is num && s['longitude'] is num)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (op != null && number != null && number.isNotEmpty) ...[
              ui.LineBadge(operator: op, number: number, size: ui.LineBadgeSize.md),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                journey.serviceLabel,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
            ),
          ]),
          if (journey.vehicleReference.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Véhicule ${journey.vehicleReference} · ${journey.driverName}',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            icon: const Icon(Icons.gps_fixed, size: 18),
            label: const Text('Voir ce véhicule en direct'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => LiveJourneysMap(advertisementId: journey.id))),
          ),

          const SizedBox(height: 12),
          Text(
            'Déposez le colis à un arrêt et choisissez une remise plus loin dans le sens du trajet.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),

          StopList(items: [
            for (var i = 0; i < journey.stops.length; i++)
              _stopItem(journey.stops[i], i, journey.stops.length),
          ]),

          if (points.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Voir les arrêts sur la carte'),
              onPressed: () => _openMap(context, points),
            ),
          ),
          const SizedBox(height: 8),
          Text('La réservation reste en attente jusqu’à l’acceptation du transporteur.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  StopListItem _stopItem(Map stop, int index, int total) {
    final scheduled = stop['scheduledAt']?.toString();
    final hasSchedule = DateTime.tryParse(scheduled ?? '') != null;
    return StopListItem(
      key: '${stop['zoneId']}-$index',
      label: stop['name']?.toString() ?? 'Arrêt ${index + 1}',
      tone: index == 0 ? StopTone.origin
          : index == total - 1 ? StopTone.destination
          : StopTone.defaultTone,
      meta: hasSchedule
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              const DataQualityTag(quality: DataQuality.scheduled),
              const SizedBox(width: 6),
              Text(_formatShortTime(scheduled!),
                style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
            ])
          : DataQualityTag(
              quality: DataQuality.estimated,
              label: '+${stop['offsetMinutes']} min',
            ),
    );
  }

  static String _formatShortTime(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openMap(BuildContext context, List<Map<String, dynamic>> points) {
    return showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .7,
          child: Column(children: [
            ListTile(
              title: Text(journey.serviceLabel),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    (points.first['latitude'] as num).toDouble(),
                    (points.first['longitude'] as num).toDouble()),
                  zoom: 11,
                ),
                onMapCreated: (controller) {
                  if (points.length < 2) return;
                  final lats = points.map((s) => (s['latitude'] as num).toDouble()).toList()..sort();
                  final lngs = points.map((s) => (s['longitude'] as num).toDouble()).toList()..sort();
                  controller.animateCamera(CameraUpdate.newLatLngBounds(
                    LatLngBounds(
                      southwest: LatLng(lats.first, lngs.first),
                      northeast: LatLng(lats.last, lngs.last)),
                    48));
                },
                markers: {
                  for (var i = 0; i < points.length; i++)
                    Marker(
                      markerId: MarkerId(points[i]['zoneId'].toString()),
                      position: LatLng(
                        (points[i]['latitude'] as num).toDouble(),
                        (points[i]['longitude'] as num).toDouble()),
                      infoWindow: InfoWindow(
                        title: '${i + 1}. ${points[i]['name']?.toString() ?? ''}',
                        snippet: points[i]['scheduledAt'] == null
                            ? 'Horaire estimé' : 'Horaire : ${_formatShortTime(points[i]['scheduledAt'].toString())}'),
                    ),
                },
                polylines: points.length < 2 ? {} : {
                  Polyline(
                    polylineId: const PolylineId('stops'),
                    color: AppTheme.teal500,
                    width: 4,
                    points: [for (final p in points) LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble())],
                  ),
                },
                mapToolbarEnabled: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Arrêts annoncés par l\'opérateur — ligne tracée à titre indicatif.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
