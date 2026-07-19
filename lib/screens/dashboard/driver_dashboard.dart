// mobile/lib/screens/dashboard/driver_dashboard.dart
// ignore_for_file: unused_import, deprecated_member_use, prefer_const_constructors, unused_element_parameter

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/models/payment.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/models/voice_message.dart';
import 'package:procolis/screens/dashboard/notifications/notifications_screen.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/services/commission_service.dart';
import 'package:procolis/services/notification_service.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:record/record.dart';

import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/availability_toggle.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/procolis_design_system.dart';
import '../driver/create_annonce_sheet.dart';
import '../driver/revenus_screen.dart';
import '../driver/mes_annonces_screen.dart';
import '../driver/parametres_screen.dart';
import '../driver/points_screen.dart';
import '../driver/garage_screen.dart';
import '../driver/historique_screen.dart';
import '../driver/vehicle_documents_screen.dart';
import '../shared/messages_screen.dart';
import '../parcel/free_parcels_screen.dart';
import '../parcel/track_parcel_screen.dart';
import '../parcel/confirm_delivery_screen.dart';
import '../parcel/parcel_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';


class _SearchBar extends StatelessWidget {
  final void Function(String query) onSearch;

  const _SearchBar({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showSearch(
          context: context,
          delegate: _DriverSearchDelegate(onSearch: onSearch),
        );
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppTheme.slate400),
            const SizedBox(width: 10),
            Text(
              'Rechercher un colis, un chauffeur…',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.slate400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverSearchDelegate extends SearchDelegate<String> {
  final void Function(String query) onSearch;

  _DriverSearchDelegate({required this.onSearch}) : super(
    searchFieldLabel: 'Rechercher un colis, un chauffeur…',
  );

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isNotEmpty) {
      return [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];
    }
    return null;
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isNotEmpty) {
      onSearch(query.trim());
      close(context, query.trim());
    }
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text('Entrez un numéro de suivi de colis.',
        style: TextStyle(color: AppTheme.slate500),
      ),
    );
  }
}

// ==================== DRIVER DASHBOARD ====================

class DriverDashboard extends ConsumerStatefulWidget {
  const DriverDashboard({super.key});

