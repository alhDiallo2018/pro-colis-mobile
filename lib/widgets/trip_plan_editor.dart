import 'package:flutter/material.dart';
import '../models/garage.dart';
import 'garage_picker.dart';

/// Plan relatif au départ : décaler la date conserve les durées des escales.
/// Le serveur résout les noms et valide à nouveau ordre, terminus et capacité.
class TripPlanEditor extends StatelessWidget {
  const TripPlanEditor(
      {super.key,
      required this.value,
      required this.zones,
      required this.onChanged});
  final Map<String, dynamic> value;
  final List<Garage> zones;
  final ValueChanged<Map<String, dynamic>> onChanged;
  List<Map<String, dynamic>> get stops =>
      (value['intermediateStops'] as List? ?? [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
  void change(String key, dynamic next) => onChanged({...value, key: next});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 18),
        const Text('Service et arrêts',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.badge_outlined),
            title: Text(switch (value['serviceType']) {
              'gp' => 'GP · transport de colis',
              'shuttle' => 'Navette / Tata',
              _ => 'Voyage'
            }),
            subtitle: const Text(
                'Catégorie reprise de votre véhicule enregistré. Modifiable dans votre profil.')),
        if (value['serviceType'] == 'shuttle') ...[
          const SizedBox(height: 12),
          TextFormField(
              initialValue: value['lineNumber']?.toString() ?? '',
              maxLength: 40,
              decoration: const InputDecoration(
                  labelText: 'Numéro ou nom de ligne', hintText: 'Ex. 45'),
              onChanged: (v) => change('lineNumber', v)),
        ],
        const SizedBox(height: 12),
        const Text(
            'Chaque annonce correspond à un départ daté. Ajoutez les arrêts dans le sens du voyage. Les colis peuvent monter et descendre à ces arrêts.'),
        for (final (i, stop) in stops.indexed)
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(stop['name']?.toString() ?? 'Arrêt'),
              subtitle: Text('+ ${stop['offsetMinutes']} min après le départ'),
              trailing: IconButton(
                  tooltip: 'Retirer cet arrêt',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    final next = stops..removeAt(i);
                    change('intermediateStops', next);
                  })),
        OutlinedButton.icon(
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Ajouter un arrêt intermédiaire'),
            onPressed: () async {
              final place = await GaragePickerSheet.show(
                  context: context, garages: zones, title: 'Arrêt de passage');
              if (place == null || !context.mounted) return;
              String minutes = '';
              final offset = await showDialog<int>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                          title: Text('Passage à ${place.name}'),
                          content: TextField(
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Minutes après le départ',
                                  hintText: 'Ex. 30'),
                              onChanged: (v) => minutes = v),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Annuler')),
                            TextButton(
                                onPressed: () {
                                  final n = int.tryParse(minutes);
                                  if (n != null && n > 0) Navigator.pop(ctx, n);
                                },
                                child: const Text('Ajouter'))
                          ]));
              if (offset != null)
                change('intermediateStops', [
                  ...stops,
                  {
                    'zoneId': place.id,
                    'name': place.name,
                    'offsetMinutes': offset
                  }
                ]);
            }),
        const SizedBox(height: 12),
        TextFormField(
            initialValue: value['arrivalOffsetMinutes']?.toString() ?? '',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Durée totale jusqu’au terminus (minutes)',
                helperText: 'Ex. 90 pour 1 h 30 ; 1440 pour 24 h'),
            onChanged: (v) => change('arrivalOffsetMinutes', int.tryParse(v))),
        const SizedBox(height: 8),
        const Text(
            'Horaires prévus à confirmer avec le chauffeur. Un nouveau départ de la ligne nécessite une nouvelle annonce.',
            style: TextStyle(fontSize: 12)),
      ]);
}

Map<String, dynamic>? tripPlanFromItinerary(dynamic value) {
  if (value is! Map) return null;
  final stops = value['stops'] as List? ?? [];
  return {
    'serviceType': value['serviceType'],
    'lineNumber': value['lineNumber'],
    'intermediateStops':
        stops.length > 2 ? stops.sublist(1, stops.length - 1) : [],
    'arrivalOffsetMinutes': stops.isEmpty ? null : stops.last['offsetMinutes']
  };
}

Map<String, dynamic> itineraryFromTripPlan(
        Map<String, dynamic> plan, String? from, String? to) =>
    {
      'serviceType': plan['serviceType'] ?? 'trip',
      'lineNumber': plan['lineNumber'],
      'stops': [
        {'zoneId': from, 'offsetMinutes': 0},
        ...(plan['intermediateStops'] as List? ?? []),
        {'zoneId': to, 'offsetMinutes': plan['arrivalOffsetMinutes']}
      ],
    };
