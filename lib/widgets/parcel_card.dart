import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/parcel.dart';
import '../theme/app_theme.dart';

/// Carte colis alignée sur le composant ParcelCard du design system :
/// en-tête (QR + n° suivi mono + badge statut), trajet (Départ → Arrivée),
/// bande méta (poids / délai) + prix.
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
        return Icons.description_rounded;
      case ParcelType.package:
        return Icons.inventory_2_rounded;
      case ParcelType.fragile:
        return Icons.warning_amber_rounded;
      case ParcelType.perishable:
        return Icons.food_bank_rounded;
      case ParcelType.valuable:
        return Icons.diamond_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = AppTheme.statusColors(parcel.status);
    final hasMeta = parcel.estimatedDeliveryDate != null || parcel.price != null;

    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.slate200),
            boxShadow: AppTheme.shadowSm(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête : QR + n° de suivi + badge statut.
              Row(
                children: [
                  const Icon(Icons.qr_code_2_rounded,
                      size: 18, color: AppTheme.slate400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      parcel.trackingNumber,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.mono(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate600,
                      ),
                    ),
                  ),
                  if (parcel.isUrgent) ...[
                    Text('»',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.red400)),
                    const SizedBox(width: 8),
                  ],
                  _StatusPill(status: status, label: parcel.status.label),
                ],
              ),
              const SizedBox(height: 14),
              // Trajet.
              Row(
                children: [
                  Expanded(
                    child: _RouteLabel(
                      label: 'Départ',
                      city: parcel.departureGarageName,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.local_shipping_rounded,
                        size: 20, color: AppTheme.teal400),
                  ),
                  Expanded(
                    child: _RouteLabel(
                      label: 'Arrivée',
                      city: parcel.arrivalGarageName ?? '—',
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              if (hasMeta) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.slate200),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Meta(Icons.scale_rounded, '${parcel.weight} kg'),
                    if (parcel.estimatedDeliveryDate != null) ...[
                      const SizedBox(width: 14),
                      _Meta(Icons.schedule_rounded,
                          _formatEta(parcel.estimatedDeliveryDate!)),
                    ],
                    const Spacer(),
                    if (parcel.price != null)
                      Text(
                        '${parcel.price!.toStringAsFixed(0)} FCFA',
                        style: AppTheme.mono(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.teal600,
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

class _StatusPill extends StatelessWidget {
  final ProcolisStatusColors status;
  final String label;

  const _StatusPill({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: status.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: status.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.slate400),
        const SizedBox(width: 5),
        Text(text,
            style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.slate500)),
      ],
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
  final bool alignEnd;

  const _RouteLabel({
    required this.label,
    required this.city,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.slate400,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