  @override
  ConsumerState<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboard> {
  int _selectedIndex = 0;
  int _unreadNotificationsCount = 0;
  int _unreadMessagesCount = 0;
  bool _isUpdatingStatus = false;
  final ApiService _dashApi = ApiService();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNotificationsCount();
    _loadMessagesUnread();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _loadNotificationsCount();
      _loadMessagesUnread();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _loadData() {
    Future.microtask(() {
      ref.read(parcelProvider.notifier).loadDriverParcels();
      ref.read(parcelProvider.notifier).loadFreeParcels();
    });
  }

  Future<void> _loadNotificationsCount() async {
    try {
      final c = await _dashApi.getUnreadNotificationsCount();
      if (mounted) setState(() => _unreadNotificationsCount = c);
    } catch (_) {}
  }

  /// Messages non-lus (conversations où je suis destinataire) + notification
  /// locale à la réception d'un nouveau message.
  Future<void> _loadMessagesUnread() async {
    final myId = ref.read(authProvider).user?.id;
    if (myId == null) return;
    try {
      final convs = await _dashApi.getConversations();
      int count = 0;
      Map<String, dynamic>? latest;
      for (final conv in convs) {
        final receiver = conv['receiver'] as Map<String, dynamic>?;
        final isRead = conv['isRead'] == true;
        if (receiver?['id']?.toString() == myId && !isRead) {
          count++;
          latest ??= conv;
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
          id: 'sendprocolis-drv-msg'.hashCode,
          title: '💬 $sender',
          body: body.isNotEmpty ? body : 'Vous avez reçu un nouveau message',
        );
      }
    } catch (_) {}
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

  void _openPublishTrip() {
    showCreateAnnonceSheet(context).then((created) {
      if (created == true) {
        _loadData();
        setState(() => _selectedIndex = 1);
      }
    });
  }

  Future<void> _toggleAvailability() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final newStatus = user.isDriverAvailable ? 'offline' : 'available';
    setState(() => _isUpdatingStatus = true);
    await ref.read(authProvider.notifier).updateDriverStatus(newStatus);
    if (mounted) setState(() => _isUpdatingStatus = false);
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
        },
        items: [
          const ProcolisTabItem(
            icon: Icons.dashboard_rounded,
            label: 'Tableau',
          ),
          ProcolisTabItem(
            icon: Icons.sell_rounded,
            label: 'À prendre',
            badge: parcelState.freeParcels.length,
          ),
          ProcolisTabItem(
            icon: Icons.local_shipping_rounded,
            label: 'Missions',
            badge: parcelState.parcels.length,
          ),
          const ProcolisTabItem(
            icon: Icons.campaign_rounded,
            label: 'Annonces',
          ),
          const ProcolisTabItem(
            icon: Icons.person_rounded,
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _getScreen(int index, User? user, ParcelState parcelState) {
    switch (index) {
      case 0:
        return _DriverTableauScreen(
          parcelState: parcelState,
          user: user,
          onNotificationsTap: _onNotificationsTap,
          unreadNotificationsCount: _unreadNotificationsCount,
          unreadMessagesCount: _unreadMessagesCount,
          onViewMissions: () => setState(() => _selectedIndex = 2),
          onViewPool: () => setState(() => _selectedIndex = 1),
          onPublishTrip: _openPublishTrip,
          isUpdatingStatus: _isUpdatingStatus,
          onToggleAvailability: _toggleAvailability,
        );
      case 1:
        return _DriverPoolTabScreen(
          parcelState: parcelState,
          onRefresh: _loadData,
          onPublishTrip: _openPublishTrip,
        );
      case 2:
        return _DriverMissionsTabScreen(
          parcelState: parcelState,
          onRefresh: _loadData,
        );
      case 3:
        return const DriverMesAnnoncesScreen(embedded: true);
      case 4:
        return _DriverProfileTabScreen(
          user: user,
          activeMissionsCount: parcelState.parcels
              .where((parcel) =>
                  parcel.status == ParcelStatus.confirmed ||
                  parcel.status.isInProgress)
              .length,
        );
      default:
        return _DriverMissionsTabScreen(
          parcelState: parcelState,
          onRefresh: _loadData,
        );
    }
  }
}

/// Action de cycle de vie côté chauffeur : un seul bouton contextuel qui fait
/// avancer la mission (aligné sur le web MissionsScreen). L'étape `deliver`
/// bascule vers le flux OTP (ConfirmDeliveryScreen).
class _DriverStepAction {
  final String step;
  final String label;
  final IconData icon;
  const _DriverStepAction(this.step, this.label, this.icon);
}

_DriverStepAction? _driverNextStep(ParcelStatus status) {
  switch (status) {
    case ParcelStatus.pending:
      return const _DriverStepAction(
          'confirm', 'Confirmer la prise en charge', Icons.check_circle_rounded);
    case ParcelStatus.confirmed:
      return const _DriverStepAction(
          'pickup', 'Marquer ramassé', Icons.inventory_2_rounded);
    case ParcelStatus.pickedUp:
      return const _DriverStepAction(
          'transit', 'Marquer en transit', Icons.local_shipping_rounded);
    case ParcelStatus.inTransit:
      return const _DriverStepAction(
          'arrived', 'Marquer arrivé', Icons.pin_drop_rounded);
    case ParcelStatus.arrived:
      return const _DriverStepAction(
          'out-for-delivery', 'En livraison', Icons.delivery_dining_rounded);
    case ParcelStatus.outForDelivery:
      return const _DriverStepAction(
          'deliver', 'Confirmer livraison', Icons.task_alt_rounded);
    default:
      return null;
  }
}

class _DriverTableauScreen extends StatefulWidget {
  final ParcelState parcelState;
  final User? user;
  final VoidCallback onNotificationsTap;
  final int unreadNotificationsCount;
  final int unreadMessagesCount;
  final VoidCallback onViewMissions;
  final VoidCallback onViewPool;
  final VoidCallback onPublishTrip;
  final bool isUpdatingStatus;
  final Future<void> Function() onToggleAvailability;

  const _DriverTableauScreen({
    required this.parcelState,
    required this.user,
    required this.onNotificationsTap,
    required this.unreadNotificationsCount,
    required this.unreadMessagesCount,
    required this.onViewMissions,
    required this.onViewPool,
    required this.onPublishTrip,
    required this.isUpdatingStatus,
    required this.onToggleAvailability,
  });

  @override
  State<_DriverTableauScreen> createState() => _DriverTableauScreenState();
}

class _DriverTableauScreenState extends State<_DriverTableauScreen> {
  final ApiService _api = ApiService();
  double? _walletBalance;
  List<Map<String, dynamic>> _bidsSent = [];
  List<Map<String, dynamic>> _ads = [];
  double _weekRevenue = 0;
  List<double> _revenueBars = List<double>.filled(7, 0);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final results = await Future.wait([
      _api.getWalletBalance(widget.user?.id ?? ''),
      _api.getDriverBidsSent(),
      _api.getMyAdvertisements(),
      _api.getPaymentHistory(),
    ]);
    if (!mounted) return;
    final payments = results[3] as List<Map<String, dynamic>>;
    final now = DateTime.now();
    final weekStart =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final bars = List<double>.filled(7, 0);
    double weekTotal = 0;
    for (final p in payments) {
      final amount = (p['amount'] ?? 0).toDouble();
      try {
        final date = DateTime.parse(p['createdAt']?.toString() ?? '');
        final dayIndex = date.difference(weekStart).inDays;
        if (dayIndex >= 0 && dayIndex < 7) {
          bars[dayIndex] += amount;
          weekTotal += amount;
        }
      } catch (_) {}
    }
    setState(() {
      _walletBalance = results[0] as double;
      _bidsSent = results[1] as List<Map<String, dynamic>>;
      _ads = results[2] as List<Map<String, dynamic>>;
      _revenueBars = bars;
      _weekRevenue = weekTotal;
    });
  }

  void _openItinerary(Parcel parcel) {
    _api.getAllGarages().then((garages) {
      if (!mounted) return;
      context.push('/driver/itinerary', extra: {
        'departureName': parcel.departureGarageName,
        'arrivalName': parcel.arrivalGarageName ?? '',
        'garages': garages,
      });
    });
  }

  String _fcfa(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match[1]} ',
        );
  }

