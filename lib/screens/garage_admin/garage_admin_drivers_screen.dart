// mobile/lib/screens/garage_admin/garage_admin_drivers_screen.dart
// ignore_for_file: non_constant_identifier_names, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/widgets/app_logo.dart';

import '../../models/user.dart';
import '../../services/api_service.dart';

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

  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF0F4F8);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);

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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 24, isWhite: false),
            const SizedBox(width: 8),
            const Text(
              'PRO COLIS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textPrimary,
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
            onPressed: _loadDrivers,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            )
          : _error != null
              ? _buildErrorView()
              : _drivers.isEmpty
                  ? _buildEmptyView()
                  : _buildDriversList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Erreur: $_error',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDrivers,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.withOpacity( 0.3)),
          const SizedBox(height: 16),
          Text(
            'Aucun chauffeur',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ce garage ne dispose pas encore de chauffeurs',
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contactez le super administrateur',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.withOpacity( 0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDrivers,
            icon: Icon(Icons.refresh, size: 18),
            label: const Text('Actualiser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversList() {
    return RefreshIndicator(
      onRefresh: _loadDrivers,
      color: primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drivers.length,
        itemBuilder: (context, index) {
          final driver = _drivers[index];
          return _DriverCard(driver: driver);
        },
      ),
    );
  }
}

// ==================== DRIVER CARD ====================
class _DriverCard extends StatelessWidget {
  final User driver;

  const _DriverCard({required this.driver});

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);

  Color _getDriverStatusColor(DriverStatus? status) {
    if (status == null) return Colors.green;
    switch (status) {
      case DriverStatus.available:
        return Colors.green;
      case DriverStatus.busy:
        return Colors.orange;
      case DriverStatus.offline:
        return Colors.red;
    }
  }

  String _getDriverStatusLabel(DriverStatus? status) {
    if (status == null) return 'Disponible';
    switch (status) {
      case DriverStatus.available:
        return '🟢 Disponible';
      case DriverStatus.busy:
        return '🟠 En livraison';
      case DriverStatus.offline:
        return '🔴 Hors ligne';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getDriverStatusColor(driver.driverStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity( 0.15)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity( 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.person,
            color: statusColor,
            size: 24,
          ),
        ),
        title: Text(
          driver.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          driver.phone,
          style: TextStyle(
            fontSize: 13,
            color: textSecondary,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity( 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _getDriverStatusLabel(driver.driverStatus),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // En-tête des infos
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity( 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.badge, size: 16, color: primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Informations du chauffeur',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Infos
                _InfoRow(
                  icon: Icons.email,
                  label: 'Email',
                  value: driver.email,
                ),
                _InfoRow(
                  icon: Icons.phone,
                  label: 'Téléphone',
                  value: driver.phone,
                ),
                if (driver.vehiclePlate != null && driver.vehiclePlate!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.confirmation_number,
                    label: 'Plaque',
                    value: driver.vehiclePlate!,
                  ),
                if (driver.vehicleModel != null && driver.vehicleModel!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.car_repair,
                    label: 'Modèle',
                    value: driver.vehicleModel!,
                  ),
                if (driver.vehicleColor != null && driver.vehicleColor!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.color_lens,
                    label: 'Couleur',
                    value: driver.vehicleColor!,
                  ),
                if (driver.vehicleYear != null)
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Année',
                    value: driver.vehicleYear!.toString(),
                  ),
                _InfoRow(
                  icon: Icons.timeline,
                  label: 'Statut',
                  value: _getDriverStatusLabel(driver.driverStatus),
                ),
                _InfoRow(
                  icon: Icons.calendar_month,
                  label: 'Inscription',
                  value: _formatDate(driver.createdAt),
                ),
                // Statistiques
                if (driver.totalDeliveries != null || driver.rating != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity( 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity( 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          icon: Icons.local_shipping,
                          label: 'Livraisons',
                          value: driver.totalDeliveries?.toString() ?? '0',
                        ),
                        _StatItem(
                          icon: Icons.star,
                          label: 'Note',
                          value: driver.formattedRating,
                        ),
                        _StatItem(
                          icon: Icons.trending_up,
                          label: 'Taux succès',
                          value: driver.formattedSuccessRate,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _InfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 10),
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _StatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.amber[700]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.amber[700],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}