import 'package:flutter/material.dart';
import '../services/journey_live_service.dart';

class JourneyLiveTile extends StatelessWidget {
  const JourneyLiveTile(
      {super.key, required this.advertisementId, this.enabled = true});
  final String advertisementId;
  final bool enabled;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: JourneyLiveService.instance,
      builder: (context, _) {
        final service = JourneyLiveService.instance;
        final sharing =
            service.active && service.advertisementId == advertisementId;
        return Card(
            child: SwitchListTile.adaptive(
                value: sharing,
                title: Text(service.starting
                    ? 'Acquisition GPS…'
                    : sharing
                        ? 'Ce véhicule est suivi en direct'
                        : 'Démarrer le suivi de ce départ'),
                subtitle: Text(service.error ??
                    'Partagez la position GPS précise de ce véhicule avec les clients pendant ce départ, y compris en arrière-plan. Arrêtez le suivi à la fin.'),
                secondary: const Icon(Icons.gps_fixed),
                onChanged: service.starting || (!enabled && !sharing)
                    ? null
                    : (value) async {
                        if (!value) {
                          await service.stop();
                          return;
                        }
                        // Une activation est un choix explicite pour CE départ. Le système
                        // demande la permission GPS si elle n’a pas encore été accordée.
                        await service.start(advertisementId);
                      }));
      });
}
