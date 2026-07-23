// mobile/lib/screens/dashboard/super_admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:procolis/theme/fonts.dart';
import 'package:procolis/models/garage.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/screens/dashboard/notifications/notifications_screen.dart';
import 'package:procolis/screens/super-admin/garages_management_screen.dart';
import 'package:procolis/screens/super-admin/users_management_screen.dart';
import 'package:procolis/screens/super-admin/colis_management_screen.dart';
import 'package:procolis/screens/super-admin/chauffeurs_management_screen.dart';
import 'package:procolis/screens/super-admin/stats_screen.dart';
import 'package:procolis/screens/super-admin/admin_parametres_screen.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/theme/app_theme.dart';

import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/broadcast_banner.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/procolis_design_system.dart';
import '../profile/profile_screen.dart';
import '../super-admin/finance_dashboard_screen.dart';
import '../super-admin/wallets_screen.dart';
import '../super-admin/payments_screen.dart';
import '../super-admin/payment_notifications_screen.dart';
import '../super-admin/withdrawals_screen.dart';
import '../super-admin/commission_config_screen.dart';
import '../super-admin/reputation_dashboard_screen.dart';
import '../super-admin/scores_screen.dart';
import '../super-admin/classement_screen.dart';

// Provider pour les utilisateurs
final userProvider = StateNotifierProvider<UserNotifier, List<User>>((ref) {
  return UserNotifier();
});

class UserNotifier extends StateNotifier<List<User>> {
  UserNotifier() : super([]);
  final ApiService _apiService = ApiService();

  Future<void> loadUsers() async {
    try {
      final users = await _apiService.getAllUsersSuperAdmin();
      state = users;
    } catch (e) {
      debugPrint('Erreur chargement utilisateurs: $e');
    }
  }

  Future<void> loadDrivers() async {
    try {
      final drivers = await _apiService.getAllDriversSuperAdmin();
      state = drivers;
    } catch (e) {
      debugPrint('Erreur chargement chauffeurs: $e');
    }
  }

  Future<void> updateUserStatus(String userId, String status) async {
    try {
      final Map<String, dynamic> result = await _apiService.updateUserStatusSuperAdmin(userId, status);
      if (result['success'] == true && result['user'] != null) {
        final updatedUser = User.fromJson(result['user']);
        final index = state.indexWhere((u) => u.id == userId);
        if (index != -1) {
          final newState = List<User>.from(state);
          newState[index] = updatedUser;
          state = newState;
        }
      }
    } catch (e) {
      debugPrint('Erreur mise à jour statut: $e');
    }
  }
}

// Provider pour les garages
final garageProvider = StateNotifierProvider<GarageNotifier, List<Garage>>((ref) {
  return GarageNotifier();
});

class GarageNotifier extends StateNotifier<List<Garage>> {
  GarageNotifier() : super([]);
  final ApiService _apiService = ApiService();

  Future<void> loadGarages() async {
    try {
      final garages = await _apiService.getAllGaragesSuperAdmin();
      state = garages;
    } catch (e) {
      debugPrint('Erreur chargement garages: $e');
    }
  }
}

