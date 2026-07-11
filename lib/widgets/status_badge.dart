import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/parcel.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final ParcelStatus status;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.statusColors(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: colors.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status),
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.pending:
        return 'En attente';
      case ParcelStatus.free:
        return 'Libre';
      case ParcelStatus.confirmed:
        return 'Confirmé';
      case ParcelStatus.pickedUp:
        return 'Ramassé';
      case ParcelStatus.inTransit:
        return 'En transit';
      case ParcelStatus.arrived:
        return 'Arrivé';
      case ParcelStatus.outForDelivery:
        return 'En livraison';
      case ParcelStatus.delivered:
        return 'Livré';
      case ParcelStatus.cancelled:
        return 'Annulé';
    }
  }
}
