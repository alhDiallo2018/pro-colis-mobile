import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/providers/auth_provider.dart';
import 'package:procolis/providers/parcel_provider.dart';
import 'package:procolis/screens/parcel/new_parcel_screen.dart';
import 'package:procolis/screens/parcel/parcel_detail_screen.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:procolis/widgets/parcel_card.dart';

class AdvertisementsScreen extends ConsumerStatefulWidget {
  const AdvertisementsScreen({super.key});

  @override
  ConsumerState<AdvertisementsScreen> createState() => _AdvertisementsScreenState();
}

class _AdvertisementsScreenState extends ConsumerState<AdvertisementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';
  bool _isLoading = false;
  
  List<Parcel> _myAds = [];
  List<Parcel> _driverAds = [];
  
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdvertisements();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdvertisements() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await Future.microtask(() async {
        await ref.read(parcelProvider.notifier).loadFreeParcels();
      });
      
      final freeParcels = ref.read(parcelProvider).freeParcels;
      
      debugPrint('📦 Total colis en libre service: ${freeParcels.length}');
      
      _myAds = freeParcels.where((p) => 
        p.senderId == user.id || p.senderPhone == user.phone
      ).toList();
      
      _driverAds = freeParcels.where((p) => 
        p.senderId != user.id && 
        p.senderPhone != user.phone &&
        _isDriver(p)
      ).toList();
      
      debugPrint('✅ Mes annonces: ${_myAds.length}, Annonces chauffeurs: ${_driverAds.length}');
      
    } catch (e) {
      debugPrint('❌ Erreur chargement annonces: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isDriver(Parcel parcel) {
    return parcel.driverId != null || 
           parcel.driverName != null ||
           parcel.senderName.contains('Chauffeur') ||
           parcel.senderName.contains('Driver') ||
           parcel.senderName.contains('Chauffeuse');
  }

  List<Parcel> get _filteredAdvertisements {
    List<Parcel> ads = _tabController.index == 0 
        ? _myAds 
        : _driverAds;
    
    switch (_selectedFilter) {
      case 'active':
        return ads.where((p) => p.status == ParcelStatus.free || p.status == ParcelStatus.pending).toList();
      case 'with_bids':
        return ads.where((p) => p.hasBids).toList();
      case 'confirmed':
        return ads.where((p) => p.status == ParcelStatus.confirmed).toList();
      case 'delivered':
        return ads.where((p) => p.status == ParcelStatus.delivered).toList();
      default:
        return ads;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Annonces',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdvertisements,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
      body: Column(
        children: [
          // TabBar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppTheme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              onTap: (index) => setState(() {}),
              tabs: const [
                Tab(text: '📦 Mes annonces'),
                Tab(text: '🚚 Annonces chauffeurs'),
              ],
            ),
          ),
          
          // Filtres
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.textSecondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        icon: Icon(
                          Icons.filter_list,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('📋 Toutes')),
                          const DropdownMenuItem(value: 'active', child: Text('🔄 Actives')),
                          const DropdownMenuItem(value: 'with_bids', child: Text('💰 Avec offres')),
                          const DropdownMenuItem(value: 'confirmed', child: Text('✅ Confirmées')),
                          const DropdownMenuItem(value: 'delivered', child: Text('🎉 Livrées')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Contenu
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _createNewAd,
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              tooltip: 'Nouvelle annonce',
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
        ),
      );
    }

    final advertisements = _filteredAdvertisements;
    
    if (advertisements.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadAdvertisements,
      color: AppTheme.primaryBlue,
      backgroundColor: AppTheme.cardColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: advertisements.length,
        itemBuilder: (context, index) {
          final parcel = advertisements[index];
          final isMine = _tabController.index == 0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildParcelCard(parcel, isMine),
          );
        },
      ),
    );
  }

  Widget _buildParcelCard(Parcel parcel, bool isMine) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carte de colis
          ParcelCard(
            parcel: parcel,
            onTap: () => _navigateToParcelDetail(parcel),
          ),
          
          // Actions pour mes annonces
          if (isMine) ...[
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Statistiques des offres
                  if (parcel.hasBids)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.gavel_rounded,
                            size: 16,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${parcel.bids.length} offre${parcel.bids.length > 1 ? 's' : ''} reçue${parcel.bids.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Boutons d'action
                  Row(
                    children: [
                      // Voir les offres
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: parcel.hasBids ? () => _showBidsDialog(parcel) : null,
                          icon: Icon(
                            Icons.visibility_outlined,
                            size: 18,
                            color: parcel.hasBids ? AppTheme.primaryBlue : Colors.grey.shade400,
                          ),
                          label: Text(
                            'Voir les offres',
                            style: TextStyle(
                              color: parcel.hasBids ? AppTheme.primaryBlue : Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: parcel.hasBids 
                                  ? AppTheme.primaryBlue 
                                  : Colors.grey.shade300,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Modifier
                      if (parcel.isPending || parcel.isFree)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _editAd(parcel),
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                            label: Text(
                              'Modifier',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      
                      const SizedBox(width: 8),
                      
                      // Supprimer
                      if (parcel.isPending || parcel.isFree)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteAd(parcel),
                            icon: const Icon(
                              Icons.delete_outlined,
                              size: 18,
                              color: AppTheme.errorColor,
                            ),
                            label: Text(
                              'Supprimer',
                              style: TextStyle(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isMyAds = _tabController.index == 0;
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMyAds 
                    ? Icons.ads_click_rounded 
                    : Icons.local_shipping_rounded,
                size: 64,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isMyAds 
                  ? 'Aucune annonce créée' 
                  : 'Aucune annonce de chauffeur',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isMyAds 
                  ? 'Publiez un colis en mode libre service\npour recevoir des offres de chauffeurs' 
                  : 'Les chauffeurs n\'ont pas encore publié d\'annonces',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (isMyAds) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _createNewAd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Créer une annonce',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _createNewAd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewParcelScreen(),
      ),
    ).then((result) {
      if (result == true) {
        _loadAdvertisements();
      }
    });
  }

  void _editAd(Parcel parcel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParcelDetailScreen(parcel: parcel),
      ),
    ).then((result) {
      if (result == true) {
        _loadAdvertisements();
      }
    });
  }

  Future<void> _deleteAd(Parcel parcel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Supprimer l\'annonce',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer l\'annonce "${parcel.description}" ?\n\n'
          '⚠️ Toutes les offres associées seront également supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final result = await _apiService.cancelParcel(parcel.id);
        
        if (result['success'] == true) {
          await _loadAdvertisements();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Annonce supprimée avec succès'),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        } else {
          throw Exception(result['message'] ?? 'Erreur lors de la suppression');
        }
      } catch (e) {
        debugPrint('❌ Erreur lors de la suppression: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: $e'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _navigateToParcelDetail(Parcel parcel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParcelDetailScreen(parcel: parcel),
      ),
    );
  }

  void _showBidsDialog(Parcel parcel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _BidsBottomSheet(parcel: parcel),
    );
  }
}

// ==================== BOTTOM SHEET DES OFFRES ====================

class _BidsBottomSheet extends StatefulWidget {
  final Parcel parcel;

  const _BidsBottomSheet({required this.parcel});

  @override
  State<_BidsBottomSheet> createState() => _BidsBottomSheetState();
}

class _BidsBottomSheetState extends State<_BidsBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Titre
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Offres reçues',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.parcel.bids.length} offre${widget.parcel.bids.length > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Liste des offres
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.parcel.bids.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bid = widget.parcel.bids[index];
                return _buildBidTile(bid);
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bouton fermer
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: AppTheme.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              child: const Text('Fermer'),
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBidTile(Bid bid) {
    final isSelected = widget.parcel.selectedBidId == bid.id;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected 
            ? AppTheme.successColor.withValues(alpha: 0.08) 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected 
            ? Border.all(color: AppTheme.successColor, width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
            child: Text(
              bid.driverName.isNotEmpty ? bid.driverName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bid.driverName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '✅ Acceptée',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '💰 ${bid.price.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (bid.message != null && bid.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bid.message!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${bid.formattedDate}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bid.status.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: bid.status.color.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              bid.status.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: bid.status.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}