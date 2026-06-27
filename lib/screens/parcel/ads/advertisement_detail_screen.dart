import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/theme/app_theme.dart';

class AdvertisementDetailScreen extends StatelessWidget {
  final Parcel parcel;

  const AdvertisementDetailScreen({
    super.key,
    required this.parcel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          parcel.description,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statut
            _buildStatusChip(parcel),
            const SizedBox(height: 20),
            
            // Description
            _buildInfoSection('📦 Description', parcel.description),
            const SizedBox(height: 16),
            
            // Itinéraire
            _buildInfoSection('📍 Itinéraire', 
              'Départ: ${parcel.departureGarageName}\n→ Arrivée: ${parcel.arrivalGarageName ?? 'Non spécifié'}'),
            const SizedBox(height: 16),
            
            // Détails
            _buildInfoSection('📋 Détails',
              'Poids: ${parcel.formattedWeight}\n'
              'Type: ${parcel.type.label}\n'
              'Prix proposé: ${parcel.formattedProposedPrice}\n'
              'Date: ${DateFormat('dd/MM/yyyy à HH:mm').format(parcel.createdAt)}'),
            
            // Offres
            if (parcel.hasBids) ...[
              const SizedBox(height: 16),
              _buildInfoSection('💰 Offres reçues', 
                '${parcel.bids.length} offre${parcel.bids.length > 1 ? 's' : ''}'),
              const SizedBox(height: 8),
              ...parcel.bids.map((bid) => _buildBidCard(bid)).toList(),
            ],
            
            // Infos expéditeur
            const SizedBox(height: 16),
            _buildInfoSection('👤 Expéditeur',
              'Nom: ${parcel.senderName}\n'
              'Téléphone: ${parcel.senderPhone}'),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(Parcel parcel) {
    Color color;
    String label;
    IconData icon;
    
    if (parcel.isFree) {
      color = Colors.purple;
      label = '🔓 Libre service';
      icon = Icons.lock_open_rounded;
    } else if (parcel.isPending) {
      color = AppTheme.warningColor;
      label = '⏳ En attente';
      icon = Icons.hourglass_empty_rounded;
    } else if (parcel.isConfirmed) {
      color = AppTheme.primaryBlue;
      label = '✅ Confirmé';
      icon = Icons.check_circle_rounded;
    } else if (parcel.isDelivered) {
      color = AppTheme.successColor;
      label = '🎉 Livré';
      icon = Icons.celebration_rounded;
    } else if (parcel.isCancelled) {
      color = AppTheme.errorColor;
      label = '❌ Annulé';
      icon = Icons.cancel_rounded;
    } else {
      color = AppTheme.textSecondary;
      label = parcel.status.label;
      icon = Icons.info_rounded;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBidCard(Bid bid) {
    final isSelected = parcel.selectedBidId == bid.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected 
            ? AppTheme.successColor.withValues(alpha: 0.08) 
            : AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected 
              ? AppTheme.successColor 
              : AppTheme.textSecondary.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
            child: Text(
              bid.driverName[0].toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bid.driverName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '💰 ${bid.price.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (bid.message != null)
                  Text(
                    bid.message!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  '📅 ${bid.formattedDate}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Acceptée',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bid.status.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: bid.status.color.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                bid.status.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: bid.status.color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}