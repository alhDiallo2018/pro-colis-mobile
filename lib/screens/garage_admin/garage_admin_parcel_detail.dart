// mobile/lib/screens/garage_admin/garage_admin_parcel_detail.dart
import 'package:flutter/material.dart';

import '../../models/parcel.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

class GarageAdminParcelDetailScreen extends StatefulWidget {
  final Parcel parcel;

  const GarageAdminParcelDetailScreen({super.key, required this.parcel});

  @override
  State<GarageAdminParcelDetailScreen> createState() =>
      _GarageAdminParcelDetailScreenState();
}

class _GarageAdminParcelDetailScreenState
    extends State<GarageAdminParcelDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isUpdating = false;

  String _statusToStep(String status) {
    switch (status) {
      case 'picked_up':
        return 'pickup';
      case 'in_transit':
        return 'transit';
      case 'arrived':
        return 'arrived';
      case 'out_for_delivery':
        return 'out-for-delivery';
      case 'confirmed':
        return 'confirm';
      case 'delivered':
        return 'deliver';
      case 'cancelled':
        return 'cancelled';
      default:
        return status;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final step = _statusToStep(newStatus);
      if (step == 'cancelled') {
        await _apiService.cancelParcel(widget.parcel.id,
            reason: 'Annulé par l\'admin');
      } else {
        await _apiService.advanceParcel(widget.parcel.id, step);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statut mis à jour avec succès'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  String get _arrival => widget.parcel.arrivalGarageName?.isNotEmpty == true
      ? widget.parcel.arrivalGarageName!
      : 'Arrivée';

  String get _driverName => widget.parcel.driverName?.isNotEmpty == true
      ? widget.parcel.driverName!
      : 'Chauffeur non assigné';

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    final isPending = parcel.status == ParcelStatus.pending;
    final isConfirmed = parcel.status == ParcelStatus.confirmed;
    final canCancel = isPending || isConfirmed;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Détail du colis'),
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _TrackingHero(parcel: parcel, arrival: _arrival),
          const SizedBox(height: 12),
          _TagsRow(parcel: parcel),
          const SizedBox(height: 16),
          _DriverCard(
            name: _driverName,
            garage: parcel.departureGarageName,
            assigned: parcel.driverName?.isNotEmpty == true,
          ),
          const SizedBox(height: 16),
          const PcSectionHeader('Informations du colis'),
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                PcListRow(
                  icon: Icons.category_rounded,
                  iconTone: PcTone.primary,
                  title: 'Type',
                  trailing: _InfoValue(value: parcel.type.label),
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.scale_rounded,
                  iconTone: PcTone.primary,
                  title: 'Poids',
                  trailing:
                      _InfoValue(value: parcel.formattedWeight, mono: true),
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.person_pin_rounded,
                  iconTone: PcTone.primary,
                  title: 'Destinataire',
                  trailing: _InfoValue(
                    value: parcel.receiverName.isEmpty
                        ? 'Non renseigné'
                        : parcel.receiverName,
                  ),
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.call_rounded,
                  iconTone: PcTone.primary,
                  title: 'Téléphone',
                  trailing: _InfoValue(
                    value: parcel.receiverPhone.isEmpty
                        ? 'Non renseigné'
                        : parcel.receiverPhone,
                    mono: true,
                  ),
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.person_outline_rounded,
                  iconTone: PcTone.primary,
                  title: 'Expéditeur',
                  trailing: _InfoValue(
                    value: parcel.senderName.isEmpty
                        ? 'Non renseigné'
                        : parcel.senderName,
                  ),
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.payments_rounded,
                  iconTone: PcTone.primary,
                  title: 'Prix',
                  trailing:
                      _InfoValue(value: parcel.formattedPrice, mono: true),
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.event_rounded,
                  iconTone: PcTone.primary,
                  title: 'Créé le',
                  trailing: _InfoValue(
                    value: _formatDate(parcel.createdAt),
                    mono: true,
                  ),
                ),
              ],
            ),
          ),
          if (parcel.isDelivered) ...[
            const SizedBox(height: 16),
            _DeliveryInfoCard(parcel: parcel, formatDate: _formatDate),
          ],
          const SizedBox(height: 20),
          if (isPending) ...[
            PcButton(
              'Confirmer le colis',
              onPressed: _isUpdating ? null : () => _updateStatus('confirmed'),
              icon: Icons.check_circle_rounded,
              size: PcButtonSize.lg,
              loading: _isUpdating,
              block: true,
            ),
            const SizedBox(height: 12),
          ],
          if (isConfirmed) ...[
            PcButton(
              'Marquer comme ramassé',
              onPressed: _isUpdating ? null : () => _updateStatus('picked_up'),
              icon: Icons.local_shipping_rounded,
              size: PcButtonSize.lg,
              loading: _isUpdating,
              block: true,
            ),
            const SizedBox(height: 12),
          ],
          if (canCancel)
            PcButton(
              'Annuler le colis',
              onPressed: _isUpdating ? null : () => _updateStatus('cancelled'),
              icon: Icons.cancel_rounded,
              variant: PcButtonVariant.danger,
              size: PcButtonSize.lg,
              block: true,
            ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// Tracking hero (bandeau brand)
// ============================================================

class _TrackingHero extends StatelessWidget {
  final Parcel parcel;
  final String arrival;

  const _TrackingHero({required this.parcel, required this.arrival});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.brandShadow(),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  parcel.trackingNumber,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _HeroStatusBadge(status: parcel.status),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _RouteEnd(
                  label: 'Départ',
                  city: parcel.departureGarageName.isEmpty
                      ? 'Départ'
                      : parcel.departureGarageName,
                  alignEnd: false,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: _RouteLine()),
              const SizedBox(width: 10),
              Expanded(
                child: _RouteEnd(
                  label: 'Arrivée',
                  city: arrival,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMeta(label: 'Type', value: parcel.type.label),
              const SizedBox(width: 18),
              _HeroMeta(label: 'Poids', value: parcel.formattedWeight),
              const SizedBox(width: 18),
              Expanded(
                child: _HeroMeta(label: 'Prix', value: parcel.formattedPrice),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteEnd extends StatelessWidget {
  final String label;
  final String city;
  final bool alignEnd;

  const _RouteEnd({
    required this.label,
    required this.city,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 2,
            color: Colors.white.withOpacity(0.42),
          ),
          const Positioned(
            left: 34,
            child: Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.mono(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HeroStatusBadge extends StatelessWidget {
  final ParcelStatus status;

  const _HeroStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: colors.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ============================================================
// Driver / assignment card
// ============================================================

class _DriverCard extends StatelessWidget {
  final String name;
  final String garage;
  final bool assigned;

  const _DriverCard({
    required this.name,
    required this.garage,
    required this.assigned,
  });

  @override
  Widget build(BuildContext context) {
    return PcCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          PcAvatar(
            assigned ? name : 'PC',
            size: 48,
            status: assigned ? PcAvatarStatus.online : PcAvatarStatus.offline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  garage.isEmpty ? 'Zone de départ' : garage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PcBadge(
            assigned ? 'Assigné' : 'Non assigné',
            tone: assigned ? PcTone.green : PcTone.neutral,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Tags row
// ============================================================

class _TagsRow extends StatelessWidget {
  final Parcel parcel;

  const _TagsRow({required this.parcel});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (parcel.isUrgent) const PcTag.express(),
        if (parcel.isInsured)
          const PcTag(
            'Assuré',
            icon: Icons.shield_rounded,
            tone: PcTone.green,
          ),
        PcTag(
          parcel.type.label,
          icon: parcel.type.icon,
          tone: PcTone.primary,
        ),
      ],
    );
  }
}

// ============================================================
// Info value (trailing)
// ============================================================

class _InfoValue extends StatelessWidget {
  final String value;
  final bool mono;

  const _InfoValue({required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: mono
            ? AppTheme.mono(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              )
            : const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
      ),
    );
  }
}

// ============================================================
// Delivery info card
// ============================================================

class _DeliveryInfoCard extends StatelessWidget {
  final Parcel parcel;
  final String Function(DateTime) formatDate;

  const _DeliveryInfoCard({required this.parcel, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return PcCard(
      accent: AppTheme.successColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: AppTheme.successColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Livraison terminée',
                style: TextStyle(
                  color: AppTheme.successColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (parcel.deliveryDate != null)
            _MiniRow(
              label: 'Date de livraison',
              value: formatDate(parcel.deliveryDate!),
              mono: true,
            ),
          if (parcel.driverName != null)
            _MiniRow(label: 'Chauffeur', value: parcel.driverName!),
          if (parcel.signatureUrl != null)
            _MiniRow(label: 'Signature', value: 'Disponible'),
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _MiniRow({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: mono
                  ? AppTheme.mono(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    )
                  : const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
