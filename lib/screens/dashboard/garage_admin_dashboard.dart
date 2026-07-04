// mobile/lib/screens/dashboard/garage_admin_dashboard.dart
// ignore_for_file: prefer_const_constructors, avoid_print, unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/screens/parcel/parcel_detail_screen.dart';
import 'package:procolis/screens/profile/profile_screen.dart';
import 'package:procolis/widgets/app_logo.dart';

import '../../models/parcel.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../garage_admin/garage_admin_parcel_detail.dart';
import '../garage_admin/garage_assignations_screen.dart';

class GarageAdminDashboard extends ConsumerStatefulWidget {
  const GarageAdminDashboard({super.key});

  @override
  ConsumerState<GarageAdminDashboard> createState() => _GarageAdminDashboardState();
}

class _GarageAdminDashboardState extends ConsumerState<GarageAdminDashboard> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  List<Parcel> _parcels = [];
  List<User> _drivers = [];
  bool _isLoading = true;
  String? _error;
  User? _currentAdmin;
  
  int _pendingCount = 0;
  int _inProgressCount = 0;
  int _completedCount = 0;
  int _availableDriversCount = 0;

  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF0F4F8);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
    _loadCurrentAdmin();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAdmin() async {
    try {
      final admin = await _apiService.getCurrentUser();
      if (mounted) {
        setState(() => _currentAdmin = admin);
      }
    } catch (e) {
      debugPrint('Erreur chargement admin: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final parcels = await _apiService.getGarageParcels();
      final drivers = await _apiService.getGarageDrivers();
      
      if (mounted) {
        _updateStats(parcels, drivers);
        setState(() {
          _parcels = parcels;
          _drivers = drivers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur détaillée: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _updateStats(List<Parcel> parcels, List<User> drivers) {
    _pendingCount = parcels.where((p) => 
      p.status == ParcelStatus.pending || p.status == ParcelStatus.confirmed
    ).length;
    _inProgressCount = parcels.where((p) => 
      p.status == ParcelStatus.pickedUp ||
      p.status == ParcelStatus.inTransit ||
      p.status == ParcelStatus.arrived ||
      p.status == ParcelStatus.outForDelivery
    ).length;
    _completedCount = parcels.where((p) => p.status == ParcelStatus.delivered).length;
    _availableDriversCount = drivers.where((d) => d.driverStatus == DriverStatus.available).length;
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
            icon: Icon(Icons.person, color: primaryBlue),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
            tooltip: 'Mon profil',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: primaryBlue),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'garage-assignations',
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GarageAssignationsScreen())),
        backgroundColor: primaryBlue,
        child: const Icon(Icons.assignment_turned_in, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
      ),
    );
    if (_error != null) return _buildErrorView();

    return Column(
      children: [
        _buildHeader(),
        _buildStatsGrid(),
        _buildTabs(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _PendingParcelsTab(parcels: _parcels, drivers: _drivers, onRefresh: _loadData),
              _DriversTab(drivers: _drivers, onRefresh: _loadData),
              _InProgressTab(parcels: _parcels, onRefresh: _loadData),
              _HistoryTab(parcels: _parcels, onRefresh: _loadData),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, secondaryBlue],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.business, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour, ${_currentAdmin?.fullName.split(' ').first ?? "Admin"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gérez votre garage et vos livraisons',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_availableDriversCount dispo',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.store, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    '${_parcels.length} colis | ${_drivers.length} chauffeurs',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatCard(
            title: 'En attente',
            value: _pendingCount,
            icon: Icons.pending_actions,
            color: Colors.orange,
            onTap: () => _tabController.animateTo(0),
          ),
          const SizedBox(width: 12),
          _StatCard(
            title: 'En cours',
            value: _inProgressCount,
            icon: Icons.local_shipping,
            color: Colors.blue,
            onTap: () => _tabController.animateTo(2),
          ),
          const SizedBox(width: 12),
          _StatCard(
            title: 'Livrés',
            value: _completedCount,
            icon: Icons.check_circle,
            color: Colors.green,
            onTap: () => _tabController.animateTo(3),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: primaryBlue,
        indicatorWeight: 3,
        labelColor: textPrimary,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
        tabs: const [
          Tab(text: '📦 En attente'),
          Tab(text: '👨‍✈️ Chauffeurs'),
          Tab(text: '🚚 En cours'),
          Tab(text: '📜 Historique'),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _tabController.index,
          onTap: (index) => _tabController.animateTo(index),
          selectedItemColor: primaryBlue,
          unselectedItemColor: Colors.grey[500],
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 0,
          backgroundColor: Colors.white,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.pending),
              label: 'En attente',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Chauffeurs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping),
              label: 'En cours',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Historique',
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== STAT CARD ====================
class _StatCard extends StatelessWidget {
  final String title; final int value; final IconData icon; final Color color; final VoidCallback onTap;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== ONGLET COLIS EN ATTENTE ====================
class _PendingParcelsTab extends StatefulWidget {
  final List<Parcel> parcels;
  final List<User> drivers;
  final Future<void> Function() onRefresh;
  const _PendingParcelsTab({required this.parcels, required this.drivers, required this.onRefresh});

  @override
  State<_PendingParcelsTab> createState() => _PendingParcelsTabState();
}

class _PendingParcelsTabState extends State<_PendingParcelsTab> {
  final ApiService _apiService = ApiService();
  String? _processingParcelId;

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundColor = Color(0xFFF0F4F8);

  List<Parcel> get _pendingParcels => widget.parcels.where((p) => 
    p.status == ParcelStatus.pending || p.status == ParcelStatus.confirmed
  ).toList();

  String? _getDriverName(String? driverId) {
    if (driverId == null) return null;
    final driver = widget.drivers.firstWhere(
      (d) => d.id == driverId,
      orElse: () => User(
        id: driverId,
        fullName: 'Chauffeur inconnu',
        email: '',
        phone: '',
        role: UserRole.driver,
        createdAt: DateTime.now(),
      ),
    );
    return driver.fullName;
  }

  Future<void> _confirmParcel(Parcel parcel) async {
    setState(() => _processingParcelId = parcel.id);
    try {
      await _apiService.advanceParcel(parcel.id, 'confirm');
      if (mounted) {
        _showSnackBar('Colis confirmé', Colors.green);
        await widget.onRefresh();
      }
    } catch (e) {
      if (mounted) _showSnackBar('Erreur: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _processingParcelId = null);
    }
  }

  Future<void> _assignDriver(Parcel parcel, String driverId) async {
    setState(() => _processingParcelId = parcel.id);
    try {
      final result = await _apiService.assignDriverToParcel(parcel.id, driverId);
      if (mounted && result['success'] == true) {
        _showSnackBar('Chauffeur assigné', Colors.green);
        await widget.onRefresh();
      } else if (mounted) {
        _showSnackBar(result['message'] ?? 'Erreur', Colors.red);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Erreur: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _processingParcelId = null);
    }
  }

  Future<void> _cancelParcel(Parcel parcel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler le colis'),
        content: Text('Annuler ${parcel.trackingNumber} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _processingParcelId = parcel.id);
      try {
        await _apiService.cancelParcel(parcel.id, reason: 'Annulé par le garage admin');
        if (mounted) {
          _showSnackBar('Colis annulé', Colors.green);
          await widget.onRefresh();
        }
      } catch (e) {
        if (mounted) _showSnackBar('Erreur: $e', Colors.red);
      } finally {
        if (mounted) setState(() => _processingParcelId = null);
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingParcels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Aucun colis en attente',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les nouveaux colis apparaîtront ici',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingParcels.length,
        itemBuilder: (context, index) {
          final parcel = _pendingParcels[index];
          final isProcessing = _processingParcelId == parcel.id;
          final isConfirmed = parcel.status == ParcelStatus.confirmed;
          final hasDriver = parcel.driverId != null && parcel.driverId!.isNotEmpty;
          final driverName = _getDriverName(parcel.driverId);
          final driverExists = driverName != null && driverName != 'Chauffeur inconnu';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            elevation: 2,
            child: InkWell(
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => ParcelDetailScreen(parcel: parcel))
              ).then((_) => widget.onRefresh()),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.inventory, size: 18, color: primaryBlue),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parcel.trackingNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF1A2332),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                parcel.receiverName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isConfirmed ? Colors.blue : Colors.orange).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isConfirmed ? 'Confirmé' : 'En attente',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isConfirmed ? Colors.blue : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Infos colis
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _InfoChip(icon: Icons.fitness_center, label: '${parcel.weight} kg'),
                        if (parcel.price != null)
                          _InfoChip(icon: Icons.money, label: '${parcel.price!.toInt()} FCFA'),
                        _InfoChip(icon: Icons.category, label: parcel.type.label),
                      ],
                    ),
                    
                    // Chauffeur assigné
                    if (hasDriver && driverExists) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.delivery_dining, size: 16, color: Colors.green[700]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Chauffeur: $driverName',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green[700],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const Divider(height: 20),
                    
                    // Boutons d'action
                    Row(
                      children: [
                        // Annuler
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isProcessing ? null : () => _cancelParcel(parcel),
                            icon: Icon(Icons.cancel, size: 16),
                            label: Text('Annuler', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Confirmer
                        if (!isConfirmed)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isProcessing ? null : () => _confirmParcel(parcel),
                              icon: Icon(Icons.check_circle, size: 16),
                              label: Text('Confirmer', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        
                        // Assigner chauffeur
                        if (!hasDriver && isConfirmed)
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              hint: Text('Assigner', style: TextStyle(fontSize: 12)),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                prefixIcon: Icon(Icons.delivery_dining, size: 16),
                              ),
                              items: widget.drivers
                                  .where((d) => d.driverStatus == DriverStatus.available)
                                  .map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            d.fullName,
                                            style: TextStyle(fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                              onChanged: isProcessing ? null : (value) => _assignDriver(parcel, value!),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon; final String label;
  const _InfoChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.grey.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    ),
  );
}

// ==================== ONGLET CHAUFFEURS ====================
class _DriversTab extends StatelessWidget {
  final List<User> drivers;
  final Future<void> Function() onRefresh;
  const _DriversTab({required this.drivers, required this.onRefresh});

  static const Color primaryBlue = Color(0xFF2563EB);

  void _showDriverDetails(BuildContext context, User driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          driver.fullName,
          style: TextStyle(color: Color(0xFF1A2332)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(Icons.phone, color: primaryBlue),
              title: const Text('Téléphone'),
              subtitle: Text(driver.phone),
              dense: true,
            ),
            ListTile(
              leading: Icon(Icons.email, color: primaryBlue),
              title: const Text('Email'),
              subtitle: Text(driver.email),
              dense: true,
            ),
            ListTile(
              leading: Icon(Icons.badge, color: primaryBlue),
              title: const Text('Statut'),
              subtitle: Text(driver.driverStatus?.label ?? 'Disponible'),
              dense: true,
            ),
            if (driver.vehiclePlate != null)
              ListTile(
                leading: Icon(Icons.directions_car, color: primaryBlue),
                title: const Text('Plaque'),
                subtitle: Text(driver.vehiclePlate!),
                dense: true,
              ),
            if (driver.vehicleModel != null)
              ListTile(
                leading: Icon(Icons.car_repair, color: primaryBlue),
                title: const Text('Modèle'),
                subtitle: Text(driver.vehicleModel!),
                dense: true,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: primaryBlue)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen())
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Aucun chauffeur',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez des chauffeurs depuis le profil',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: drivers.length,
        itemBuilder: (context, index) {
          final driver = drivers[index];
          final isAvailable = driver.driverStatus == DriverStatus.available;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isAvailable ? Colors.green : Colors.grey).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person,
                  color: isAvailable ? Colors.green : Colors.grey,
                ),
              ),
              title: Text(
                driver.fullName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1A2332),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    driver.phone,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    driver.email,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isAvailable ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      driver.driverStatus?.label ?? 'Disponible',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isAvailable ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () => _showDriverDetails(context, driver),
            ),
          );
        },
      ),
    );
  }
}

