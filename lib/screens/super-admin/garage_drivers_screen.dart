import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/garage.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

class GarageDriversScreen extends ConsumerStatefulWidget {
  final Garage garage;

  const GarageDriversScreen({super.key, required this.garage});

  @override
  ConsumerState<GarageDriversScreen> createState() => _GarageDriversScreenState();
}

class _GarageDriversScreenState extends ConsumerState<GarageDriversScreen> {
  final ApiService _apiService = ApiService();
  List<User> _drivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    try {
      final allUsers = await _apiService.getAllUsersSuperAdmin();
      setState(() {
        _drivers = allUsers.where((u) =>
          u.role == UserRole.driver && u.garageId == widget.garage.id
        ).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  // ==================== MAPPINGS DE STATUT (aligné web) ====================

  ({PcAvatarStatus avatar, PcTone tone, String label}) _driverStatusMeta(User d) {
    switch (d.driverStatus) {
      case DriverStatus.available:
        return (avatar: PcAvatarStatus.online, tone: PcTone.green, label: 'Disponible');
      case DriverStatus.busy:
        return (avatar: PcAvatarStatus.busy, tone: PcTone.amber, label: 'Occupé');
      case DriverStatus.offline:
      case null:
        return (avatar: PcAvatarStatus.offline, tone: PcTone.neutral, label: 'Hors ligne');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chauffeurs',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              widget.garage.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: AppTheme.slate500,
              ),
            ),
          ],
        ),
        leading: PcIconButton(
          Icons.arrow_back_ios_new_rounded,
          size: PcButtonSize.sm,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PcIconButton(
            Icons.refresh_rounded,
            variant: PcIconButtonVariant.soft,
            onPressed: _loadDrivers,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drivers.isEmpty
              ? PcEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'Aucun chauffeur',
                  message:
                      'Aucun chauffeur n\'est actuellement rattaché à cette zone.',
                  action: PcButton(
                    'Actualiser',
                    icon: Icons.refresh_rounded,
                    variant: PcButtonVariant.secondary,
                    size: PcButtonSize.sm,
                    onPressed: _loadDrivers,
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _loadDrivers,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      PcSectionHeader('Chauffeurs · ${_drivers.length}'),
                      PcCard(
                        padding: EdgeInsets.zero,
                        shadow: AppTheme.shadowXs(),
                        child: Column(
                          children: [
                            for (var i = 0; i < _drivers.length; i++) ...[
                              if (i > 0) const PcDivider(),
                              _buildDriverRow(_drivers[i]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDriverRow(User driver) {
    final meta = _driverStatusMeta(driver);
    final subtitleParts = <String>[
      if (driver.city != null && driver.city!.isNotEmpty)
        driver.city!
      else if (driver.garageName != null && driver.garageName!.isNotEmpty)
        driver.garageName!,
    ];
    final subtitle = subtitleParts.isEmpty
        ? driver.formattedPhone
        : '${subtitleParts.first} · ${driver.formattedPhone}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDriverDetails(driver),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              PcAvatar(driver.fullName, status: meta.avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      driver.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${driver.rating != null ? driver.rating!.toStringAsFixed(1) : '—'} ★',
                    style: AppTheme.mono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${driver.completedDeliveries ?? 0} livraisons',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              PcBadge(meta.label, tone: meta.tone),
            ],
          ),
        ),
      ),
    );
  }

  void _showDriverDetails(User driver) {
    final meta = _driverStatusMeta(driver);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      backgroundColor: AppTheme.cardColor,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    PcAvatar(driver.fullName, size: 60, status: meta.avatar),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.fullName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          PcBadge(meta.label, tone: meta.tone),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildDetailTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: driver.email,
                    ),
                    _buildDetailTile(
                      icon: Icons.phone_outlined,
                      label: 'Téléphone',
                      value: driver.formattedPhone,
                      mono: true,
                    ),
                    if (driver.vehiclePlate != null && driver.vehiclePlate!.isNotEmpty)
                      _buildDetailTile(
                        icon: Icons.local_taxi_outlined,
                        label: 'Plaque d\'immatriculation',
                        value: driver.vehiclePlate!,
                        mono: true,
                      ),
                    if (driver.vehicleModel != null && driver.vehicleModel!.isNotEmpty)
                      _buildDetailTile(
                        icon: Icons.directions_car_outlined,
                        label: 'Modèle du véhicule',
                        value: driver.vehicleModel!,
                      ),
                    if (driver.vehicleColor != null && driver.vehicleColor!.isNotEmpty)
                      _buildDetailTile(
                        icon: Icons.color_lens_outlined,
                        label: 'Couleur du véhicule',
                        value: driver.vehicleColor!,
                      ),
                    _buildDetailTile(
                      icon: Icons.star_outline_rounded,
                      label: 'Évaluation',
                      value:
                          '${driver.rating != null ? driver.rating!.toStringAsFixed(1) : '—'} ★',
                      tone: PcTone.amber,
                      mono: true,
                    ),
                    _buildDetailTile(
                      icon: Icons.local_shipping_outlined,
                      label: 'Livraisons effectuées',
                      value: '${driver.completedDeliveries ?? 0}',
                      mono: true,
                    ),
                    _buildDetailTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Membre depuis',
                      value: _formatDate(driver.createdAt),
                    ),
                    const SizedBox(height: 20),
                    PcButton(
                      'Fermer',
                      block: true,
                      variant: PcButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
    PcTone tone = PcTone.primary,
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PcListRow(
        icon: icon,
        iconTone: tone,
        title: label,
        subtitle: mono ? null : value,
        trailing: mono
            ? Text(
                value,
                style: AppTheme.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              )
            : null,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Non disponible';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
