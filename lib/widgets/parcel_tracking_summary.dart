import 'package:flutter/material.dart';
import '../models/parcel.dart';
import '../services/api/client.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

/// Le colis est le premier repère du suivi. Ses informations essentielles
/// restent lisibles sans ouvrir une autre fiche, même avec de grands caractères.
class ParcelTrackingSummary extends StatelessWidget {
  const ParcelTrackingSummary(
      {super.key,
      required this.parcel,
      required this.onDetails,
      required this.onReceipt,
      required this.onShare,
      this.onTrack});
  final Parcel parcel;
  final VoidCallback onDetails, onReceipt, onShare;
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final color = switch (parcel.status) {
      ParcelStatus.delivered => AppTheme.green700,
      ParcelStatus.cancelled => AppTheme.red500,
      _ => AppTheme.primary,
    };
    return PcCard(
      key: const ValueKey('tracking-parcel-summary'),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.teal50,
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.inventory_2_outlined,
                  color: AppTheme.primary, size: 28)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Votre colis',
                    style: theme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                // Le numéro est sélectionnable et conserve toutes ses lettres.
                SelectableText(parcel.trackingNumber,
                    style: AppTheme.mono(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600)),
              ])),
          IconButton(
              onPressed: onShare,
              tooltip: 'Partager le suivi',
              icon: const Icon(Icons.ios_share_rounded),
              color: AppTheme.textSecondary),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(parcel.status.label,
                  style: theme.labelLarge
                      ?.copyWith(color: color, fontWeight: FontWeight.w800))),
          if (parcel.isUrgent) const PcTag.express(),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (parcel.photoUrls.isNotEmpty) ...[
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                    ApiClient.resolveMediaUrl(parcel.photoUrls.first),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    semanticLabel: 'Photo du colis',
                    errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: AppTheme.slate100,
                        child: Icon(Icons.inventory_2_outlined,
                            color: AppTheme.textSecondary)))),
            const SizedBox(width: 12),
          ],
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    parcel.description.trim().isEmpty
                        ? parcel.type.label
                        : parcel.description,
                    key: const ValueKey('tracking-parcel-description'),
                    style: theme.titleMedium?.copyWith(
                        fontSize: 17,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 6, children: [
                  Text(parcel.type.label,
                      style: theme.bodyMedium
                          ?.copyWith(color: AppTheme.textSecondary)),
                  Text(parcel.formattedWeight,
                      style: theme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700)),
                  if (parcel.agreedPrice != null)
                    Text(parcel.formattedAgreedPrice,
                        style: theme.bodyMedium?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700)),
                ]),
              ])),
        ]),
        const SizedBox(height: 20),
        Divider(height: 1, color: AppTheme.slate200),
        const SizedBox(height: 16),
        _place(
            context,
            'Départ',
            parcel.departureZoneName.trim().isEmpty
                ? parcel.departureCity ?? 'À préciser'
                : parcel.departureZoneName,
            Icons.trip_origin_rounded),
        const SizedBox(height: 12),
        _place(
            context,
            'Destination',
            parcel.arrivalZoneName ?? parcel.arrivalCity ?? 'À préciser',
            Icons.location_on_outlined),
        if (parcel.receiverName.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Destinataire',
              style: theme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(parcel.receiverName,
              style: theme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
          if (parcel.receiverAddress?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(parcel.receiverAddress!,
                style:
                    theme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
          ],
        ],
        const SizedBox(height: 20),
        if (onTrack != null && !parcel.isFinished) ...[
          PcButton('Suivre le colis sur la carte',
              block: true, icon: Icons.near_me_outlined, onPressed: onTrack),
          const SizedBox(height: 10),
        ],
        PcActionButtons(children: [
          PcButton('Détails du colis',
              variant: onTrack == null
                  ? PcButtonVariant.primary
                  : PcButtonVariant.secondary,
              icon: Icons.info_outline_rounded,
              size: PcButtonSize.sm,
              onPressed: onDetails),
          PcButton('Reçu / QR',
              icon: Icons.qr_code_rounded,
              size: PcButtonSize.sm,
              variant: PcButtonVariant.secondary,
              onPressed: onReceipt),
        ]),
      ]),
    );
  }

  Widget _place(
          BuildContext context, String label, String value, IconData icon) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: AppTheme.primary)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 3),
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ])),
      ]);
}
