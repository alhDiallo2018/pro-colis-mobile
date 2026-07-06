// mobile/lib/screens/dashboard/garage_admin_dashboard.dart
// ignore_for_file: prefer_const_constructors, avoid_print, unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:procolis/screens/parcel/parcel_detail_screen.dart';
import 'package:procolis/screens/profile/profile_screen.dart';

import '../../models/parcel.dart';
import '../../models/user.dart';
import '../../providers/nav_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/parcel_card.dart';
import '../../widgets/procolis_design_system.dart';
import '../garage_admin/garage_assignations_screen.dart';
import '../garage_admin/garage_colis_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
    // Synchronise l'onglet avec la barre de navigation persistante (AppBottomNav)
    ref.listen<int>(dashboardTabProvider, (prev, next) {
      if (next != _tabController.index && next >= 0 && next < 4) {
        _tabController.animateTo(next);
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: PcFab(
        icon: Icons.assignment_turned_in_rounded,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GarageAssignationsScreen())),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null) return _buildErrorView();

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Column(
            children: [
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
          ),
        ),
      ],
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
        onPressed: _loadData,
      ),
    );
  }

  Widget _buildHeader() {
    final firstName = _currentAdmin?.fullName.split(' ').first ?? 'Admin';
    return PcGradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(Icons.business_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour, $firstName',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gérez votre zone et vos livraisons',
                        style: GoogleFonts.manrope(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.green300,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_availableDriversCount dispo',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _HeaderIconButton(
                  icon: Icons.person_outline_rounded,
                  tooltip: 'Mon profil',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.store_rounded, size: 15, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  '${_parcels.length} colis · ${_drivers.length} chauffeurs',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TapStat(
                  icon: Icons.pending_actions_rounded,
                  tone: PcTone.amber,
                  value: _pendingCount.toString(),
                  label: 'Colis en attente',
                  onTap: () => _tabController.animateTo(0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TapStat(
                  icon: Icons.local_shipping_rounded,
                  tone: PcTone.green,
                  value: _inProgressCount.toString(),
                  label: 'Colis en transit',
                  onTap: () => _tabController.animateTo(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TapStat(
                  icon: Icons.check_circle_rounded,
                  tone: PcTone.primary,
                  value: _completedCount.toString(),
                  label: 'Colis livrés',
                  onTap: () => _tabController.animateTo(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TapStat(
                  icon: Icons.directions_car_rounded,
                  tone: PcTone.neutral,
                  value: '$_availableDriversCount/${_drivers.length}',
                  label: 'Chauffeurs dispo.',
                  onTap: () => _tabController.animateTo(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.assignment_rounded,
                  label: 'Assignations',
                  tone: PcTone.primary,
                  badge: _pendingCount > 0 ? _pendingCount.toString() : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GarageAssignationsScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.bar_chart_rounded,
                  label: 'Rapports',
                  tone: PcTone.green,
                  onTap: () => context.push('/garage/rapports'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'Tous les colis',
                  tone: PcTone.primary,
                  badge: _parcels.isNotEmpty ? _parcels.length.toString() : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GarageColisScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: AppTheme.cardColor,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppTheme.textPrimary,
        unselectedLabelColor: AppTheme.slate500,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'En attente'),
          Tab(text: 'Chauffeurs'),
          Tab(text: 'En cours'),
          Tab(text: 'Historique'),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return ProcolisTabBar(
      currentIndex: _tabController.index,
      onTap: (index) {
        _tabController.animateTo(index);
        ref.read(dashboardTabProvider.notifier).state = index;
      },
      items: [
        ProcolisTabItem(
          label: 'En attente',
          icon: Icons.pending_actions_rounded,
          badge: _pendingCount > 0 ? _pendingCount : null,
        ),
        const ProcolisTabItem(label: 'Chauffeurs', icon: Icons.people_rounded),
        const ProcolisTabItem(label: 'En cours', icon: Icons.local_shipping_rounded),
        const ProcolisTabItem(label: 'Historique', icon: Icons.history_rounded),
      ],
    );
  }
}

// ==================== HEADER ICON BUTTON (hero) ====================
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.18),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ==================== STAT BOX (tapable) ====================
class _TapStat extends StatelessWidget {
  final IconData icon;
  final PcTone tone;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _TapStat({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: PcStatBox(icon: icon, value: value, label: label, tone: tone),
    );
  }
}

// ==================== QUICK ACTION CARD ====================
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final PcTone tone;
  final String? badge;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.tone,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = tone == PcTone.primary
        ? (bg: AppTheme.teal50, fg: AppTheme.teal500)
        : (bg: AppTheme.green50, fg: AppTheme.green700);
    return PcCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: chip.bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: chip.fg, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null)
            PcBadge(badge!, tone: tone, variant: PcBadgeVariant.solid)
          else
            Icon(Icons.chevron_right_rounded, color: chip.fg, size: 22),
        ],
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
        _showSnackBar('Colis confirmé', AppTheme.green600);
        await widget.onRefresh();
      }
    } catch (e) {
      if (mounted) _showSnackBar('Erreur: $e', AppTheme.red400);
    } finally {
      if (mounted) setState(() => _processingParcelId = null);
    }
  }

  Future<void> _assignDriver(Parcel parcel, String driverId) async {
    setState(() => _processingParcelId = parcel.id);
    try {
      final result = await _apiService.assignDriverToParcel(parcel.id, driverId);
      if (mounted && result['success'] == true) {
        _showSnackBar('Chauffeur assigné', AppTheme.green600);
        await widget.onRefresh();
      } else if (mounted) {
        _showSnackBar(result['message'] ?? 'Erreur', AppTheme.red400);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Erreur: $e', AppTheme.red400);
    } finally {
      if (mounted) setState(() => _processingParcelId = null);
    }
  }

  Future<void> _cancelParcel(Parcel parcel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le colis'),
        content: Text('Annuler ${parcel.trackingNumber} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red400,
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
          _showSnackBar('Colis annulé', AppTheme.green600);
          await widget.onRefresh();
        }
      } catch (e) {
        if (mounted) _showSnackBar('Erreur: $e', AppTheme.red400);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingParcels.isEmpty) {
      return const PcEmptyState(
        icon: Icons.inbox_rounded,
        title: 'Aucun colis en attente',
        message: 'Les nouveaux colis apparaîtront ici.',
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingParcels.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final parcel = _pendingParcels[index];
          final isProcessing = _processingParcelId == parcel.id;
          final isConfirmed = parcel.status == ParcelStatus.confirmed;
          final hasDriver = parcel.driverId != null && parcel.driverId!.isNotEmpty;
          final driverName = _getDriverName(parcel.driverId);
          final driverExists = driverName != null && driverName != 'Chauffeur inconnu';

          return PcCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ParcelDetailScreen(parcel: parcel))
            ).then((_) => widget.onRefresh()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.teal50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, size: 20, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parcel.trackingNumber,
                            style: AppTheme.mono(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            parcel.receiverName,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    PcBadge(
                      isConfirmed ? 'Confirmé' : 'En attente',
                      tone: isConfirmed ? PcTone.primary : PcTone.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Infos colis
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    PcMeta(Icons.scale_rounded, '${parcel.weight} kg'),
                    if (parcel.price != null)
                      PcMeta(Icons.payments_rounded, '${parcel.price!.toInt()} FCFA'),
                    PcMeta(Icons.category_rounded, parcel.type.label),
                  ],
                ),

                // Chauffeur assigné
                if (hasDriver && driverExists) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.green50,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.delivery_dining_rounded, size: 16, color: AppTheme.green700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Chauffeur : $driverName',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.green700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.green500,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.slate200),
                const SizedBox(height: 12),

                // Boutons d'action
                Row(
                  children: [
                    Expanded(
                      child: PcButton(
                        'Annuler',
                        variant: PcButtonVariant.danger,
                        size: PcButtonSize.sm,
                        icon: Icons.close_rounded,
                        block: true,
                        onPressed: isProcessing ? null : () => _cancelParcel(parcel),
                      ),
                    ),
                    const SizedBox(width: 8),

                    if (!isConfirmed)
                      Expanded(
                        child: PcButton(
                          'Confirmer',
                          size: PcButtonSize.sm,
                          icon: Icons.check_circle_rounded,
                          block: true,
                          loading: isProcessing,
                          onPressed: isProcessing ? null : () => _confirmParcel(parcel),
                        ),
                      ),

                    if (!hasDriver && isConfirmed)
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          hint: Text('Assigner', style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            prefixIcon: const Icon(Icons.delivery_dining_rounded, size: 18),
                            prefixIconConstraints: const BoxConstraints(minWidth: 34),
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
                                      decoration: const BoxDecoration(
                                        color: AppTheme.green500,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        d.fullName,
                                        style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w600),
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
          );
        },
      ),
    );
  }
}

// ==================== ONGLET CHAUFFEURS ====================
class _DriversTab extends StatelessWidget {
  final List<User> drivers;
  final Future<void> Function() onRefresh;
  const _DriversTab({required this.drivers, required this.onRefresh});

  void _showDriverDetails(BuildContext context, User driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(driver.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.phone_rounded, color: AppTheme.primary),
              title: const Text('Téléphone'),
              subtitle: Text(driver.phone),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.email_rounded, color: AppTheme.primary),
              title: const Text('Email'),
              subtitle: Text(driver.email),
              dense: true,
            ),
            ListTile(
              leading: const Icon(Icons.badge_rounded, color: AppTheme.primary),
              title: const Text('Statut'),
              subtitle: Text(driver.driverStatus?.label ?? 'Disponible'),
              dense: true,
            ),
            if (driver.vehiclePlate != null)
              ListTile(
                leading: const Icon(Icons.directions_car_rounded, color: AppTheme.primary),
                title: const Text('Plaque'),
                subtitle: Text(driver.vehiclePlate!),
                dense: true,
              ),
            if (driver.vehicleModel != null)
              ListTile(
                leading: const Icon(Icons.car_repair_rounded, color: AppTheme.primary),
                title: const Text('Modèle'),
                subtitle: Text(driver.vehicleModel!),
                dense: true,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  PcAvatarStatus _avatarStatus(DriverStatus? status) {
    switch (status) {
      case DriverStatus.available:
        return PcAvatarStatus.online;
      case DriverStatus.busy:
        return PcAvatarStatus.busy;
      case DriverStatus.offline:
        return PcAvatarStatus.offline;
      default:
        return PcAvatarStatus.offline;
    }
  }

  PcTone _statusTone(DriverStatus? status) {
    switch (status) {
      case DriverStatus.available:
        return PcTone.green;
      case DriverStatus.busy:
        return PcTone.amber;
      default:
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
        return 'Hors ligne';
      default:
        return 'Inconnu';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) {
      return const PcEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Aucun chauffeur',
        message: 'Ajoutez des chauffeurs depuis le profil.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: drivers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final driver = drivers[index];
          final tone = _statusTone(driver.driverStatus);
          final statusLabel = _statusLabel(driver.driverStatus);

          return PcCard(
            onTap: () => _showDriverDetails(context, driver),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                PcAvatar(
                  driver.fullName,
                  size: 46,
                  status: _avatarStatus(driver.driverStatus),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.fullName,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        driver.phone,
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.slate500,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          ...List.generate(5, (i) {
                            final stars = driver.rating ?? 0;
                            return Icon(
                              i < stars.floor() ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 15,
                              color: AppTheme.amber400,
                            );
                          }),
                          const SizedBox(width: 5),
                          Text(
                            driver.formattedRating,
                            style: AppTheme.mono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.slate600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.local_shipping_rounded, size: 13, color: AppTheme.slate400),
                          const SizedBox(width: 3),
                          Text(
                            '${driver.completedDeliveries ?? 0}',
                            style: AppTheme.mono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.slate600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                PcBadge(statusLabel, tone: tone),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.slate400),
              ],
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

  List<Parcel> get _inProgressParcels => parcels.where((p) =>
    p.status == ParcelStatus.pickedUp ||
    p.status == ParcelStatus.inTransit ||
    p.status == ParcelStatus.arrived ||
    p.status == ParcelStatus.outForDelivery
  ).toList();

  @override
  Widget build(BuildContext context) {
    if (_inProgressParcels.isEmpty) {
      return const PcEmptyState(
        icon: Icons.local_shipping_rounded,
        title: 'Aucun colis en cours',
        message: 'Les colis en livraison apparaîtront ici.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _inProgressParcels.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final parcel = _inProgressParcels[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ParcelCard(
                parcel: parcel,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ParcelDetailScreen(parcel: parcel))
                ).then((_) => onRefresh()),
              ),
              if (parcel.driverName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: PcMeta(Icons.delivery_dining_rounded, parcel.driverName!),
                ),
            ],
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

  List<Parcel> get _historyParcels => parcels.where((p) =>
    p.status == ParcelStatus.delivered || p.status == ParcelStatus.cancelled
  ).toList();

  Future<void> _deleteParcel(BuildContext context, Parcel parcel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              backgroundColor: AppTheme.red400,
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
              content: const Text('Colis supprimé'),
              backgroundColor: AppTheme.green600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            )
          );
          await onRefresh();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppTheme.red400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            )
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_historyParcels.isEmpty) {
      return const PcEmptyState(
        icon: Icons.history_rounded,
        title: 'Aucun historique',
        message: 'Les colis livrés ou annulés apparaîtront ici.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _historyParcels.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final parcel = _historyParcels[index];
          final isDelivered = parcel.status == ParcelStatus.delivered;
          final status = AppTheme.statusColors(parcel.status);
          return PcCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDelivered ? AppTheme.green50 : AppTheme.red50,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    isDelivered ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isDelivered ? AppTheme.green600 : AppTheme.red400,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parcel.trackingNumber,
                        style: AppTheme.mono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slate700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${parcel.receiverName} · ${_formatDate(parcel.createdAt)}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.slate500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    parcel.status.label.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: status.foreground,
                    ),
                  ),
                ),
                PcIconButton(
                  Icons.delete_outline_rounded,
                  variant: PcIconButtonVariant.danger,
                  size: PcButtonSize.sm,
                  onPressed: () => _deleteParcel(context, parcel),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
