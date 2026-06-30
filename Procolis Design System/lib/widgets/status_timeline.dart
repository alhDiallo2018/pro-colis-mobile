// mobile/lib/widgets/status_timeline.dart
import 'package:flutter/material.dart';
import 'package:procolis/models/parcel.dart';

class StatusTimeline extends StatelessWidget {
  final List<ParcelEvent> events;

  const StatusTimeline({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    // Trier les événements par date (du plus ancien au plus récent)
    final sortedEvents = List<ParcelEvent>.from(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Column(
      children: [
        for (int i = 0; i < sortedEvents.length; i++) ...[
          _buildTimelineItem(sortedEvents[i], isFirst: i == 0, isLast: i == sortedEvents.length - 1),
        ],
      ],
    );
  }

  Widget _buildTimelineItem(ParcelEvent event, {required bool isFirst, required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colonne de la timeline (icône + ligne)
        SizedBox(
          width: 40,
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: event.status.color,
                ),
                child: Icon(
                  _getStatusIcon(event.status),
                  size: 14,
                  color: Colors.white,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  color: event.status.color.withAlpha(100),
                ),
            ],
          ),
        ),
        // Contenu
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.status.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(event.timestamp),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (event.location != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          event.location!,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                if (event.userName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Par: ${event.userName}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.pending:
        return Icons.pending;
      case ParcelStatus.free:
        return Icons.gavel;  
      case ParcelStatus.confirmed:
        return Icons.check_circle;
      case ParcelStatus.pickedUp:
        return Icons.inventory;
      case ParcelStatus.inTransit:
        return Icons.local_shipping;
      case ParcelStatus.arrived:
        return Icons.location_on;
      case ParcelStatus.outForDelivery:
        return Icons.delivery_dining;
      case ParcelStatus.delivered:
        return Icons.check_circle;
      case ParcelStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}