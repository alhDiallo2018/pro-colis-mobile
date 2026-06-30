import 'package:flutter/material.dart';

import '../models/parcel.dart';
import '../theme/app_theme.dart';

class ParcelCard extends StatelessWidget {
  final Parcel parcel;
  final VoidCallback onTap;

  const ParcelCard({
    super.key,
    required this.parcel,
    required this.onTap,
  });

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
    final status = AppTheme.statusColors(parcel.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.softShadow(alpha: 0.06),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
                      color: status.background,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(
                      _getTypeIcon(parcel.type),
                      color: status.foreground,
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
                          style: AppTheme.mono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.slate500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          parcel.receiverName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          parcel.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      parcel.status.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: status.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              if (parcel.price != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${parcel.weight} kg',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(
                      '${parcel.price!.toStringAsFixed(0)} FCFA',
                      style: AppTheme.mono(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.teal700,
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