  List<Parcel> get _activeMissions {
    final missions = widget.parcelState.parcels
        .where((parcel) =>
            parcel.status.isInProgress ||
            parcel.status == ParcelStatus.confirmed)
        .toList();
    return missions.isNotEmpty ? missions : widget.parcelState.parcels;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final activeMission =
        _activeMissions.isNotEmpty ? _activeMissions.first : null;
    final availableParcel = widget.parcelState.freeParcels.isNotEmpty
        ? widget.parcelState.freeParcels.first
        : null;
    final deliveries = user?.completedDeliveries ?? user?.totalDeliveries ?? 0;
    final activeCount = _activeMissions.length;
    final wallet =
        _walletBalance != null ? '${_fcfa(_walletBalance!)}' : '—';
    final rating =
        (user?.rating ?? 4.9).toStringAsFixed(1).replaceAll('.', ',');

    return Column(
      children: [
        _buildHero(user),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _SearchBar(onSearch: (query) {
            if (query.trim().isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => TrackParcelScreen(trackingNumber: query.trim()),
              ));
            }
          }),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: AvailabilityToggle(),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 96),
            children: [
              GridView.count(
                crossAxisCount: 2,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.24,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverPointsScreen())),
                    child: PcStatBox(
                      icon: Icons.account_balance_wallet_rounded,
                      value: '$wallet FCFA',
                      label: 'Portefeuille',
                      tone: PcTone.amber,
                    ),
                  ),
                  PcStatBox(
                    icon: Icons.local_shipping_rounded,
                    value: '$activeCount',
                    label: 'Missions actives',
                    tone: PcTone.primary,
                  ),
                  PcStatBox(
                    icon: Icons.task_alt_rounded,
                    value: '$deliveries',
                    label: 'Livraisons',
                    tone: PcTone.green,
                  ),
                  PcStatBox(
                    icon: Icons.star_rounded,
                    value: rating,
                    label: 'Note moyenne',
                    tone: PcTone.amber,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverPointsScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.amberGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_rounded, color: AppTheme.amberOnFg, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Recharger mon portefeuille', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.amberOnFg)),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.amberOnFg),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PublishTripShortcut(onTap: widget.onPublishTrip),
              const SizedBox(height: 28),
              PcSectionHeader(
                'Mission en cours',
                action: 'Voir tout',
                onAction: widget.onViewMissions,
              ),
              if (activeMission != null)
                _DriverRouteCard(
                  parcel: activeMission,
                  primaryActionLabel: 'Continuer la livraison',
                  primaryActionIcon: Icons.arrow_forward_rounded,
                  onPrimaryAction: widget.onViewMissions,
                  customFooter: Row(
                    children: [
                      Expanded(
                        child: PcButton(
                          'Itinéraire',
                          icon: Icons.navigation_rounded,
                          variant: PcButtonVariant.secondary,
                          block: true,
                          onPressed: () => _openItinerary(activeMission),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PcButton(
                          'Gérer',
                          icon: Icons.checklist_rounded,
                          block: true,
                          onPressed: widget.onViewMissions,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const PcEmptyState(
                  icon: Icons.local_shipping_rounded,
                  title: 'Aucune mission en cours',
                  message: 'Les missions acceptées apparaîtront ici.',
                  tone: PcTone.primary,
                ),
              const SizedBox(height: 28),
              PcSectionHeader(
                'Colis à prendre',
                action: 'Tout voir',
                onAction: widget.onViewPool,
              ),
              if (availableParcel != null)
                _DriverRouteCard(
                  parcel: availableParcel,
                  footerText: '240 km',
                  primaryActionLabel: 'Faire une offre',
                  primaryActionIcon: Icons.gavel_rounded,
                  onPrimaryAction: widget.onViewPool,
                )
              else
                const PcEmptyState(
                  icon: Icons.sell_rounded,
                  title: 'Aucun colis disponible',
                  message: 'Les colis en libre service apparaîtront ici.',
                  tone: PcTone.amber,
                ),
              const SizedBox(height: 28),
              _buildRevenuePanel(),
              const SizedBox(height: 28),
              _buildBidsPanel(),
              const SizedBox(height: 28),
              _buildAdsPanel(),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Revenus · 7 jours (mini graphique, logique de revenus_screen) ----
  Widget _buildRevenuePanel() {
    return PcCard(
      radius: AppTheme.radiusLg,
      shadow: AppTheme.shadowSm(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Revenus · 7 jours',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DriverRevenusScreen()),
                ),
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_fcfa(_weekRevenue)} FCFA',
            style: AppTheme.mono(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          PcBarChart(bars: _revenueBars, labels: const ['L', 'M', 'M', 'J', 'V', 'S', 'D'], height: 96),
        ],
      ),
    );
  }

  // ---- Mes offres (offres envoyées par le chauffeur) ----
  Widget _buildBidsPanel() {
    final top = _bidsSent.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PcSectionHeader('Mes offres'),
        PcCard(
          padding: EdgeInsets.zero,
          child: top.isEmpty
              ? const PcEmptyState(
                  icon: Icons.gavel_rounded,
                  title: 'Aucune offre envoyée',
                  message: 'Vos offres sur les annonces apparaîtront ici.',
                  tone: PcTone.amber,
                )
              : Column(
                  children: [
                    for (var i = 0; i < top.length; i++) ...[
                      if (i > 0) const PcDivider(),
                      _buildBidRow(top[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildBidRow(Map<String, dynamic> bid) {
    final status = bid['status']?.toString() ?? 'pending';
    final price = (bid['price'] ?? 0).toDouble();
    final parcelId = bid['parcelId']?.toString() ?? '';
    final tracking = bid['parcel']?['trackingNumber']?.toString() ??
        (parcelId.length > 8 ? '${parcelId.substring(0, 8)}…' : parcelId);
    late final String statusLabel;
    late final PcTone statusTone;
    switch (status) {
      case 'accepted':
        statusLabel = 'Acceptée';
        statusTone = PcTone.green;
        break;
      case 'rejected':
        statusLabel = 'Refusée';
        statusTone = PcTone.red;
        break;
      default:
        statusLabel = 'En attente';
        statusTone = PcTone.amber;
    }
    return PcListRow(
      icon: Icons.gavel_rounded,
      iconTone: PcTone.primary,
      title: tracking,
      subtitle: '${_fcfa(price)} FCFA proposés',
      trailing: PcBadge(statusLabel, tone: statusTone),
    );
  }

  // ---- Mes annonces (trajets publiés par le chauffeur) ----
  Widget _buildAdsPanel() {
    final top = _ads.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PcSectionHeader(
          'Mes annonces',
          action: 'Voir tout',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverMesAnnoncesScreen()),
          ),
        ),
        PcCard(
          padding: EdgeInsets.zero,
          child: top.isEmpty
              ? const PcEmptyState(
                  icon: Icons.campaign_rounded,
                  title: 'Aucune annonce',
                  message: 'Publiez un trajet pour recevoir des colis.',
                  tone: PcTone.primary,
                )
              : Column(
                  children: [
                    for (var i = 0; i < top.length; i++) ...[
                      if (i > 0) const PcDivider(),
                      _buildAdRow(top[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAdRow(Map<String, dynamic> ad) {
    final departure = ad['departureCity']?.toString() ?? '—';
    final arrival = ad['arrivalCity']?.toString() ?? '—';
    final proposedPrice = ad['proposedPrice'];
    return PcListRow(
      icon: Icons.local_shipping_rounded,
      iconTone: PcTone.primary,
      title: '$departure → $arrival',
      subtitle: 'Trajet publié',
      trailing: proposedPrice != null
          ? Text(
              '${_fcfa(double.tryParse(proposedPrice?.toString() ?? '') ?? 0)} FCFA',
              style: AppTheme.mono(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.teal600,
              ),
            )
          : null,
    );
  }

  Widget _buildHero(User? user) {
    final available = user?.isDriverAvailable ?? false;
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
                        radius: 31,
                        backgroundColor: const Color(0xFFC9F3EE),
                        backgroundImage: user != null &&
                                user.profilePhoto != null &&
                                user.profilePhoto!.isNotEmpty
                            ? NetworkImage(
                                user.profilePhoto!.startsWith('http')
                                    ? user.profilePhoto!
                                    : ApiService.resolveMediaUrl(user.profilePhoto!),
                              )
                            : null,
                        child: user != null &&
                                user.profilePhoto != null &&
                                user.profilePhoto!.isNotEmpty
                            ? null
                            : Text(
                                user?.initials ?? 'PC',
                                style: const TextStyle(
                                  color: AppTheme.teal700,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: 3,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: available
                                ? AppTheme.green500
                                : AppTheme.slate400,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
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
                        Text(
                          'Chauffeur',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          user?.fullName ?? 'Chauffeur',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MessagesScreen()),
                    ),
                    color: Colors.white,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.chat_rounded, size: 26),
                        if (widget.unreadMessagesCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.amber400,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                widget.unreadMessagesCount > 9
                                    ? '9+'
                                    : '${widget.unreadMessagesCount}',
                                style: const TextStyle(
                                    color: Color(0xFF3A2600),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onNotificationsTap,
                    color: Colors.white,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_rounded, size: 28),
                        if (widget.unreadNotificationsCount > 0)
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
                                widget.unreadNotificationsCount > 99 ? '99+' : '${widget.unreadNotificationsCount}',
                                style: const TextStyle(
                                  color: Color(0xFF3A2600),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity( 0.20),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity( 0.18),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Icon(
                        available ? Icons.bolt_rounded : Icons.bedtime_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            available ? 'Vous êtes en ligne' : 'Hors ligne',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            available
                                ? 'Vous recevez les colis disponibles'
                                : 'Vous ne recevez pas de colis',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    widget.isUpdatingStatus
                        ? const SizedBox(
                            width: 40,
                            height: 24,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                            ),
                          )
                        : Switch(
                            value: available,
                            activeColor: Colors.white,
                            activeTrackColor: AppTheme.deep500,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            onChanged: (_) => widget.onToggleAvailability(),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishTripShortcut extends StatelessWidget {
  final VoidCallback onTap;

  const _PublishTripShortcut({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.brandShadow(),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity( 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Publier un voyage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Annoncez votre trajet aux clients',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverRouteCard extends StatelessWidget {
  final Parcel parcel;
  final String? footerText;
  final Widget? customFooter;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback onPrimaryAction;
  final bool showPrimaryAction;
  final VoidCallback? onTap;

  const _DriverRouteCard({
    required this.parcel,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    required this.onPrimaryAction,
    this.footerText,
    this.customFooter,
    this.showPrimaryAction = true,
    this.onTap,
  });

  String _formatFcfa(double amount) {
    final rawAmount = amount.toStringAsFixed(0);
    // Sépare les milliers sans dépendre d'une locale système indisponible
    // dans certains environnements Flutter de test.
    return rawAmount.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]} ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final price =
        parcel.price ?? parcel.proposedPrice ?? parcel.negotiatedPrice ?? 0;
    final destination = parcel.arrivalGarageName?.isNotEmpty == true
        ? parcel.arrivalGarageName!
        : 'Arrivée';

    return PcCard(
      onTap: onTap,
      radius: AppTheme.radiusLg,
      shadow: AppTheme.shadowSm(),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  size: 20, color: AppTheme.slate400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parcel.trackingNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700,
                  ),
                ),
              ),
              ProcolisStatusBadge(status: parcel.status),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: _RouteEndpoint(
                  label: 'DÉPART',
                  value: parcel.departureGarageName,
                  alignEnd: false,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              Expanded(
                child: _RouteEndpoint(
                  label: 'ARRIVÉE',
                  value: destination,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              _RouteMeta(
                icon: Icons.shopping_bag_outlined,
                value:
                    '${parcel.weight.toStringAsFixed(parcel.weight.truncateToDouble() == parcel.weight ? 0 : 1)} kg',
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _RouteMeta(
                  icon: Icons.category_outlined,
                  value: parcel.type.label,
                ),
              ),
              const SizedBox(width: 14),
              const _RouteMeta(icon: Icons.schedule_rounded, value: '~4 h'),
              const SizedBox(width: 18),
              Text(
                '${_formatFcfa(price)}\nFCFA',
                textAlign: TextAlign.left,
                style: AppTheme.mono(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.deep500,
                ),
              ),
            ],
          ),
          if (customFooter != null) ...[
            const SizedBox(height: 18),
            customFooter!,
          ] else if (footerText != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.route_rounded,
                    size: 18, color: AppTheme.slate500),
                const SizedBox(width: 6),
                Text(
                  footerText!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                PcButton(
                  primaryActionLabel,
                  icon: primaryActionIcon,
                  size: PcButtonSize.sm,
                  onPressed: onPrimaryAction,
                ),
              ],
            ),
          ] else if (showPrimaryAction) ...[
            const SizedBox(height: 22),
            PcButton(
              primaryActionLabel,
              iconTrailing: primaryActionIcon,
              block: true,
              size: PcButtonSize.lg,
              onPressed: onPrimaryAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteEndpoint extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _RouteEndpoint({
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
          label,
          style: const TextStyle(
            color: AppTheme.slate400,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RouteMeta extends StatelessWidget {
  final IconData icon;
  final String value;

  const _RouteMeta({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppTheme.slate400),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== TAB À PRENDRE ====================

class _DriverPoolTabScreen extends StatefulWidget {
  final ParcelState parcelState;
  final VoidCallback onRefresh;
  final VoidCallback onPublishTrip;

  const _DriverPoolTabScreen({
    required this.parcelState,
    required this.onRefresh,
    required this.onPublishTrip,
  });

  @override
  State<_DriverPoolTabScreen> createState() => _DriverPoolTabScreenState();
}

class _DriverPoolTabScreenState extends State<_DriverPoolTabScreen> {
  String _selectedFilter = 'Tous';

  List<String> get _filters => const [
        'Tous',
        'Abidjan →',
        'Express',
        '< 10 kg',
        'Aujourd’hui',
        'Avec offres',
      ];

  List<Parcel> get _filteredParcels {
    final parcels = widget.parcelState.freeParcels;
    switch (_selectedFilter) {
      case 'Abidjan →':
        return parcels
            .where((parcel) =>
                parcel.departureGarageName.toLowerCase().contains('abidjan'))
            .toList();
      case 'Express':
        return parcels.where((parcel) => parcel.isUrgent).toList();
      case '< 10 kg':
        return parcels.where((parcel) => parcel.weight < 10).toList();
      case 'Aujourd’hui':
        final now = DateTime.now();
        return parcels
            .where((parcel) =>
                parcel.createdAt.year == now.year &&
                parcel.createdAt.month == now.month &&
                parcel.createdAt.day == now.day)
            .toList();
      case 'Avec offres':
        return parcels.where((parcel) => parcel.bids.isNotEmpty).toList();
      default:
        return parcels;
    }
  }

  String _poolFooter(Parcel parcel) {
    // Les maquettes exposent une distance statique; tant que l'API ne fournit
    // pas cette donnée, on conserve un fallback visuel stable.
    final offers = parcel.bids.length;
    return '240 km · $offers offre${offers > 1 ? 's' : ''}';
  }

  Future<void> _refresh() async => widget.onRefresh();

  void _openOffer(Parcel parcel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FreeParcelDetailsScreen(parcel: parcel),
      ),
    ).then((_) => widget.onRefresh());
  }

  @override
  Widget build(BuildContext context) {
    final parcels = _filteredParcels;

    return Column(
      children: [
        _DriverTabHeader(
          title: 'Colis à prendre',
          subtitle:
              '${widget.parcelState.freeParcels.length} opportunité(s) disponibles',
          icon: Icons.sell_rounded,
          actionIcon: Icons.refresh_rounded,
          onAction: widget.onRefresh,
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              return _DriverFilterChip(
                label: filter,
                selected: _selectedFilter == filter,
                onTap: () => setState(() => _selectedFilter = filter),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: _PublishTripShortcut(onTap: widget.onPublishTrip),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: _refresh,
            child: widget.parcelState.isLoadingFreeParcels
                ? const Center(child: CircularProgressIndicator())
                : parcels.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(24, 90, 24, 120),
                        children: const [
                          PcEmptyState(
                            icon: Icons.inventory_2_rounded,
                            title: 'Aucun colis à prendre',
                            message:
                                'Les demandes clients en libre service apparaîtront ici.',
                            tone: PcTone.amber,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                        itemCount: parcels.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final parcel = parcels[index];
                          return _DriverRouteCard(
                            parcel: parcel,
                            footerText: _poolFooter(parcel),
                            primaryActionLabel: 'Faire une offre',
                            primaryActionIcon: Icons.gavel_rounded,
                            onPrimaryAction: () => _openOffer(parcel),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

// ==================== TAB MISSIONS ====================

class _DriverMissionsTabScreen extends StatefulWidget {
  final ParcelState parcelState;
  final VoidCallback onRefresh;

  const _DriverMissionsTabScreen({
    required this.parcelState,
    required this.onRefresh,
  });

  @override
  State<_DriverMissionsTabScreen> createState() =>
      _DriverMissionsTabScreenState();
}

class _DriverMissionsTabScreenState extends State<_DriverMissionsTabScreen> {
  int _tabIndex = 0;
  final ApiService _api = ApiService();
  String? _advancingId;

  Future<void> _advanceMission(Parcel mission, String step) async {
    setState(() => _advancingId = mission.id);
    try {
      final res = await _api.advanceParcel(mission.id, step);
      if (res['success'] == false) {
        _snack(res['message']?.toString() ?? 'Action impossible');
      } else {
        widget.onRefresh();
      }
    } catch (_) {
      _snack('Action impossible');
    } finally {
      if (mounted) setState(() => _advancingId = null);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<Parcel> get _activeMissions => widget.parcelState.parcels
      .where((parcel) =>
          parcel.status == ParcelStatus.pending ||
          parcel.status == ParcelStatus.confirmed ||
          parcel.status.isInProgress)
      .toList();

  List<Parcel> get _completedMissions => widget.parcelState.parcels
      .where((parcel) => parcel.status == ParcelStatus.delivered)
      .toList();

  List<Parcel> get _visibleMissions =>
      _tabIndex == 0 ? _activeMissions : _completedMissions;

  Future<void> _refresh() async => widget.onRefresh();

  void _openMission(Parcel parcel) {
    context
        .push('/parcel/${parcel.id}', extra: parcel)
        .then((_) => widget.onRefresh());
  }

  void _openConfirmDelivery(Parcel parcel) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmDeliveryScreen(parcel: parcel),
      ),
    ).then((updated) {
      if (updated == true) widget.onRefresh();
    });
  }

  Widget _buildMissionFooter(Parcel mission) {
    final commissionEstimate =
        mission.price != null ? CommissionService.calculate(mission.price!) : 0;
    final commissionLabel =
        mission.status.isCompleted ? 'Commission: ${commissionEstimate.toStringAsFixed(0)} FCFA' : 'Commission est.: ${commissionEstimate.toStringAsFixed(0)} FCFA';
    final client =
        mission.senderName.isNotEmpty ? mission.senderName : 'Client SendProcolis';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              commissionLabel,
              style: AppTheme.mono(
                color: AppTheme.slate500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                'Client · $client',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (_driverNextStep(mission.status) != null) ...[
          const SizedBox(height: 10),
          Builder(builder: (_) {
            final next = _driverNextStep(mission.status)!;
            final loading = _advancingId == mission.id;
            return PcButton(
              next.label,
              icon: next.icon,
              block: true,
              loading: loading,
              onPressed: loading
                  ? null
                  : () => next.step == 'deliver'
                      ? _openConfirmDelivery(mission)
                      : _advanceMission(mission, next.step),
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final missions = _visibleMissions;

    return Column(
      children: [
        _DriverTabHeader(
          title: 'Mes missions',
          subtitle:
              '${_activeMissions.length} active(s) · ${_completedMissions.length} terminée(s)',
          icon: Icons.local_shipping_rounded,
          actionIcon: Icons.refresh_rounded,
          onAction: widget.onRefresh,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: Row(
              children: [
                _DriverSegmentButton(
                  label: 'Actives',
                  count: _activeMissions.length,
                  selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                _DriverSegmentButton(
                  label: 'Terminées',
                  count: _completedMissions.length,
                  selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: _refresh,
            child: widget.parcelState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : missions.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(24, 90, 24, 120),
                        children: [
                          PcEmptyState(
                            icon: _tabIndex == 0
                                ? Icons.route_rounded
                                : Icons.task_alt_rounded,
                            title: _tabIndex == 0
                                ? 'Aucune mission active'
                                : 'Aucune mission terminée',
                            message: _tabIndex == 0
                                ? 'Acceptez un colis à prendre pour démarrer une mission.'
                                : 'Vos livraisons complétées seront visibles ici.',
                            tone: _tabIndex == 0
                                ? PcTone.primary
                                : PcTone.green,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                        itemCount: missions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final mission = missions[index];
                          return _DriverRouteCard(
                            parcel: mission,
                            customFooter: _buildMissionFooter(mission),
                            showPrimaryAction: false,
                            primaryActionLabel: 'Voir la mission',
                            primaryActionIcon: Icons.arrow_forward_rounded,
                            onTap: () => _openMission(mission),
                            onPrimaryAction: () => _openMission(mission),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

// ==================== TAB PROFIL CHAUFFEUR ====================

class _DriverProfileTabScreen extends ConsumerWidget {
  final User? user;
  final int activeMissionsCount;

  const _DriverProfileTabScreen({
    required this.user,
    required this.activeMissionsCount,
  });

  int get _deliveries =>
      user?.completedDeliveries ?? user?.totalDeliveries ?? 0;

  double get _walletBalance => user?.walletBalance ?? 0;

  String get _rating =>
      (user?.rating ?? 4.9).toStringAsFixed(1).replaceAll('.', ',');

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = user?.fullName ?? 'Chauffeur';
    final status = user?.driverStatus ?? DriverStatus.available;
    final photoUrl = user?.profilePhoto;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Column(
      children: [
        _DriverTabHeader(
          title: 'Profil',
          subtitle: 'Compte chauffeur et préférences',
          icon: Icons.person_rounded,
          actionIcon: Icons.settings_rounded,
          onAction: () => _openSettings(context),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 104),
            children: [
              ProcolisCard(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: AppTheme.primaryLight,
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
                                  user?.initials ?? 'PC',
                                  style: const TextStyle(
                                    color: AppTheme.teal700,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: 6,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: status.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppTheme.amber500, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          _rating,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        Text(
                          '$_deliveries livraisons',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded,
                              color: AppTheme.primary, size: 17),
                          SizedBox(width: 6),
                          Text(
                            'Chauffeur vérifié',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DriverProfileStat(
                      icon: Icons.account_balance_wallet_rounded,
                      value: '${_walletBalance.toStringAsFixed(0)} FCFA',
                      label: 'Solde',
                      tone: AppTheme.amber500,
                      background: AppTheme.amber50,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DriverProfileStat(
                      icon: Icons.local_shipping_rounded,
                      value: '$activeMissionsCount',
                      label: 'En cours',
                      tone: AppTheme.primary,
                      background: AppTheme.primaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ProcolisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _DriverProfileRow(
                      icon: Icons.garage_rounded,
                      title: 'Ma zone',
                      subtitle: user?.garageName ?? 'Zone non renseignée',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const DriverGarageScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.directions_car_rounded,
                      title: 'Véhicule',
                      subtitle:
                          '${user?.vehicleModel ?? 'Véhicule'} · ${user?.vehiclePlate ?? 'Plaque non renseignée'}',
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.description_rounded,
                      title: 'Documents & permis',
                      subtitle: 'À jour',
                      trailing: const Icon(Icons.verified_rounded,
                          color: AppTheme.successColor),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.payments_rounded,
                      title: 'Revenus',
                      subtitle: 'Gains et historique des paiements',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DriverRevenusScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Portefeuille & crédits',
                      subtitle: 'Solde FCFA et recharge',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DriverPointsScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.campaign_rounded,
                      title: 'Mes annonces',
                      subtitle: 'Gérer mes trajets publiés',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DriverMesAnnoncesScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.badge_rounded,
                      title: 'Documents & véhicule',
                      subtitle: 'Photos et papiers du véhicule',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const VehicleDocumentsScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.forum_rounded,
                      title: 'Messages',
                      subtitle: 'Discussions avec les clients',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const MessagesScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.history_rounded,
                      title: 'Historique',
                      subtitle: 'Courses terminées et annulées',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const DriverHistoriqueScreen())),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ProcolisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _DriverProfileRow(
                      icon: Icons.settings_rounded,
                      title: 'Paramètres véhicule & PIN',
                      subtitle: 'Véhicule, sécurité',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DriverParametresScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.help_rounded,
                      title: 'Aide & support',
                      subtitle: 'Centre d’assistance chauffeur',
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.logout_rounded,
                      title: 'Se déconnecter',
                      subtitle: 'Quitter la session',
                      destructive: true,
                      trailing: const SizedBox.shrink(),
                      onTap: () => _logout(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'SENDPROCOLIS · Chauffeur',
                  style: AppTheme.mono(
                    fontSize: 12,
                    color: AppTheme.slate400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverTabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _DriverTabHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
              ),
              IconButton(
                onPressed: onAction,
                icon: Icon(actionIcon, color: AppTheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DriverFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.cardColor,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textSecondary,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? AppTheme.primary : AppTheme.slate200,
        ),
      ),
    );
  }
}

class _DriverSegmentButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _DriverSegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Text(
            '$label ($count)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverProfileStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color tone;
  final Color background;

  const _DriverProfileStat({
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: tone, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  const _DriverProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppTheme.red500 : AppTheme.textPrimary;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: destructive ? AppTheme.red50 : AppTheme.slate100,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            color: destructive ? AppTheme.red500 : AppTheme.slate600,
            size: 21,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: trailing ??
            const Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
      ),
    );
  }
}