class SuperAdminDashboard extends ConsumerStatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  ConsumerState<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends ConsumerState<SuperAdminDashboard> {
  int _selectedIndex = 0;
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNotificationsCount();
  }

  void _loadData() {
    Future.microtask(() {
      ref.read(parcelProvider.notifier).loadAllParcels();
      ref.read(userProvider.notifier).loadUsers();
      ref.read(garageProvider.notifier).loadGarages();
    });
  }

  void _loadNotificationsCount() {
    // Simuler le chargement du nombre de notifications non lues
    // À remplacer par un vrai appel API
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = 1; // Exemple pour super admin
        });
      }
    });
  }

  void _onNotificationsTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(
          onNotificationsRead: () {
            setState(() {
              _unreadNotificationsCount = 0;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final parcelState = ref.watch(parcelProvider);
    final users = ref.watch(userProvider);
    final garages = ref.watch(garageProvider);

    // Synchronise l'onglet avec la barre de navigation persistante (AppBottomNav)
    ref.listen<int>(dashboardTabProvider, (prev, next) {
      if (next != _selectedIndex && next >= 0 && next < 5) {
        setState(() => _selectedIndex = next);
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          const BroadcastBanner(),
          Expanded(
            child: _getScreen(_selectedIndex, user, parcelState, users, garages),
          ),
        ],
      ),
      bottomNavigationBar: ProcolisTabBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          ref.read(dashboardTabProvider.notifier).state = index;
        },
        items: [
          const ProcolisTabItem(
            icon: Icons.dashboard_rounded,
            label: 'Tableau',
          ),
          const ProcolisTabItem(
            icon: Icons.group_rounded,
            label: 'Utilisateurs',
          ),
          const ProcolisTabItem(
            icon: Icons.garage_rounded,
            label: 'Zones',
          ),
          ProcolisTabItem(
            icon: Icons.notifications_rounded,
            label: 'Alertes',
            badge: _unreadNotificationsCount,
          ),
          const ProcolisTabItem(
            icon: Icons.person_rounded,
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _getScreen(int index, User? user, ParcelState parcelState, List<User> users, List<Garage> garages) {
    switch (index) {
      case 0:
        return _SuperAdminHomeScreen(
          user: user,
          parcelState: parcelState,
          users: users,
          garages: garages,
          onRefresh: _loadData,
          onNotificationsTap: _onNotificationsTap,
          unreadNotificationsCount: _unreadNotificationsCount,
        );
      case 1:
        return const UsersManagementScreen(embedded: true);
      case 2:
        return const GaragesManagementScreen(embedded: true);
      case 3:
        return NotificationsScreen(
          onNotificationsRead: () {
            setState(() {
              _unreadNotificationsCount = 0;
            });
          },
        );
      case 4:
        return const ProfileScreen(embedded: true);
      default:
        return _SuperAdminHomeScreen(
          user: user,
          parcelState: parcelState,
          users: users,
          garages: garages,
          onRefresh: _loadData,
          onNotificationsTap: _onNotificationsTap,
          unreadNotificationsCount: _unreadNotificationsCount,
        );
    }
  }
}

class _SuperAdminHomeScreen extends StatelessWidget {
  final User? user;
  final ParcelState parcelState;
  final List<User> users;
  final List<Garage> garages;
  final VoidCallback onRefresh;
  final VoidCallback onNotificationsTap;
  final int unreadNotificationsCount;

  const _SuperAdminHomeScreen({
    required this.user,
    required this.parcelState,
    required this.users,
    required this.garages,
    required this.onRefresh,
    required this.onNotificationsTap,
    this.unreadNotificationsCount = 0,
  });

  int get _totalParcels => parcelState.parcels.length;
  int get _pendingParcels => parcelState.parcels.where((p) => p.status == ParcelStatus.pending).length;
  int get _inTransitParcels => parcelState.parcels.where((p) => p.isInProgress).length;
  int get _deliveredParcels => parcelState.parcels.where((p) => p.isDelivered).length;

  int get _totalUsers => users.length;
  int get _totalDrivers => users.where((u) => u.isDriver).length;
  int get _totalAdmins => users.where((u) => u.isAdmin).length;
  int get _totalGarages => garages.length;

  // Chauffeurs (dérivés de la liste des utilisateurs) pour le panneau latéral.
  List<User> get _drivers => users.where((u) => u.isDriver).toList();
  int get _availableDrivers => users.where((u) => u.isDriverAvailable).length;

  // Revenu encaissé : somme des montants des colis livrés (totalAmount ou prix).
  double get _revenue {
    double sum = 0;
    for (final p in parcelState.parcels) {
      if (p.isDelivered) sum += p.totalAmount ?? p.price ?? 0;
    }
    return sum;
  }

  String _formatAmount(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  // Données de volume (12 mois) — reprises du dashboard web.
  static const List<int> _volume = [38, 44, 41, 52, 49, 61, 58, 67, 72, 70, 84, 100];
  static const List<String> _months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatsSection(),
                const SizedBox(height: 22),
                _buildVolumeSection(),
                const SizedBox(height: 22),
                _buildQuickActions(context),
                const SizedBox(height: 22),
                _buildDriversPanel(),
                const SizedBox(height: 22),
                _buildGaragesPanel(context),
                const SizedBox(height: 22),
                _buildRecentActivitySection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero / bandeau brand
  // ---------------------------------------------------------------------------

  Widget _buildHero() {
    final photoUrl = user?.profilePhoto;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFC9F3EE),
                    backgroundImage: hasPhoto
                        ? NetworkImage(
                            photoUrl!.startsWith('http')
                                ? photoUrl!
                                : ApiService.resolveMediaUrl(photoUrl),
                          )
                        : null,
                    child: hasPhoto
                        ? null
                        : Text(
                            user?.initials ?? 'SA',
                            style: const TextStyle(
                              color: AppTheme.teal700,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Super Admin',
                          style: AppFonts.manrope(
                            color: Colors.white.withAlpha(220),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user?.fullName ?? 'Administration',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onNotificationsTap,
                    color: Colors.white,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_rounded, size: 27),
                        if (unreadNotificationsCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.amber400,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppTheme.teal600, width: 2),
                              ),
                              child: Text(
                                unreadNotificationsCount > 99 ? '99+' : '$unreadNotificationsCount',
                                style: const TextStyle(
                                  color: AppTheme.amberOnFg,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Gérez l\'ensemble de la plateforme',
                style: AppFonts.manrope(
                  color: Colors.white.withAlpha(220),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Statistiques globales
  // ---------------------------------------------------------------------------

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PcSectionHeader('Statistiques globales'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            const _AdminStat(icon: Icons.inventory_2_rounded, tone: PcTone.primary, label: 'Colis', valueKey: 'parcels').resolve(this),
            _revenueStatBox(),
            const _AdminStat(icon: Icons.local_shipping_rounded, tone: PcTone.green, label: 'Chauffeurs', valueKey: 'drivers').resolve(this),
            const _AdminStat(icon: Icons.garage_rounded, tone: PcTone.amber, label: 'Zones', valueKey: 'garages').resolve(this),
            const _AdminStat(icon: Icons.group_rounded, tone: PcTone.neutral, label: 'Utilisateurs', valueKey: 'users').resolve(this),
            const _AdminStat(icon: Icons.admin_panel_settings_rounded, tone: PcTone.neutral, label: 'Admins', valueKey: 'admins').resolve(this),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatusMini(
                label: 'En attente',
                value: _pendingParcels,
                tone: PcTone.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusMini(
                label: 'En cours',
                value: _inTransitParcels,
                tone: PcTone.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusMini(
                label: 'Livrés',
                value: _deliveredParcels,
                tone: PcTone.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  int _statValue(String key) {
    switch (key) {
      case 'parcels':
        return _totalParcels;
      case 'users':
        return _totalUsers;
      case 'drivers':
        return _totalDrivers;
      case 'admins':
        return _totalAdmins;
      case 'garages':
        return _totalGarages;
      default:
        return 0;
    }
  }

  Widget _revenueStatBox() {
    return PcStatBox(
      icon: Icons.account_balance_wallet_rounded,
      tone: PcTone.neutral,
      value: _revenue > 0 ? _formatAmount(_revenue) : '—',
      label: 'FCFA encaissés',
    );
  }

  // ---------------------------------------------------------------------------
  // Volume de colis (mini graphique)
  // ---------------------------------------------------------------------------

  Widget _buildVolumeSection() {
    return PcCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Volume de colis · 12 mois',
                style: AppFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const PcBadge('+12%', tone: PcTone.primary),
            ],
          ),
          const SizedBox(height: 16),
          PcBarChart(bars: _volume.map((v) => v.toDouble()).toList(), labels: _months, height: 120, highlightLast: true),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions rapides
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PcSectionHeader('Actions rapides'),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.garage_rounded,
                label: 'Zones',
                tone: PcTone.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GaragesManagementScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.group_rounded,
                label: 'Utilisateurs',
                tone: PcTone.amber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UsersManagementScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.inventory_2_rounded,
                label: 'Colis',
                tone: PcTone.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ColisManagementScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.local_shipping_rounded,
                label: 'Chauffeurs',
                tone: PcTone.amber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const ChauffeursManagementScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.insights_rounded,
                label: 'Statistiques',
                tone: PcTone.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminStatsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.settings_rounded,
                label: 'Paramètres',
                tone: PcTone.neutral,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminParametresScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Finance',
                tone: PcTone.primary,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const FinanceDashboardScreen(),
                  ));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.emoji_events_rounded,
                label: 'Réputation',
                tone: PcTone.amber,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const ReputationDashboardScreen(),
                  ));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.receipt_long_rounded,
                label: 'Wallets',
                tone: PcTone.green,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const WalletsScreen(),
                  ));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.receipt_long_rounded,
                label: 'Paiements',
                tone: PcTone.neutral,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const PaymentsScreen(),
                  ));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.percent_rounded,
                label: 'Commissions',
                tone: PcTone.amber,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const CommissionConfigScreen(),
                  ));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.format_list_numbered_rounded,
                label: 'Classement',
                tone: PcTone.primary,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const ClassementScreen(),
                  ));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.campaign_rounded,
                label: 'Bandeaux',
                tone: PcTone.primary,
                onTap: () => context.go('/admin/broadcasts'),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.email_rounded,
                label: 'Configuration Brevo',
                tone: PcTone.primary,
                onTap: () => context.go('/admin/notifications/brevo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.savings_rounded,
                label: 'Retraits',
                tone: PcTone.green,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const WithdrawalsScreen(),
                  ));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.notifications_active_rounded,
                label: 'Alertes paiements',
                tone: PcTone.amber,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const PaymentNotificationsScreen(),
                  ));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Configuration PayDunya',
                tone: PcTone.green,
                onTap: () => context.go('/admin/payments/paydunya'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Panneau Chauffeurs (top 5)
  // ---------------------------------------------------------------------------

  Widget _buildDriversPanel() {
    final drivers = _drivers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chauffeurs',
                style: AppFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (_availableDrivers > 0)
                PcBadge('$_availableDrivers dispo', tone: PcTone.green),
            ],
          ),
        ),
        if (drivers.isEmpty)
          const PcCard(
            child: PcEmptyState(
              icon: Icons.local_shipping_rounded,
              title: 'Aucun chauffeur',
              message: 'Les chauffeurs de la plateforme apparaîtront ici.',
              tone: PcTone.neutral,
            ),
          )
        else
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < drivers.take(5).length; i++) ...[
                  if (i > 0) const PcDivider(),
                  _buildDriverRow(drivers[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDriverRow(User driver) {
    final status = switch (driver.driverStatus) {
      DriverStatus.available => PcAvatarStatus.online,
      DriverStatus.busy => PcAvatarStatus.busy,
      DriverStatus.offline => PcAvatarStatus.offline,
      _ => PcAvatarStatus.offline,
    };
    final place = (driver.city != null && driver.city!.isNotEmpty)
        ? driver.city!
        : (driver.garageName ?? '—');
    final rating = driver.rating != null ? driver.rating!.toStringAsFixed(1) : '—';
    return PcListRow(
      leading: PcAvatar(driver.fullName, size: 40, status: status),
      title: driver.fullName,
      subtitle: '$place · $rating ★',
    );
  }

  // ---------------------------------------------------------------------------
  // Panneau Garages (top 5)
  // ---------------------------------------------------------------------------

  Widget _buildGaragesPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PcSectionHeader(
          'Zones',
          action: 'Tout voir',
          onAction: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GaragesManagementScreen()),
            );
          },
        ),
        if (garages.isEmpty)
          const PcCard(
            child: PcEmptyState(
              icon: Icons.garage_rounded,
              title: 'Aucune zone',
              message: 'Les zones enregistrées apparaîtront ici.',
              tone: PcTone.neutral,
            ),
          )
        else
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < garages.take(5).length; i++) ...[
                  if (i > 0) const PcDivider(),
                  _buildGarageRow(garages[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGarageRow(Garage garage) {
    return PcListRow(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.slate100,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: const Icon(Icons.garage_rounded, size: 22, color: AppTheme.slate500),
      ),
      title: garage.name,
      subtitle: garage.city.isNotEmpty ? garage.city : '—',
    );
  }

  // ---------------------------------------------------------------------------
  // Activité récente
  // ---------------------------------------------------------------------------

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PcSectionHeader('Activité récente'),
        if (parcelState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          )
        else if (parcelState.parcels.isEmpty)
          const PcCard(
            child: PcEmptyState(
              icon: Icons.local_shipping_rounded,
              title: 'Aucune activité récente',
              message: 'Les derniers colis enregistrés apparaîtront ici.',
              tone: PcTone.neutral,
            ),
          )
        else
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < parcelState.parcels.take(5).length; i++) ...[
                  if (i > 0) const PcDivider(),
                  _buildActivityRow(parcelState.parcels[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActivityRow(Parcel parcel) {
    final colors = AppTheme.statusColors(parcel.status);
    return PcListRow(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Icon(Icons.local_shipping_rounded, color: colors.foreground, size: 22),
      ),
      title: parcel.trackingNumber,
      subtitle: parcel.receiverName,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          parcel.status.label,
          style: AppFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: colors.foreground,
          ),
        ),
      ),
    );
  }
}

