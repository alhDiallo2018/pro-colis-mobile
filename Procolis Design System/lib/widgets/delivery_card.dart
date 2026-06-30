import 'package:flutter/material.dart';
import '../models/parcel.dart';

class DeliveryCard extends StatelessWidget {
  final Parcel parcel;
  final VoidCallback onPickup;
  final VoidCallback onDeliver;
  final bool isPickupEnabled;
  final bool isDeliverEnabled;

  const DeliveryCard({
    super.key,
    required this.parcel,
    required this.onPickup,
    required this.onDeliver,
    this.isPickupEnabled = false,
    this.isDeliverEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.orange, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parcel.trackingNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'De: ${parcel.senderName}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'À: ${parcel.receiverName}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPickupEnabled ? onPickup : null,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Ramassage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isDeliverEnabled ? onDeliver : null,
                    icon: const Icon(Icons.delivery_dining, size: 18),
                    label: const Text('Livrer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
