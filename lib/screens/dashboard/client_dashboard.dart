// lib/screens/dashboard/client_dashboard.dart
// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors, deprecated_member_use, unnecessary_this, unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/screens/dashboard/notifications/notifications_screen.dart';
import 'package:procolis/services/api_service.dart';

import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/procolis_design_system.dart';
// IMPORTANT: Importer le nouvel écran d'annonces
import '../parcel/ads/advertisements_screen.dart'; // <-- NOUVEAU CHEMIN
import '../parcel/new_parcel_screen.dart';
import '../parcel/parcel_detail_screen.dart';
import '../parcel/track_parcel_screen.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

class ClientDashboard extends ConsumerStatefulWidget {
  const ClientDashboard({super.key});

  @override
  ConsumerState<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends ConsumerState<ClientDashboard> {
  int _selectedIndex = 0;
  int _unreadNotificationsCount = 0;
  final ApiService _apiService = ApiService();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNotificationsCount();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadNotificationsCount();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadData() {
    Future.microtask(() {
      ref.read(parcelProvider.notifier).loadMyParcels();
    });
  }

  Future<void> _loadNotificationsCount() async {
    try {
      final unreadCount = await _apiService.getUnreadNotificationsCount();
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = unreadCount;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement compteur notifications: $e');
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final parcelState = ref.watch(parcelProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: null,
      body: _getScreen(_selectedIndex, user, parcelState),
      bottomNavigationBar: ProcolisTabBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) {
            _loadData();
          }
        },
        items: [
          const ProcolisTabItem(
            icon: Icons.home_rounded,
            label: 'Accueil',
          ),
          ProcolisTabItem(
            icon: Icons.inventory_2_rounded,
            label: 'Mes colis',
            badge: parcelState.parcels.length,
          ),
          const ProcolisTabItem(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Suivi',
          ),
          const ProcolisTabItem(
            icon: Icons.sell_rounded,
            label: 'Libre service',
          ),
          const ProcolisTabItem(
            icon: Icons.person_rounded,
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 || _selectedIndex == 1
          ? FloatingActionButton(
              heroTag: 'client-new-parcel',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NewParcelScreen()),
                );
              },
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _getScreen(int index, User? user, ParcelState parcelState) {
    switch (index) {
      case 0:
        return HomeScreen(
          user: user,
          parcelState: parcelState,
          onRefresh: _loadData,
          onNotificationsTap: _onNotificationsTap,
          unreadNotificationsCount: _unreadNotificationsCount,
        );
      case 1:
        return _MesColisTab(
          parcelState: parcelState,
          onRefresh: _loadData,
        );
      case 2:
        return const TrackParcelScreen(embedded: true);
      case 3:
        return const AdvertisementsScreen(embedded: true);
      case 4:
        return const ProfileScreen();
      default:
        return HomeScreen(
          user: user,
          parcelState: parcelState,
          onRefresh: _loadData,
          onNotificationsTap: _onNotificationsTap,
          unreadNotificationsCount: _unreadNotificationsCount,
        );
    }
  }

  void _onNotificationsTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(
          onNotificationsRead: () {
            _loadNotificationsCount();
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildLegacyAppBar() {
    return AppBar(
      title: Row(
        children: [
          const AppLogo(size: 28),
          const SizedBox(width: 10),
          const Text(
            'PRO COLIS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.cardColor,
      foregroundColor: AppTheme.textPrimary,
      elevation: 0,
      centerTitle: false,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: _onNotificationsTap,
              color: AppTheme.textPrimary,
            ),
            if (_unreadNotificationsCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${_unreadNotificationsCount > 99 ? '99+' : _unreadNotificationsCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ==================== LE RESTE DU CODE (HomeScreen, _StatCard, etc.) RESTE INCHANGÉ ====================

class _MesColisTab extends StatefulWidget {
  final ParcelState parcelState;
  final VoidCallback onRefresh;

  const _MesColisTab({
    required this.parcelState,
    required this.onRefresh,
  });

  @override
  State<_MesColisTab> createState() => _MesColisTabState();
}

class _MesColisTabState extends State<_MesColisTab> {
  String _tab = 'cours';

  List<Parcel> get _inProgressParcels => widget.parcelState.parcels
      .where(
        (parcel) =>
            parcel.status == ParcelStatus.pending ||
            parcel.status == ParcelStatus.free ||
            parcel.status == ParcelStatus.confirmed ||
            parcel.status == ParcelStatus.pickedUp ||
            parcel.status == ParcelStatus.inTransit ||
            parcel.status == ParcelStatus.arrived ||
            parcel.status == ParcelStatus.outForDelivery,
      )
      .toList();

  List<Parcel> get _deliveredParcels => widget.parcelState.parcels
      .where((parcel) => parcel.status == ParcelStatus.delivered)
      .toList();

  List<Parcel> get _cancelledParcels => widget.parcelState.parcels
      .where((parcel) => parcel.status == ParcelStatus.cancelled)
      .toList();

  List<Parcel> get _visibleParcels {
    switch (_tab) {
      case 'livres':
        return _deliveredParcels;
      case 'annules':
        return _cancelledParcels;
      default:
        return _inProgressParcels;
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcels = _visibleParcels;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + 8,
            8,
            10,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.cardColor,
            border: Border(bottom: BorderSide(color: AppTheme.slate200)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Mes colis',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.tune_rounded),
                color: AppTheme.slate700,
                tooltip: 'Filtres',
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: const BoxDecoration(
            color: AppTheme.cardColor,
            border: Border(bottom: BorderSide(color: AppTheme.slate200)),
          ),
          child: _MesColisSegmentedTabs(
            value: _tab,
            counts: {
              'cours': _inProgressParcels.length,
              'livres': _deliveredParcels.length,
              'annules': _cancelledParcels.length,
            },
            onChanged: (value) => setState(() => _tab = value),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: AppTheme.primary,
            child: widget.parcelState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : parcels.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
                        children: [
                          _MesColisEmptyState(
                            onNew: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NewParcelScreen(),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                        itemCount: parcels.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final parcel = parcels[index];
                          return _ClientRecentParcelCard(
                            parcel: parcel,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ParcelDetailScreen(parcel: parcel),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

class _MesColisSegmentedTabs extends StatelessWidget {
  final String value;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  const _MesColisSegmentedTabs({
    required this.value,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('cours', 'En cours'),
      ('livres', 'Livrés'),
      ('annules', 'Annulés'),
    ];

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: items.map((item) {
          final selected = value == item.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: selected ? AppTheme.cardColor : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: InkWell(
                  onTap: () => onChanged(item.$1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      boxShadow:
                          selected ? AppTheme.softShadow(alpha: 0.05) : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            item.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primaryLight
                                : AppTheme.slate200,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${counts[item.$1] ?? 0}',
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MesColisEmptyState extends StatelessWidget {
  final VoidCallback onNew;

  const _MesColisEmptyState({required this.onNew});

  @override
  Widget build(BuildContext context) {
    return ProcolisCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: AppTheme.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun colis ici',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Vos colis de cette catégorie apparaîtront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nouveau colis'),
          ),
        ],
      ),
    );
  }
}

class _ClientRecentParcelCard extends StatelessWidget {
  final Parcel parcel;
  final VoidCallback onTap;

  const _ClientRecentParcelCard({
    required this.parcel,
    required this.onTap,
  });

  String get _arrival => parcel.arrivalGarageName?.isNotEmpty == true
      ? parcel.arrivalGarageName!
      : '—';

  String get _price {
    final amount =
        parcel.negotiatedPrice ?? parcel.price ?? parcel.proposedPrice;
    if (amount == null) return '';
    return '${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match[1]} ',
        )} FCFA';
  }

  String get _eta {
    final target = parcel.estimatedDeliveryDate ?? parcel.deliveryDate;
    if (target == null) return '~4 h';
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return 'Arrivé';
    if (diff.inDays > 0) return '${diff.inDays} j';
    if (diff.inHours > 0) return '~${diff.inHours} h';
    return '${diff.inMinutes.clamp(1, 59)} min';
  }

  @override
  Widget build(BuildContext context) {
    return ProcolisCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                color: AppTheme.slate400,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        parcel.trackingNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.mono(
                          color: AppTheme.slate700,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (parcel.isUrgent) ...[
                      const SizedBox(width: 5),
                      const Text(
                        '»',
                        style: TextStyle(
                          color: AppTheme.red400,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _ClientRecentStatusBadge(status: parcel.status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ClientRouteEnd(
                  label: 'Départ',
                  value: parcel.departureGarageName.isEmpty
                      ? '—'
                      : parcel.departureGarageName,
                  alignEnd: false,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.local_shipping_rounded,
                color: AppTheme.teal500,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ClientRouteEnd(
                  label: 'Arrivée',
                  value: _arrival,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _ClientParcelMeta(
                icon: Icons.scale_rounded,
                text: parcel.formattedWeight,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ClientParcelMeta(
                  icon: Icons.category_rounded,
                  text: parcel.type.label,
                ),
              ),
              const SizedBox(width: 14),
              _ClientParcelMeta(
                icon: Icons.schedule_rounded,
                text: _eta,
              ),
              if (_price.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  _price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    color: AppTheme.teal600,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
          if (parcel.status == ParcelStatus.free && parcel.bids.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.chevron_right_rounded),
                label: Text('${parcel.bids.length} offres reçues'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.teal100),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClientRecentStatusBadge extends StatelessWidget {
  final ParcelStatus status;

  const _ClientRecentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: colors.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ClientRouteEnd extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _ClientRouteEnd({
    required this.label,
    required this.value,
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
            color: AppTheme.slate400,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ClientParcelMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ClientParcelMeta({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.slate400, size: 16),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class HomeScreen extends StatelessWidget {
  final User? user;
  final ParcelState parcelState;
  final VoidCallback onRefresh;
  final VoidCallback onNotificationsTap;
  final int unreadNotificationsCount;

  const HomeScreen({
    super.key,
    required this.user,
    required this.parcelState,
    required this.onRefresh,
    required this.onNotificationsTap,
    this.unreadNotificationsCount = 0,
  });

  List<Parcel> get _visibleParcels {
    final currentUser = user;
    if (currentUser == null) return [];

    final parcels = parcelState.parcels.where((parcel) {
      final isSender = parcel.senderName == currentUser.fullName ||
          parcel.senderPhone == currentUser.phone ||
          parcel.senderEmail == currentUser.email;
      final isReceiver = parcel.receiverName == currentUser.fullName ||
          parcel.receiverPhone == currentUser.phone ||
          parcel.receiverEmail == currentUser.email;
      return isSender || isReceiver;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return parcels;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = user;
    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final parcels = _visibleParcels;
    final recentParcels = parcels.take(2).toList();
    final inProgressCount =
        parcels.where((parcel) => parcel.isInProgress).length;
    final deliveredCount = parcels.where((parcel) => parcel.isDelivered).length;
    final points = deliveredCount > 0 ? deliveredCount * 90 : 2450;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ClientHomeHero(
            user: currentUser,
            points: points,
            unreadNotificationsCount: unreadNotificationsCount,
            onNotificationsTap: onNotificationsTap,
            onWalletTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WalletScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ClientQuickActions(
                  onNew: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NewParcelScreen(),
                    ),
                  ),
                  onLibre: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdvertisementsScreen(),
                    ),
                  ),
                  onTrack: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrackParcelScreen(),
                      ),
                    );
                  },
                  onHistory: onRefresh,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _DesignStatBox(
                        icon: Icons.inventory_2_rounded,
                        value: '$inProgressCount',
                        label: 'Colis en cours',
                        tone: AppTheme.primary,
                        background: AppTheme.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DesignStatBox(
                        icon: Icons.task_alt_rounded,
                        value: '$deliveredCount',
                        label: 'Colis livrés',
                        tone: AppTheme.successColor,
                        background: AppTheme.green50,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ProcolisSectionHeader(
                  title: 'Mes colis récents',
                  action: 'Tout voir',
                  onAction: onRefresh,
                ),
                if (parcelState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: CircularProgressIndicator(),
                  )
                else if (recentParcels.isEmpty)
                  _ClientEmptyRecent(onNew: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NewParcelScreen(),
                      ),
                    );
                  })
                else
                  Column(
                    children: recentParcels
                        .map(
                          (parcel) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ClientRecentParcelCard(
                              parcel: parcel,
                              onTap: () => _openParcel(context, parcel),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openParcel(BuildContext context, Parcel parcel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParcelDetailScreen(parcel: parcel),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ClientHomeHero extends StatelessWidget {
  final User user;
  final int points;
  final int unreadNotificationsCount;
  final VoidCallback onNotificationsTap;
  final VoidCallback onWalletTap;

  const _ClientHomeHero({
    required this.user,
    required this.points,
    required this.unreadNotificationsCount,
    required this.onNotificationsTap,
    required this.onWalletTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppTheme.green500,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bonjour,',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _HomeGhostIconButton(icon: Icons.search_rounded),
                  const SizedBox(width: 4),
                  _HomeNotificationButton(
                    unread: unreadNotificationsCount,
                    onTap: onNotificationsTap,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ClientPointsCard(
                points: points,
                inverse: true,
                onTap: onWalletTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientPointsCard extends StatelessWidget {
  final int points;
  final bool inverse;
  final VoidCallback onTap;

  const _ClientPointsCard({
    required this.points,
    required this.inverse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = inverse ? Colors.white : AppTheme.textPrimary;
    final muted = inverse ? Colors.white70 : AppTheme.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: inverse
                ? Colors.white.withValues(alpha: 0.14)
                : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: inverse ? null : Border.all(color: AppTheme.slate200),
            boxShadow: inverse ? null : AppTheme.softShadow(alpha: 0.05),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: inverse
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppTheme.amber50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: inverse ? Colors.white : AppTheme.amber500,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOLDE DE POINTS',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text.rich(
                      TextSpan(
                        text: _formatPoints(points),
                        children: const [
                          TextSpan(
                            text: ' pts',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      style: AppTheme.mono(
                        color: foreground,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Recharger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.amber400,
                  foregroundColor: const Color(0xFF3A2600),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPoints(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match[1]} ',
        );
  }
}

class _ClientQuickActions extends StatelessWidget {
  final VoidCallback onNew;
  final VoidCallback onLibre;
  final VoidCallback onTrack;
  final VoidCallback onHistory;

  const _ClientQuickActions({
    required this.onNew,
    required this.onLibre,
    required this.onTrack,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ProcolisQuickAction(
            icon: Icons.add_box_rounded,
            label: 'Nouveau',
            onTap: onNew,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ProcolisQuickAction(
            icon: Icons.sell_rounded,
            label: 'Libre service',
            onTap: onLibre,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ProcolisQuickAction(
            icon: Icons.qr_code_2_rounded,
            label: 'Suivre',
            onTap: onTrack,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ProcolisQuickAction(
            icon: Icons.history_rounded,
            label: 'Historique',
            onTap: onHistory,
          ),
        ),
      ],
    );
  }
}

class _HomeGhostIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HomeGhostIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _HomeNotificationButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const _HomeNotificationButton({
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _HomeGhostIconButton(icon: Icons.notifications_rounded, onTap: onTap),
        if (unread > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.amber400,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.teal600, width: 2),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Color(0xFF3A2600),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ClientEmptyRecent extends StatelessWidget {
  final VoidCallback onNew;

  const _ClientEmptyRecent({required this.onNew});

  @override
  Widget build(BuildContext context) {
    return ProcolisCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(Icons.inbox_rounded, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            'Aucun colis récent',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Créez un colis pour démarrer le suivi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nouveau colis'),
          ),
        ],
      ),
    );
  }
}

class _DesignStatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color tone;
  final Color background;

  const _DesignStatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return ProcolisCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: tone, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final List<Color> gradientColors;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color.darken(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.darken(),
            ),
          ),
        ],
      ),
    );
  }
}

extension ColorExtension on Color {
  Color darken() {
    return Color.fromRGBO(
      (this.red * 0.8).round(),
      (this.green * 0.8).round(),
      (this.blue * 0.8).round(),
      1,
    );
  }
}
