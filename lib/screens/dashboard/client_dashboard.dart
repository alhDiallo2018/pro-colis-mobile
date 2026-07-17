// lib/screens/dashboard/client_dashboard.dart
// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors, deprecated_member_use, unnecessary_this, unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/screens/dashboard/notifications/notifications_screen.dart';
import 'package:procolis/services/api_service.dart';

import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/parcel_card.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/procolis_design_system.dart';
import '../../widgets/segmented_control.dart';
// IMPORTANT: Importer le nouvel écran d'annonces
import '../parcel/ads/advertisements_screen.dart'; // <-- NOUVEAU CHEMIN
import '../parcel/create_colis_sheet.dart';
import '../parcel/offres_recues_screen.dart';
import '../parcel/parcel_detail_screen.dart';
import '../parcel/track_parcel_screen.dart';
import '../profile/profile_screen.dart';
import '../shared/messages_screen.dart';
import '../wallet/wallet_screen.dart';
import '../../services/notification_service.dart';

class ClientDashboard extends ConsumerStatefulWidget {
  const ClientDashboard({super.key});

  @override
  ConsumerState<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends ConsumerState<ClientDashboard> {
  int _selectedIndex = 0;
  int _unreadNotificationsCount = 0;
  int _unreadMessagesCount = 0;
  final ApiService _apiService = ApiService();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNotificationsCount();
    _loadMessagesUnread();

    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadNotificationsCount();
        _loadMessagesUnread();
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

  /// Compte les messages non-lus (conversations où je suis destinataire) et
  /// déclenche une notification locale quand un nouveau message arrive.
  Future<void> _loadMessagesUnread() async {
    final myId = ref.read(authProvider).user?.id;
    if (myId == null) return;
    try {
      final convs = await _apiService.getConversations();
      int count = 0;
      Map<String, dynamic>? latest;
      for (final c in convs) {
        final receiver = c['receiver'] as Map<String, dynamic>?;
        final isRead = c['isRead'] == true;
        if (receiver?['id']?.toString() == myId && !isRead) {
          count++;
          latest ??= c;
        }
      }
      if (!mounted) return;
      final increased = count > _unreadMessagesCount;
      setState(() => _unreadMessagesCount = count);
      if (increased && latest != null) {
        final sender =
            latest['sender']?['fullName']?.toString() ?? 'Nouveau message';
        final body = latest['body']?.toString() ?? '';
        NotificationService.showNotification(
          id: 'sendprocolis-msg'.hashCode,
          title: '💬 $sender',
          body: body.isNotEmpty ? body : 'Vous avez reçu un nouveau message',
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final parcelState = ref.watch(parcelProvider);

    // Synchronise l'onglet avec la barre de navigation persistante (AppBottomNav)
    ref.listen<int>(dashboardTabProvider, (prev, next) {
      if (next != _selectedIndex && next >= 0 && next < 5) {
        setState(() => _selectedIndex = next);
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _getScreen(_selectedIndex, user, parcelState),
      bottomNavigationBar: ProcolisTabBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          ref.read(dashboardTabProvider.notifier).state = index;
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
                showCreateColisSheet(context);
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
          onNavigateToTab: (i) => setState(() => _selectedIndex = i),
          onNotificationsTap: _onNotificationsTap,
          unreadNotificationsCount: _unreadNotificationsCount,
          unreadMessagesCount: _unreadMessagesCount,
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
        return const ProfileScreen(embedded: true);
      default:
        return HomeScreen(
          user: user,
          parcelState: parcelState,
          onRefresh: _loadData,
          onNotificationsTap: _onNotificationsTap,
          unreadNotificationsCount: _unreadNotificationsCount,
          unreadMessagesCount: _unreadMessagesCount,
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
            'SENDPROCOLIS',
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
  int _groupIndex = 0;
  String _searchQuery = '';

  // Groupes de statut alignés sur le web (Tous / En attente / En transit /
  // Livrés / Annulés), chacun couvrant plusieurs statuts bruts.
  static const List<(String, List<ParcelStatus>)> _statusGroups = [
    ('Tous', <ParcelStatus>[]),
    (
      'Attente',
      [ParcelStatus.pending, ParcelStatus.free, ParcelStatus.confirmed]
    ),
    (
      'Transit',
      [
        ParcelStatus.pickedUp,
        ParcelStatus.inTransit,
        ParcelStatus.arrived,
        ParcelStatus.outForDelivery
      ]
    ),
    ('Livrés', [ParcelStatus.delivered]),
    ('Annulés', [ParcelStatus.cancelled]),
  ];
  String _selectedSort = 'recent';
  String _selectedTypeFilter = '';
  final TextEditingController _searchController = TextEditingController();

  static const Map<String, String> _sortLabels = {
    'recent': 'Plus récents',
    'old': 'Plus anciens',
    'price_desc': 'Prix décroissant',
    'price_asc': 'Prix croissant',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Parcel> _applyFilters(List<Parcel> parcels) {
    final query = _searchQuery.trim().toLowerCase();

    var filtered = _selectedTypeFilter.isEmpty
        ? parcels
        : parcels.where((p) => p.type.value == _selectedTypeFilter).toList();

    if (query.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.trackingNumber.toLowerCase().contains(query) ||
            (p.arrivalGarageName?.toLowerCase().contains(query) ?? false) ||
            p.departureGarageName.toLowerCase().contains(query) ||
            p.receiverName.toLowerCase().contains(query);
      }).toList();
    }

    switch (_selectedSort) {
      case 'old':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'price_desc':
        filtered.sort((a, b) => ((b.price ?? 0)).compareTo(a.price ?? 0));
        break;
      case 'price_asc':
        filtered.sort((a, b) => ((a.price ?? 0)).compareTo(b.price ?? 0));
        break;
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return filtered;
  }

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
    final match = _statusGroups[_groupIndex].$2;
    final base = match.isEmpty
        ? widget.parcelState.parcels
        : widget.parcelState.parcels
            .where((p) => match.contains(p.status))
            .toList();
    return _applyFilters(base);
  }

  Widget _buildTypeChip(String value, String label) {
    final selected = _selectedTypeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTypeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.slate100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.slate500,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSortSelector() {
    return GestureDetector(
      onTap: _showSortSheet,
      child: Row(
        children: [
          const Text(
            'Trier par',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _sortLabels[_selectedSort]!,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const Icon(Icons.unfold_more_rounded, size: 16, color: AppTheme.slate400),
        ],
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Trier par',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                ..._sortLabels.entries.map((entry) {
                  final selected = _selectedSort == entry.key;
                  return ListTile(
                    title: Text(entry.value),
                    trailing: selected
                        ? const Icon(Icons.check_rounded, color: AppTheme.primary)
                        : null,
                    onTap: () {
                      setState(() => _selectedSort = entry.key);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
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
              Expanded(
                child: Text(
                  'Mes colis',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
          child: SegmentedControl(
            options: _statusGroups.map((g) => g.$1).toList(),
            selectedIndex: _groupIndex,
            onChanged: (i) => setState(() => _groupIndex = i),
          ),
        ),
        if (widget.parcelState.parcels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: PcCard(
              radius: AppTheme.radiusLg,
              padding: const EdgeInsets.all(14),
              shadow: AppTheme.shadowXs(),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Rechercher (suivi, ville, destinataire…)',
                      hintStyle: const TextStyle(fontSize: 14, color: AppTheme.slate400),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.slate400),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.slate50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTypeChip('', 'Tous'),
                        const SizedBox(width: 8),
                        _buildTypeChip('document', 'Documents'),
                        const SizedBox(width: 8),
                        _buildTypeChip('package', 'Colis standard'),
                        const SizedBox(width: 8),
                        _buildTypeChip('fragile', 'Fragiles'),
                        const SizedBox(width: 8),
                        _buildTypeChip('perishable', 'Périssables'),
                        const SizedBox(width: 8),
                        _buildTypeChip('valuable', 'Précieux'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSortSelector(),
                ],
              ),
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
                            onNew: () => showCreateColisSheet(context),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                        itemCount: parcels.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final parcel = parcels[index];
                          return ParcelCard(
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
      const _StatusTab('cours', 'En cours'),
      const _StatusTab('livres', 'Livrés'),
      const _StatusTab('annules', 'Annulés'),
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
          final selected = value == item.key;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: selected ? AppTheme.cardColor : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: InkWell(
                  onTap: () => onChanged(item.key),
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
                            item.label,
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
                            '${counts[item.key] ?? 0}',
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
  final ValueChanged<int>? onNavigateToTab;
  final VoidCallback onNotificationsTap;
  final int unreadNotificationsCount;
  final int unreadMessagesCount;

  const HomeScreen({
    super.key,
    required this.user,
    required this.parcelState,
    required this.onRefresh,
    this.onNavigateToTab,
    required this.onNotificationsTap,
    this.unreadNotificationsCount = 0,
    this.unreadMessagesCount = 0,
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
    final recentParcels = parcels.take(5).toList();
    final inProgressCount =
        parcels.where((parcel) => parcel.isInProgress).length;
    final deliveredCount = parcels.where((parcel) => parcel.isDelivered).length;
    final libreCount = parcels.where((parcel) => parcel.isFree).length;
    final points = deliveredCount > 0 ? deliveredCount * 90 : 2450;

    // Agrège toutes les offres (bids) en attente reçues sur les colis du client.
    final pendingOffers = <_OfferPreview>[];
    for (final parcel in parcels) {
      for (final bid in parcel.pendingBids) {
        pendingOffers.add(_OfferPreview(parcel: parcel, bid: bid));
      }
    }
    pendingOffers.sort((a, b) => b.bid.createdAt.compareTo(a.bid.createdAt));

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
            unreadMessagesCount: unreadMessagesCount,
            onNotificationsTap: onNotificationsTap,
            onChatTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesScreen()),
            ),
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
                  onNew: () => showCreateColisSheet(context),
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
                  onOffers: () => _openOffers(context),
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DesignStatBox(
                        icon: Icons.sell_rounded,
                        value: '$libreCount',
                        label: 'Annonces',
                        tone: AppTheme.amber500,
                        background: AppTheme.amber50,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _ClientOffersPanel(
                  offers: pendingOffers,
                  onSeeAll: () => _openOffers(context),
                ),
                const SizedBox(height: 22),
                ProcolisSectionHeader(
                  title: 'Mes colis récents',
                  action: 'Tout voir',
                  onAction: () => onNavigateToTab?.call(1),
                ),
                if (parcelState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: CircularProgressIndicator(),
                  )
                else if (recentParcels.isEmpty)
                  _ClientEmptyRecent(onNew: () {
                    showCreateColisSheet(context);
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
    context.push('/parcel/${parcel.id}', extra: parcel);
  }

  void _openOffers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OffresRecuesScreen(),
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
  final int unreadMessagesCount;
  final VoidCallback onNotificationsTap;
  final VoidCallback onChatTap;
  final VoidCallback onWalletTap;

  const _ClientHomeHero({
    required this.user,
    required this.points,
    required this.unreadNotificationsCount,
    required this.unreadMessagesCount,
    required this.onNotificationsTap,
    required this.onChatTap,
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
                        backgroundColor: Colors.white.withOpacity(0.18),
                        backgroundImage: user.profilePhoto != null && user.profilePhoto!.isNotEmpty
                            ? NetworkImage(
                                user.profilePhoto!.startsWith('http')
                                    ? user.profilePhoto!
                                    : ApiService.resolveMediaUrl(user.profilePhoto!),
                              )
                            : null,
                        child: user.profilePhoto != null && user.profilePhoto!.isNotEmpty
                            ? null
                            : Text(
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
                  _HomeNotificationButton(
                    unread: unreadMessagesCount,
                    onTap: onChatTap,
                    icon: Icons.chat_rounded,
                  ),
                  const SizedBox(width: 4),
                  _HomeNotificationButton(
                    unread: unreadNotificationsCount,
                    onTap: onNotificationsTap,
                  ),
                ],
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
                ? Colors.white.withOpacity( 0.14)
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
                      ? Colors.white.withOpacity( 0.18)
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
              IconButton(
                onPressed: onTap,
                icon: Icon(Icons.chevron_right_rounded, color: foreground),
                tooltip: 'Voir mes points',
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
  final VoidCallback onOffers;

  const _ClientQuickActions({
    required this.onNew,
    required this.onLibre,
    required this.onTrack,
    required this.onOffers,
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
            icon: Icons.local_offer_rounded,
            label: 'Offres',
            onTap: onOffers,
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
  final IconData icon;

  const _HomeNotificationButton({
    required this.unread,
    required this.onTap,
    this.icon = Icons.notifications_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _HomeGhostIconButton(icon: icon, onTap: onTap),
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

/// Prévisualisation d'une offre (bid) rattachée à son colis, pour le tableau
/// de bord.
class _OfferPreview {
  final Parcel parcel;
  final Bid bid;

  const _OfferPreview({required this.parcel, required this.bid});
}

/// Panneau "Offres reçues" du tableau de bord client : les 3 offres en attente
/// les plus récentes + un bouton "Voir toutes les offres". Parité web
/// (ClientDashboard.tsx).
class _ClientOffersPanel extends StatelessWidget {
  final List<_OfferPreview> offers;
  final VoidCallback onSeeAll;

  const _ClientOffersPanel({required this.offers, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final top = offers.take(3).toList();
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Offres reçues',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (offers.isNotEmpty)
                PcBadge('${offers.length}', tone: PcTone.primary),
            ],
          ),
          if (top.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Aucune offre reçue pour le moment.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            ...top.map((offer) => _OfferPreviewRow(offer: offer)),
            const SizedBox(height: 12),
            PcButton(
              'Voir toutes les offres',
              variant: PcButtonVariant.secondary,
              size: PcButtonSize.sm,
              block: true,
              iconTrailing: Icons.chevron_right_rounded,
              onPressed: onSeeAll,
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferPreviewRow extends StatelessWidget {
  final _OfferPreview offer;

  const _OfferPreviewRow({required this.offer});

  @override
  Widget build(BuildContext context) {
    final bid = offer.bid;
    final driverName = bid.driverName.isEmpty ? 'Chauffeur' : bid.driverName;
    final subtitle = bid.message?.trim().isNotEmpty == true
        ? bid.message!.trim()
        : offer.parcel.trackingNumber;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          PcAvatar(driverName, size: 38, status: PcAvatarStatus.online),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatMoney(bid.price)} FCFA',
            style: AppTheme.mono(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.teal600,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMoney(double value) {
    final str = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(str[i]);
    }
    return buffer.toString();
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
            color: color.withOpacity( 0.2),
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

class _StatusTab {
  final String key;
  final String label;
  const _StatusTab(this.key, this.label);
}
