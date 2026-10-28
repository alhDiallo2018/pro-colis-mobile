import 'live_journeys_map.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/advertisement.dart';

class JourneyStopsCard extends StatelessWidget {
  const JourneyStopsCard({super.key, required this.journey});
  final Advertisement journey;
  @override
  Widget build(BuildContext context) {
    if (journey.stops.isEmpty) return const SizedBox.shrink();
    final points = journey.stops
        .where((s) => s['latitude'] is num && s['longitude'] is num)
        .toList();
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(journey.serviceLabel,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              if (journey.vehicleReference.isNotEmpty)
                Text(
                    'Véhicule ${journey.vehicleReference} · ${journey.driverName}'),
              OutlinedButton.icon(
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Voir ce véhicule en direct'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          LiveJourneysMap(advertisementId: journey.id)))),
              const SizedBox(height: 8),
              const Text(
                  'Déposez le colis à un arrêt et choisissez une remise plus loin dans le sens du trajet.'),
              for (final (i, stop) in journey.stops.indexed)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(stop['name']?.toString() ?? 'Arrêt'),
                    subtitle: Text(_time(stop['scheduledAt'])),
                    trailing: Text(i == 0
                        ? 'Départ'
                        : i == journey.stops.length - 1
                            ? 'Terminus'
                            : 'Escale')),
              if (points.isNotEmpty)
                OutlinedButton.icon(
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Voir les arrêts sur la carte'),
                    onPressed: () {
                      showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (ctx) => SafeArea(
                              child: SizedBox(
                                  height: MediaQuery.sizeOf(ctx).height * .7,
                                  child: Column(children: [
                                    ListTile(
                                        title: Text(journey.serviceLabel),
                                        trailing: IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () =>
                                                Navigator.pop(ctx))),
                                    Expanded(
                                        child: GoogleMap(
                                            initialCameraPosition: CameraPosition(
                                                target: LatLng(
                                                    (points.first['latitude']
                                                            as num)
                                                        .toDouble(),
                                                    (points.first['longitude']
                                                            as num)
                                                        .toDouble()),
                                                zoom: 11),
                                            onMapCreated: (controller) {
                                              if (points.length < 2) return;
                                              final lats = points
                                                  .map((s) =>
                                                      (s['latitude'] as num)
                                                          .toDouble())
                                                  .toList()
                                                ..sort();
                                              final lngs = points
                                                  .map((s) =>
                                                      (s['longitude'] as num)
                                                          .toDouble())
                                                  .toList()
                                                ..sort();
                                              // Afficher les arrêts sans inventer une route routière ou aérienne.
                                              controller.animateCamera(
                                                  CameraUpdate.newLatLngBounds(
                                                      LatLngBounds(
                                                          southwest: LatLng(
                                                              lats.first,
                                                              lngs.first),
                                                          northeast: LatLng(
                                                              lats.last,
                                                              lngs.last)),
                                                      48));
                                            },
                                            markers: points
                                                .map((s) => Marker(
                                                    markerId: MarkerId(
                                                        s['zoneId'].toString()),
                                                    position: LatLng(
                                                        (s['latitude'] as num)
                                                            .toDouble(),
                                                        (s['longitude'] as num)
                                                            .toDouble()),
                                                    infoWindow: InfoWindow(
                                                        title:
                                                            s['name']?.toString(),
                                                        snippet: _time(s['scheduledAt']))))
                                                .toSet(),
                                            mapToolbarEnabled: false)),
                                    const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                            'Arrêts et horaires annoncés par le transporteur.'))
                                  ]))));
                    }),
              const Text(
                  'La réservation reste en attente jusqu’à l’acceptation du transporteur.',
                  style: TextStyle(fontSize: 12)),
            ])));
  }

  static String _time(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Horaire à confirmer';
    return '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} (prévu)';
  }
}
