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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  parcel.trackingNumber,
                                  style: AppTheme.mono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.slate500,
                                  ),
                                ),
                              ),
                              if (parcel.isUrgent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.red50,
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.flash_on_rounded,
                                          color: AppTheme.red500,
                                          size: 12),
                                      Text(
                                        'Express >>',
                                        style: TextStyle(
                                          color: AppTheme.red500,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
              const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RouteLabel(
                    label: 'Départ',
                    city: parcel.departureGarageName,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    color: AppTheme.slate300, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: _RouteLabel(
                    label: 'Arrivée',
                    city: parcel.arrivalGarageName ?? 'Arrivée',
                  ),
                ),
              ],
            ),
            if (parcel.isInsured || parcel.estimatedDeliveryDate != null || parcel.price != null) ...[
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (parcel.estimatedDeliveryDate != null) ...[
                        const Icon(Icons.schedule_rounded,
                            color: AppTheme.textSecondary, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _formatEta(parcel.estimatedDeliveryDate!),
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        '${parcel.weight} kg',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (parcel.isInsured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.green50,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded,
                                  color: AppTheme.green700, size: 12),
                              SizedBox(width: 3),
                              Text(
                                'Assuré',
                                style: TextStyle(
                                  color: AppTheme.green700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (parcel.price != null)
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatEta(DateTime date) {
  final diff = date.difference(DateTime.now());
  if (diff.isNegative) return 'Arrivé';
  if (diff.inDays > 0) return '${diff.inDays} j';
  if (diff.inHours > 0) return '~${diff.inHours} h';
  return '${diff.inMinutes.clamp(1, 59)} min';
}

class _RouteLabel extends StatelessWidget {
  final String label;
  final String city;

  const _RouteLabel({required this.label, required this.city});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.slate400,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
