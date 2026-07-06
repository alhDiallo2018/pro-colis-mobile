// mobile/lib/screens/garage_admin/garage_admin_drivers_screen.dart
// ignore_for_file: non_constant_identifier_names, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:procolis/widgets/app_logo.dart';

import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

class GarageAdminDriversScreen extends ConsumerStatefulWidget {
  const GarageAdminDriversScreen({super.key});

  @override
  ConsumerState<GarageAdminDriversScreen> createState() => _GarageAdminDriversScreenState();
}

class _GarageAdminDriversScreenState extends ConsumerState<GarageAdminDriversScreen> {
  final ApiService _apiService = ApiService();
  List<User> _drivers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final drivers = await _apiService.getGarageDrivers();
      setState(() {
        _drivers = drivers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 24, isWhite: false),
            const SizedBox(width: 8),
            Text(
              'PRO COLIS',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0.5,
        shadowColor: AppTheme.slate200,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PcIconButton(
              Icons.refresh_rounded,
              variant: PcIconButtonVariant.soft,
              size: PcButtonSize.sm,
              tooltip: 'Actualiser',
              onPressed: _loadDrivers,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _error != null
              ? _buildErrorView()
              : _drivers.isEmpty
                  ? _buildEmptyView()
                  : _buildDriversList(),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  Widget _buildErrorView() {
    return PcEmptyState(
      icon: Icons.error_outline_rounded,
      tone: PcTone.red,
      title: 'Une erreur est survenue',
      message: _error,
      action: PcButton(
        'Réessayer',
        icon: Icons.refresh_rounded,
        onPressed: _loadDrivers,
      ),
    );
  }

  Widget _buildEmptyView() {
    return PcEmptyState(
      icon: Icons.people_outline_rounded,
      tone: PcTone.primary,
      title: 'Aucun chauffeur',
      message: "Aucun chauffeur n'est rattaché à votre garage.",
      action: PcButton(
        'Actualiser',
        variant: PcButtonVariant.secondary,
        icon: Icons.refresh_rounded,
        onPressed: _loadDrivers,
      ),
    );
  }

  Widget _buildDriversList() {
    return RefreshIndicator(
      onRefresh: _loadDrivers,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _drivers.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return PcSectionHeader('Chauffeurs · ${_drivers.length}');
          }
          final driver = _drivers[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DriverCard(driver: driver),
          );
        },
      ),
    );
  }
}

// ==================== DRIVER CARD ====================
class _DriverCard extends StatelessWidget {
  final User driver;

  const _DriverCard({required this.driver});

  PcAvatarStatus _avatarStatus(DriverStatus? status) {
    switch (status) {
      case DriverStatus.available:
        return PcAvatarStatus.online;
      case DriverStatus.busy:
        return PcAvatarStatus.busy;
      case DriverStatus.offline:
      case null:
        return PcAvatarStatus.offline;
    }
  }

  PcTone _statusTone(DriverStatus? status) {
    switch (status) {
      case DriverStatus.available:
        return PcTone.green;
      case DriverStatus.busy:
        return PcTone.amber;
      case DriverStatus.offline:
      case null:
        return PcTone.neutral;
    }
  }

  String _statusLabel(DriverStatus? status) {
    switch (status) {
      case DriverStatus.available:
        return 'Disponible';
      case DriverStatus.busy:
        return 'Occupé';
      case DriverStatus.offline:
      case null:
        return 'Hors ligne';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone(driver.driverStatus);
    final rating = driver.rating != null ? driver.formattedRating : '—';
    final deliveries = driver.completedDeliveries ?? driver.totalDeliveries ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.shadowXs(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: PcAvatar(
            driver.fullName,
            size: 44,
            status: _avatarStatus(driver.driverStatus),
          ),
          title: Text(
            driver.fullName,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              driver.phone,
              style: AppTheme.mono(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate500,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rating,
                    style: AppTheme.mono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.star_rounded, size: 14, color: AppTheme.amber400),
                ],
              ),
              const SizedBox(height: 3),
              PcBadge(_statusLabel(driver.driverStatus), tone: tone),
            ],
          ),
          children: [
            // Ligne livraisons rappelée dans le détail
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.teal50,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Informations du chauffeur',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.teal600,
                      ),
                    ),
                  ),
                  Text(
                    '$deliveries livraisons',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
            _InfoRow(icon: Icons.email_outlined, label: 'Email', value: driver.email),
            _InfoRow(icon: Icons.phone_outlined, label: 'Téléphone', value: driver.phone, mono: true),
            if (driver.vehiclePlate != null && driver.vehiclePlate!.isNotEmpty)
              _InfoRow(
                icon: Icons.confirmation_number_outlined,
                label: 'Plaque',
                value: driver.vehiclePlate!,
                mono: true,
              ),
            if (driver.vehicleModel != null && driver.vehicleModel!.isNotEmpty)
              _InfoRow(icon: Icons.directions_car_outlined, label: 'Modèle', value: driver.vehicleModel!),
            if (driver.vehicleColor != null && driver.vehicleColor!.isNotEmpty)
              _InfoRow(icon: Icons.color_lens_outlined, label: 'Couleur', value: driver.vehicleColor!),
            if (driver.vehicleYear != null)
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Année',
                value: driver.vehicleYear!.toString(),
                mono: true,
              ),
            _InfoRow(
              icon: Icons.timeline_outlined,
              label: 'Statut',
              value: _statusLabel(driver.driverStatus),
            ),
            _InfoRow(
              icon: Icons.calendar_month_outlined,
              label: 'Inscription',
              value: _formatDate(driver.createdAt),
              mono: true,
            ),
            // Statistiques
            if (driver.totalDeliveries != null || driver.rating != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PcStatBox(
                      icon: Icons.local_shipping_outlined,
                      value: driver.totalDeliveries?.toString() ?? '0',
                      label: 'Livraisons',
                      tone: PcTone.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PcStatBox(
                      icon: Icons.star_rounded,
                      value: driver.formattedRating,
                      label: 'Note',
                      tone: PcTone.amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PcStatBox(
                      icon: Icons.trending_up_rounded,
                      value: driver.formattedSuccessRate,
                      label: 'Taux succès',
                      tone: PcTone.green,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _InfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.slate400),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppTheme.slate500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? AppTheme.mono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate700,
                    )
                  : GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.slate700,
                      fontWeight: FontWeight.w500,
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