// ==================== ONGLET COLIS EN COURS ====================
class _InProgressTab extends StatelessWidget {
  final List<Parcel> parcels; final Future<void> Function() onRefresh;
  const _InProgressTab({required this.parcels, required this.onRefresh});

  static const Color primaryBlue = Color(0xFF2563EB);

  List<Parcel> get _inProgressParcels => parcels.where((p) => 
    p.status == ParcelStatus.pickedUp ||
    p.status == ParcelStatus.inTransit ||
    p.status == ParcelStatus.arrived ||
    p.status == ParcelStatus.outForDelivery
  ).toList();

  @override
  Widget build(BuildContext context) {
    if (_inProgressParcels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Aucun colis en cours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A2332),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _inProgressParcels.length,
        itemBuilder: (context, index) {
          final parcel = _inProgressParcels[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            elevation: 2,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: parcel.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_shipping, color: parcel.status.color),
              ),
              title: Text(
                parcel.trackingNumber,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFF1A2332),
                ),
              ),
              subtitle: Text(
                '${parcel.receiverName} - ${parcel.status.label}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (parcel.driverName != null)
                    Text(
                      parcel.driverName!,
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: parcel.status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      parcel.status.label,
                      style: TextStyle(
                        fontSize: 9,
                        color: parcel.status.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ParcelDetailScreen(parcel: parcel))
              ).then((_) => onRefresh()),
            ),
          );
        },
      ),
    );
  }
}

