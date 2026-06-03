// mobile/lib/screens/parcel/parcel_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/screens/profile/profile_screen.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/widgets/video_player_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/status_timeline.dart';
import '../dashboard/client_dashboard.dart';
import '../dashboard/driver_dashboard.dart';
import '../dashboard/garage_admin_dashboard.dart';
import '../dashboard/super_admin_dashboard.dart';

class ParcelDetailScreen extends ConsumerStatefulWidget {
  final Parcel parcel;

  const ParcelDetailScreen({super.key, required this.parcel});

  @override
  ConsumerState<ParcelDetailScreen> createState() => _ParcelDetailScreenState();
}

class _ParcelDetailScreenState extends ConsumerState<ParcelDetailScreen> {
  final ApiService _apiService = ApiService();
  List<ParcelEvent> _events = [];
  bool _isLoadingEvents = true;
  bool _isLoadingParcel = true;
  bool _isUpdating = false;
  late Parcel _parcel;
  String _errorMessage = '';

  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  final Map<String, bool> _expandedSections = {
    'info': true,
    'status': true,
    'timeline': true,
    'photos': false,
    'videos': false,
    'financial': false,
    'shipping': false,
  };

  @override
  void initState() {
    super.initState();
    _parcel = widget.parcel;
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingParcel = true;
      _errorMessage = '';
    });
    await Future.wait([
      _loadParcelDetails(),
      _loadEvents(),
    ]);
    if (mounted) {
      setState(() => _isLoadingParcel = false);
    }
  }

  Future<void> _loadParcelDetails() async {
    try {
      final updatedParcel = await _apiService.getParcelById(_parcel.id);
      if (updatedParcel != null && mounted) {
        setState(() => _parcel = updatedParcel);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement détails: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Impossible de charger les détails du colis');
      }
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoadingEvents = true);
    try {
      final events = await _apiService.getParcelEvents(_parcel.id);
      if (mounted) {
        setState(() {
          _events = events;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement événements: $e');
      if (mounted) {
        setState(() {
          _events = [];
          _isLoadingEvents = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final updatedParcel = await _apiService.updateParcelStatus(
        _parcel.id,
        newStatus,
      );
      if (mounted) {
        setState(() => _parcel = updatedParcel);
        _showSnackbar('Statut mis à jour avec succès', isError: false);
        await _loadEvents();
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Erreur: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleSection(String key) {
    setState(() {
      _expandedSections[key] = !(_expandedSections[key] ?? false);
    });
  }

  void _navigateToDashboard() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    
    if (user == null) {
      Navigator.pop(context);
      return;
    }
    
    Widget dashboard;
    switch (user.role) {
      case UserRole.client:
        dashboard = const ClientDashboard();
        break;
      case UserRole.driver:
        dashboard = const DriverDashboard();
        break;
      case UserRole.admin:
        dashboard = const GarageAdminDashboard();
        break;
      case UserRole.superAdmin:
        dashboard = const SuperAdminDashboard();
        break;
    }
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => dashboard),
    );
  }

  int _getCurrentIndex(User? user) {
    if (user == null) return 0;
    switch (user.role) {
      case UserRole.client:
        return 2;
      case UserRole.driver:
        return 0;
      case UserRole.admin:
        return 1;
      case UserRole.superAdmin:
        return 0;
    }
  }

  List<BottomNavigationBarItem> _getNavBarItems(User? user) {
    if (user == null) return [];
    
    switch (user.role) {
      case UserRole.client:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Mes colis'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Envoyer'),
          BottomNavigationBarItem(icon: Icon(Icons.track_changes), label: 'Suivre'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ];
      case UserRole.driver:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Mes colis'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Envoyer'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ];
      case UserRole.admin:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Tableau de bord'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Colis'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Chauffeurs'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ];
      case UserRole.superAdmin:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Tableau de bord'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Utilisateurs'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Colis'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ];
    }
  }

  void _onNavBarTap(int index, User? user) {
  if (user == null) return;
  
  switch (user.role) {
    case UserRole.client:
      switch (index) {
        case 0: // Mes colis
          _navigateToDashboard();
          break;
        case 1: // Envoyer
          Navigator.pop(context);
          break;
        case 2: // Suivre
          break;
        case 3: // Profil
          _navigateToProfile();
          break;
      }
      break;
      
    case UserRole.driver:
      switch (index) {
        case 0: // Mes colis
          _navigateToDashboard();
          break;
        case 1: // Envoyer
          Navigator.pop(context);
          break;
        case 2: // Profil
          _navigateToProfile();
          break;
      }
      break;
      
    case UserRole.admin:
      switch (index) {
        case 0: // Tableau de bord
          _navigateToDashboard();
          break;
        case 1: // Colis
          break;
        case 2: // Chauffeurs
          break;
        case 3: // Profil
          _navigateToProfile();
          break;
      }
      break;
      
    case UserRole.superAdmin:
      switch (index) {
        case 0: // Tableau de bord
          _navigateToDashboard();
          break;
        case 1: // Utilisateurs
          break;
        case 2: // Colis
          break;
        case 3: // Profil
          _navigateToProfile();
          break;
      }
      break;
  }
}

void _navigateToProfile() {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ProfileScreen()),
  );
}

  // ==================== FONCTIONS D'APPEL ====================

  Future<void> _makePhoneCall(String phoneNumber, String name) async {
    if (phoneNumber.isEmpty) {
      _showSnackbar('Numéro de téléphone non disponible', isError: true);
      return;
    }
    
    String formattedNumber = phoneNumber;
    if (!phoneNumber.startsWith('+') && !phoneNumber.startsWith('00')) {
      if (phoneNumber.startsWith('77') || 
          phoneNumber.startsWith('78') || 
          phoneNumber.startsWith('76') || 
          phoneNumber.startsWith('70')) {
        formattedNumber = '+221$phoneNumber';
      }
    }
    
    final Uri phoneUri = Uri(scheme: 'tel', path: formattedNumber);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        final result = await launchUrl(phoneUri);
        if (!result && mounted) {
          _showSnackbar('Impossible de passer l\'appel', isError: true);
        }
      } else {
        if (mounted) {
          _showSnackbar('Votre appareil ne supporte pas les appels', isError: true);
        }
      }
    } catch (e) {
      debugPrint('Erreur appel: $e');
      if (mounted) {
        _showSnackbar('Erreur lors de l\'appel', isError: true);
      }
    }
  }

  void _showCallOptions() {
    final authState = ref.read(authProvider);
    final currentUser = authState.user;
    final isDriver = currentUser?.isDriver ?? false;
    final currentDriverId = currentUser?.id;
    
    final isCurrentDriver = isDriver && currentDriverId == _parcel.driverId;
    
    final hasSenderPhone = _parcel.senderPhone.isNotEmpty;
    final hasReceiverPhone = _parcel.receiverPhone.isNotEmpty;
    final hasDriverPhone = _parcel.driverPhone != null && _parcel.driverPhone!.isNotEmpty && !isCurrentDriver;
    
    if (!hasSenderPhone && !hasReceiverPhone && !hasDriverPhone) {
      _showSnackbar('Aucun contact disponible', isError: true);
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Contacter',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const Divider(),
            if (hasSenderPhone)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF0B6E3A),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: const Text('Expéditeur'),
                subtitle: Text(_parcel.senderName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_parcel.senderPhone),
                    const SizedBox(width: 8),
                    const Icon(Icons.phone, color: Colors.green),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  _makePhoneCall(_parcel.senderPhone, _parcel.senderName);
                },
              ),
            if (hasReceiverPhone)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF0B6E3A),
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                title: const Text('Destinataire'),
                subtitle: Text(_parcel.receiverName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_parcel.receiverPhone),
                    const SizedBox(width: 8),
                    const Icon(Icons.phone, color: Colors.green),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  _makePhoneCall(_parcel.receiverPhone, _parcel.receiverName);
                },
              ),
            if (hasDriverPhone)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF0B6E3A),
                  child: Icon(Icons.delivery_dining, color: Colors.white),
                ),
                title: const Text('Chauffeur'),
                subtitle: Text(_parcel.driverName ?? 'Chauffeur'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_parcel.driverPhone!),
                    const SizedBox(width: 8),
                    const Icon(Icons.phone, color: Colors.green),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  _makePhoneCall(_parcel.driverPhone!, _parcel.driverName ?? 'Chauffeur');
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isDriver = user?.isDriver ?? false;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _isLoadingParcel
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : _buildBody(isDriver, isAdmin),
      floatingActionButton: _buildFloatingActionButton(isDriver, isAdmin),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getCurrentIndex(user),
        onTap: (index) => _onNavBarTap(index, user),
        selectedItemColor: const Color(0xFF0B6E3A),
        unselectedItemColor: Colors.grey,
        items: _getNavBarItems(user),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _parcel.trackingNumber,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            _parcel.status.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0B6E3A),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _navigateToDashboard,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Actualiser',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'share':
                _shareTrackingNumber();
                break;
              case 'report':
                _showReportDialog();
                break;
              case 'help':
                _showHelpDialog();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 20),
                  SizedBox(width: 12),
                  Text('Partager le suivi'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag, size: 20),
                  SizedBox(width: 12),
                  Text('Signaler un problème'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'help',
              child: Row(
                children: [
                  Icon(Icons.help, size: 20),
                  SizedBox(width: 12),
                  Text('Aide'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B6E3A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDriver, bool isAdmin) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainStatusCard(),
          const SizedBox(height: 16),
          
          if ((isDriver || isAdmin) && !_parcel.isFinished) _buildQuickActionsRow(),
          const SizedBox(height: 16),
          
          _buildCollapsibleSection(
            key: 'info',
            title: 'Informations du colis',
            icon: Icons.info_outline,
            child: _buildInfoContent(),
          ),
          const SizedBox(height: 12),
          
          _buildCollapsibleSection(
            key: 'shipping',
            title: 'Lieu de départ et livraison',
            icon: Icons.route,
            child: _buildShippingContent(),
          ),
          const SizedBox(height: 12),
          
          if (_parcel.price != null || _parcel.isUrgent || _parcel.isInsured)
            _buildCollapsibleSection(
              key: 'financial',
              title: 'Informations financières',
              icon: Icons.attach_money,
              child: _buildFinancialContent(),
            ),
          const SizedBox(height: 12),
          
          if (_parcel.photoUrls.isNotEmpty)
            _buildCollapsibleSection(
              key: 'photos',
              title: 'Photos (${_parcel.photoUrls.length})',
              icon: Icons.photo_library,
              child: _buildPhotosContent(),
            ),
          const SizedBox(height: 12),
          
          if (_parcel.videoUrls.isNotEmpty)
            _buildCollapsibleSection(
              key: 'videos',
              title: 'Vidéos (${_parcel.videoUrls.length})',
              icon: Icons.video_library,
              child: _buildVideosContent(),
            ),
          const SizedBox(height: 12),
          
          _buildCollapsibleSection(
            key: 'timeline',
            title: 'Historique',
            icon: Icons.history,
            child: _buildTimelineContent(),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String key,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isExpanded = _expandedSections[key] ?? false;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B6E3A).withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF0B6E3A), size: 20),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey,
            ),
            onTap: () => _toggleSection(key),
          ),
          if (isExpanded) Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildMainStatusCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_parcel.status.color, _parcel.status.color.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _parcel.status.color.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _parcel.statusIcon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _parcel.status.label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusDescription(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_parcel.estimatedDeliveryDate != null) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.white.withAlpha(50)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Livraison estimée: ${_formatDate(_parcel.estimatedDeliveryDate!)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusDescription() {
    switch (_parcel.status) {
      case ParcelStatus.pending:
        return 'Votre colis est en attente de traitement';
      case ParcelStatus.confirmed:
        return 'Votre colis a été confirmé';
      case ParcelStatus.pickedUp:
        return 'Votre colis a été ramassé';
      case ParcelStatus.inTransit:
        return 'Votre colis est en route vers sa destination';
      case ParcelStatus.arrived:
        return 'Votre colis est arrivé au lieu de livraison';
      case ParcelStatus.outForDelivery:
        return 'Votre colis est en cours de livraison';
      case ParcelStatus.delivered:
        return 'Votre colis a été livré avec succès';
      case ParcelStatus.cancelled:
        return 'Votre colis a été annulé';
    }
  }

  Widget _buildQuickActionsRow() {
    final actions = <Widget>[];
    
    if (_parcel.status == ParcelStatus.pending || _parcel.status == ParcelStatus.confirmed) {
      actions.add(_buildQuickActionChip('Accepter', Icons.check_circle, Colors.green, _acceptParcel));
    }
    if (_parcel.status == ParcelStatus.pickedUp) {
      actions.add(_buildQuickActionChip('En transit', Icons.directions_car, Colors.blue, () => _updateStatus('in_transit')));
    }
    if (_parcel.status == ParcelStatus.inTransit) {
      actions.add(_buildQuickActionChip('Arrivé', Icons.location_on, Colors.orange, () => _updateStatus('arrived')));
    }
    if (_parcel.status == ParcelStatus.arrived) {
      actions.add(_buildQuickActionChip('En livraison', Icons.delivery_dining, Colors.purple, () => _updateStatus('out_for_delivery')));
    }
    if (_parcel.status == ParcelStatus.outForDelivery) {
      actions.add(_buildQuickActionChip('Livré', Icons.check_circle, Colors.green, _confirmDelivery));
    }
    actions.add(_buildQuickActionChip('Contacter', Icons.phone, Colors.orange, _showCallOptions));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: actions),
    );
  }

  Widget _buildQuickActionChip(String label, IconData icon, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        avatar: Icon(icon, size: 16, color: Colors.white),
        onPressed: _isUpdating ? null : onPressed,
        backgroundColor: color,
        labelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildInfoContent() {
    return Column(
      children: [
        _buildInfoTile(Icons.person, 'Expéditeur', _parcel.senderName),
        _buildInfoTile(Icons.phone, 'Téléphone expéditeur', _parcel.senderPhone),
        const SizedBox(height: 12),
        _buildInfoTile(Icons.person_outline, 'Destinataire', _parcel.receiverName),
        _buildInfoTile(Icons.phone, 'Téléphone destinataire', _parcel.receiverPhone),
        if (_parcel.receiverEmail != null)
          _buildInfoTile(Icons.email, 'Email destinataire', _parcel.receiverEmail!),
        if (_parcel.receiverAddress != null)
          _buildInfoTile(Icons.location_on, 'Adresse de livraison', _parcel.receiverAddress!),
        const SizedBox(height: 12),
        _buildInfoTile(Icons.description, 'Description', _parcel.description),
        _buildInfoTile(Icons.fitness_center, 'Poids', '${_parcel.weight} kg'),
        _buildInfoTile(Icons.category, 'Type', _parcel.type.label),
        if (_parcel.notes != null)
          _buildInfoTile(Icons.note, 'Notes', _parcel.notes!, isLongText: true),
      ],
    );
  }

  Widget _buildShippingContent() {
    return Column(
      children: [
        _buildInfoTile(Icons.departure_board, 'Lieu de départ', _parcel.departureGarageName),
        if (_parcel.arrivalGarageName != null)
          _buildInfoTile(Icons.location_on, 'Lieu de livraison', _parcel.arrivalGarageName!),
        const SizedBox(height: 12),
        _buildInfoTile(Icons.create, 'Création', _formatDate(_parcel.createdAt)),
        if (_parcel.pickupDate != null)
          _buildInfoTile(Icons.inventory, 'Ramassage', _formatDate(_parcel.pickupDate!)),
        if (_parcel.deliveryDate != null)
          _buildInfoTile(Icons.check_circle, 'Livraison', _formatDate(_parcel.deliveryDate!)),
        if (_parcel.hasDriver) ...[
          const Divider(),
          _buildInfoTile(Icons.delivery_dining, 'Chauffeur', _parcel.driverName ?? 'Non assigné'),
          if (_parcel.driverPhone != null)
            _buildInfoTile(Icons.phone, 'Téléphone chauffeur', _parcel.driverPhone!),
        ],
      ],
    );
  }

  Widget _buildFinancialContent() {
    return Column(
      children: [
        if (_parcel.price != null)
          _buildInfoTile(Icons.attach_money, 'Prix', _parcel.formattedPrice, isHighlighted: true),
        if (_parcel.isUrgent && _parcel.urgentFee != null)
          _buildInfoTile(Icons.flash_on, 'Frais urgent', '${_parcel.urgentFee!.toInt()} FCFA', isHighlighted: true),
        if (_parcel.isInsured && _parcel.insuranceAmount != null)
          _buildInfoTile(Icons.shield, 'Assurance', '${_parcel.insuranceAmount!.toInt()} FCFA'),
        if (_parcel.totalAmount != null)
          _buildInfoTile(Icons.receipt, 'Total', _parcel.formattedTotal, isHighlighted: true),
        const Divider(),
        _buildInfoTile(Icons.payment, 'Mode de paiement', _getPaymentMethodLabel(_parcel.paymentMethod)),
        _buildInfoTile(Icons.receipt, 'Statut paiement', _getPaymentStatusLabel(_parcel.paymentStatus)),
      ],
    );
  }

  Widget _buildPhotosContent() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _parcel.photoUrls.length,
        itemBuilder: (context, index) {
          return _buildMediaThumbnail(_parcel.photoUrls[index], isVideo: false);
        },
      ),
    );
  }

  Widget _buildVideosContent() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _parcel.videoUrls.length,
        itemBuilder: (context, index) {
          return _buildMediaThumbnail(_parcel.videoUrls[index], isVideo: true);
        },
      ),
    );
  }

  Widget _buildMediaThumbnail(String url, {required bool isVideo}) {
    final fullUrl = _getFullUrl(url);
    return GestureDetector(
      onTap: () => isVideo ? _showVideoDialog(fullUrl) : _showPhotoDialog(fullUrl),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[200],
          image: !isVideo && fullUrl.isNotEmpty
              ? DecorationImage(image: NetworkImage(fullUrl), fit: BoxFit.cover)
              : null,
        ),
        child: isVideo
            ? Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_filled, size: 40, color: Colors.white),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildTimelineContent() {
    if (_isLoadingEvents) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aucun événement disponible pour ce colis'),
        ),
      );
    }
    return StatusTimeline(events: _events);
  }

  Widget _buildInfoTile(IconData icon, String label, String? value, {bool isHighlighted = false, bool isLongText = false}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isHighlighted ? const Color(0xFF0B6E3A) : Colors.grey[500]),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted ? const Color(0xFF0B6E3A) : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton(bool isDriver, bool isAdmin) {
    if (!isDriver && !isAdmin) return null;
    if (_parcel.isFinished) return null;
    return FloatingActionButton.extended(
      onPressed: () => _showActionMenu(),
      icon: const Icon(Icons.build),
      label: const Text('Actions'),
      backgroundColor: const Color(0xFF0B6E3A),
    );
  }

  void _showActionMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Actions disponibles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const Divider(),
            if (_parcel.status == ParcelStatus.pending || _parcel.status == ParcelStatus.confirmed)
              _buildActionMenuItem('Accepter le colis', Icons.check_circle, Colors.green, _acceptParcel),
            if (_parcel.status == ParcelStatus.pickedUp)
              _buildActionMenuItem('Démarrer le transport', Icons.directions_car, Colors.blue, () => _updateStatus('in_transit')),
            if (_parcel.status == ParcelStatus.inTransit)
              _buildActionMenuItem('Arrivé au lieu de livraison', Icons.location_on, Colors.orange, () => _updateStatus('arrived')),
            if (_parcel.status == ParcelStatus.arrived)
              _buildActionMenuItem('Partir en livraison', Icons.delivery_dining, Colors.purple, () => _updateStatus('out_for_delivery')),
            if (_parcel.status == ParcelStatus.outForDelivery)
              _buildActionMenuItem('Confirmer livraison', Icons.check_circle, Colors.green, _confirmDelivery),
            _buildActionMenuItem('Contacter', Icons.phone, Colors.blue, _showCallOptions),
            _buildActionMenuItem('Contacter le support', Icons.support_agent, Colors.orange, _contactSupport),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionMenuItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(25),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _acceptParcel() async {
    final confirmed = await _showConfirmationDialog('Accepter le colis', 'Voulez-vous accepter ce colis ?');
    if (confirmed == true) {
      await _updateStatus('picked_up');
    }
  }

  Future<void> _confirmDelivery() async {
    final confirmed = await _showConfirmationDialog('Confirmation de livraison', 'Confirmez-vous la livraison du colis ?');
    if (confirmed == true) {
      await _updateStatus('delivered');
    }
  }

  Future<bool?> _showConfirmationDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 9, 176, 243)),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Contacter le support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Color(0xFF0B6E3A)),
              title: const Text('Appeler'),
              subtitle: const Text('+221 33 123 45 67'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xFF0B6E3A)),
              title: const Text('Email'),
              subtitle: const Text('support@procolis.sn'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF0B6E3A)),
              title: const Text('WhatsApp'),
              subtitle: const Text('+221 77 123 45 67'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _shareTrackingNumber() {
    _showSnackbar('Fonctionnalité à venir');
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Signaler un problème'),
        content: const Text('Pour signaler un problème, contactez notre support au +221 33 123 45 67'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Aide'),
        content: const Text('Le numéro de suivi vous permet de suivre votre colis en temps réel.\n\nContactez notre support pour toute assistance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  void _showPhotoDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _showVideoDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.5,
            child: VideoPlayerWidget(videoUrl: url),
          ),
        ),
      ),
    );
  }

  String _getFullUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/uploads/')) {
      return 'https://procolis-backend.onrender.com$url';
    }
    return url;
  }

  String _getPaymentMethodLabel(dynamic method) {
    if (method == null) return 'Non spécifié';
    final methodStr = method.toString();
    switch (methodStr) {
      case 'cash':
        return 'Espèces';
      case 'wave':
        return 'Wave';
      case 'orange_money':
        return 'Orange Money';
      case 'free_money':
        return 'Free Money';
      case 'card':
        return 'Carte bancaire';
      default:
        return methodStr;
    }
  }

  String _getPaymentStatusLabel(dynamic status) {
    if (status == null) return 'Non spécifié';
    final statusStr = status.toString();
    switch (statusStr) {
      case 'pending':
        return 'En attente';
      case 'completed':
      case 'paid':
        return 'Payé';
      case 'failed':
        return 'Échoué';
      case 'cancelled':
        return 'Annulé';
      default:
        return statusStr;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Non défini';
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}