// A helper descriptor so we can build tone-aware PcStatBox from static config
// while still reading live values from the home screen.
class _AdminStat {
  final IconData icon;
  final PcTone tone;
  final String label;
  final String valueKey;

  const _AdminStat({
    required this.icon,
    required this.tone,
    required this.label,
    required this.valueKey,
  });

  Widget resolve(_SuperAdminHomeScreen host) {
    return PcStatBox(
      icon: icon,
      tone: tone,
      value: '${host._statValue(valueKey)}',
      label: label,
    );
  }
}

class _StatusMini extends StatelessWidget {
  final String label;
  final int value;
  final PcTone tone;

  const _StatusMini({
    required this.label,
    required this.value,
    required this.tone,
  });

  Color get _fg {
    switch (tone) {
      case PcTone.primary:
        return AppTheme.teal500;
      case PcTone.green:
        return AppTheme.green700;
      case PcTone.amber:
        return AppTheme.amber600;
      case PcTone.red:
        return AppTheme.red500;
      case PcTone.neutral:
        return AppTheme.slate500;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PcCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: [
          Text(
            '$value',
            style: AppTheme.mono(fontSize: 20, fontWeight: FontWeight.w800, color: _fg),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppFonts.manrope(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final PcTone tone;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  ({Color bg, Color fg}) get _chip {
    switch (tone) {
      case PcTone.primary:
        return (bg: AppTheme.teal50, fg: AppTheme.teal500);
      case PcTone.green:
        return (bg: AppTheme.green50, fg: AppTheme.green700);
      case PcTone.amber:
        return (bg: AppTheme.amber50, fg: AppTheme.amber600);
      case PcTone.red:
        return (bg: AppTheme.red50, fg: AppTheme.red500);
      case PcTone.neutral:
        return (bg: AppTheme.slate100, fg: AppTheme.slate500);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = _chip;
    return PcCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: chip.bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: chip.fg, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: AppFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
