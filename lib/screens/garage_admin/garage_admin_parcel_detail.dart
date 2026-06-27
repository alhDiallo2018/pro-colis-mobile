// mobile/lib/screens/garage_admin/garage_admin_parcel_detail.dart
import 'package:flutter/material.dart';
import 'package:procolis/widgets/app_logo.dart';

import '../../models/parcel.dart';
import '../../services/api_service.dart';

class GarageAdminParcelDetailScreen extends StatefulWidget {
  final Parcel parcel;

  const GarageAdminParcelDetailScreen({super.key, required this.parcel});

  @override
  State<GarageAdminParcelDetailScreen> createState() => _GarageAdminParcelDetailScreenState();
}

class _GarageAdminParcelDetailScreenState extends State<GarageAdminParcelDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isUpdating = false;

  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF0F4F8);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final Parcel updatedParcel = await _apiService.updateParcelStatus(widget.parcel.id, newStatus);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut mis à jour avec succès'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, updatedParcel);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 24, isWhite: false),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.parcel.trackingNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0.5,
        shadowColor: Colors.grey.shade200,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryBlue),
            onPressed: () => setState(() {}),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildStatusCard(),
            if (widget.parcel.status == ParcelStatus.pending ||
                widget.parcel.status == ParcelStatus.confirmed) ...[
              const SizedBox(height: 16),
              _buildActionsCard(),
            ],
            if (widget.parcel.isDelivered) ...[
              const SizedBox(height: 16),
              _buildDeliveryInfoCard(),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== INFORMATION CARD ====================
  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.info, color: primaryBlue, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Informations du colis',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              label: 'Numéro de suivi',
              value: widget.parcel.trackingNumber,
              isBold: true,
            ),
            _buildInfoRow(label: 'Expéditeur', value: widget.parcel.senderName),
            _buildInfoRow(label: 'Destinataire', value: widget.parcel.receiverName),
            _buildInfoRow(label: 'Téléphone', value: widget.parcel.receiverPhone),
            _buildInfoRow(
              label: 'Description',
              value: widget.parcel.description,
              maxLines: 2,
            ),
            _buildInfoRow(label: 'Poids', value: '${widget.parcel.weight} kg'),
            _buildInfoRow(label: 'Type', value: widget.parcel.type.label),
            if (widget.parcel.price != null)
              _buildInfoRow(
                label: 'Prix',
                value: '${widget.parcel.price!.toInt()} FCFA',
                isPrice: true,
              ),
            _buildInfoRow(label: 'Départ', value: widget.parcel.departureGarageName),
            if (widget.parcel.arrivalGarageName != null)
              _buildInfoRow(label: 'Arrivée', value: widget.parcel.arrivalGarageName!),
            _buildInfoRow(label: 'Créé le', value: _formatDate(widget.parcel.createdAt)),
            if (widget.parcel.isUrgent)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      'URGENT',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== STATUS CARD ====================
  Widget _buildStatusCard() {
    final statusColor = widget.parcel.status.color;
    final isDelivered = widget.parcel.status == ParcelStatus.delivered;
    final isCancelled = widget.parcel.status == ParcelStatus.cancelled;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDelivered ? Icons.check_circle : Icons.pending,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Statut actuel',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    statusColor.withValues(alpha: 0.1),
                    statusColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDelivered
                          ? Icons.check_circle
                          : isCancelled
                              ? Icons.cancel
                              : Icons.pending,
                      color: statusColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.parcel.status.label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        if (widget.parcel.driverName != null)
                          Text(
                            'Chauffeur: ${widget.parcel.driverName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        if (widget.parcel.deliveryDate != null)
                          Text(
                            'Livré le: ${_formatDate(widget.parcel.deliveryDate!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS CARD ====================
  Widget _buildActionsCard() {
    final isPending = widget.parcel.status == ParcelStatus.pending;
    final isConfirmed = widget.parcel.status == ParcelStatus.confirmed;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.settings, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isPending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : () => _updateStatus('confirmed'),
                  icon: Icon(Icons.check_circle, size: 18),
                  label: const Text('Confirmer le colis'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (isConfirmed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : () => _updateStatus('picked_up'),
                  icon: Icon(Icons.local_shipping, size: 18),
                  label: const Text('Marquer comme ramassé'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUpdating ? null : () => _updateStatus('cancelled'),
                icon: Icon(Icons.cancel, size: 18),
                label: const Text('Annuler le colis'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DELIVERY INFO CARD ====================
  Widget _buildDeliveryInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.verified, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Livraison terminée',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.parcel.deliveryDate != null)
              _buildInfoRow(
                label: 'Date de livraison',
                value: _formatDate(widget.parcel.deliveryDate!),
              ),
            if (widget.parcel.driverName != null)
              _buildInfoRow(label: 'Chauffeur', value: widget.parcel.driverName!),
            if (widget.parcel.signatureUrl != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Signature disponible',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== INFO ROW ====================
  Widget _buildInfoRow({
    required String label,
    required String value,
    bool isBold = false,
    bool isPrice = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isPrice ? primaryBlue : textPrimary,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FORMAT DATE ====================
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}