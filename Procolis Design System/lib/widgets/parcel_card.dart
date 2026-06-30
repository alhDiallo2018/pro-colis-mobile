import 'package:flutter/material.dart';

import '../models/parcel.dart';

class ParcelCard extends StatelessWidget {
  final Parcel parcel;
  final VoidCallback onTap;

  const ParcelCard({
    super.key,
    required this.parcel,
    required this.onTap,
  });

  Color _getStatusColor(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.pending:
        return Colors.orange;
      case ParcelStatus.free:
        return Colors.purple;
      case ParcelStatus.confirmed:
        return Colors.blue;
      case ParcelStatus.pickedUp:
        return Colors.purple;
      case ParcelStatus.inTransit:
        return Colors.indigo;
      case ParcelStatus.arrived:
        return Colors.teal;
      case ParcelStatus.outForDelivery:
        return Colors.lightBlue;
      case ParcelStatus.delivered:
        return Colors.green;
      case ParcelStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getTypeIcon(ParcelType type) {
    switch (type) {
      case ParcelType.document:
        return Icons.description;
      case ParcelType.package:
        return Icons.inventory;
      case ParcelType.fragile:
        return Icons.warning;
      case ParcelType.perishable:
        return Icons.food_bank;
      case ParcelType.valuable:
        return Icons.attach_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _getStatusColor(parcel.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getTypeIcon(parcel.type),
                      color: _getStatusColor(parcel.status),
                      size: 24,
                    ),
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
                          parcel.receiverName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          parcel.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(parcel.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      parcel.status.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(parcel.status),
                      ),
                    ),
                  ),
                ],
              ),
              if (parcel.price != null) ...[
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${parcel.weight} kg',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '${parcel.price!.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B6E3A),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