// ==================== ONGLET HISTORIQUE ====================
class _HistoryTab extends StatelessWidget {
  final List<Parcel> parcels; final Future<void> Function() onRefresh;
  const _HistoryTab({required this.parcels, required this.onRefresh});

  static const Color primaryBlue = Color(0xFF2563EB);

  List<Parcel> get _historyParcels => parcels.where((p) => 
    p.status == ParcelStatus.delivered || p.status == ParcelStatus.cancelled
  ).toList();

  Future<void> _deleteParcel(BuildContext context, Parcel parcel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le colis'),
        content: Text('Supprimer ${parcel.trackingNumber} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final apiService = ApiService();
        final currentUser = await apiService.getCurrentUser();
        if (currentUser.role == UserRole.superAdmin) {
          await apiService.deleteParcelSuperAdmin(parcel.id);
        } else if (currentUser.role == UserRole.admin) {
          await apiService.deleteParcelAdmin(parcel.id);
        } else {
          throw Exception('Droits insuffisants');
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Colis supprimé'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )
          );
          await onRefresh();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_historyParcels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Aucun historique',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A2332),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historyParcels.length,
        itemBuilder: (context, index) {
          final parcel = _historyParcels[index];
          final isDelivered = parcel.status == ParcelStatus.delivered;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            elevation: 2,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDelivered ? Colors.green : Colors.red).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDelivered ? Icons.check_circle : Icons.cancel,
                  color: isDelivered ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              title: Text(
                parcel.trackingNumber,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFF1A2332),
                ),
              ),
              subtitle: Text(
                '${parcel.receiverName} - ${_formatDate(parcel.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: parcel.status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      parcel.status.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: parcel.status.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _deleteParcel(context, parcel),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}