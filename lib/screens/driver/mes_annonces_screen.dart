// mobile/lib/screens/driver/mes_annonces_screen.dart
// Liste et gestion des annonces du chauffeur - aligné Web (MesAnnoncesScreen.tsx)

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/parcel.dart';
import '../../providers/advertisement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/negotiation_chat_widget.dart';
import '../../widgets/parcel_card.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/video_player_widget.dart';
import '../parcel/free_parcels_screen.dart';
import 'create_annonce_sheet.dart';

class DriverMesAnnoncesScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const DriverMesAnnoncesScreen({super.key, this.embedded = false});

  @override
  ConsumerState<DriverMesAnnoncesScreen> createState() =>
      _DriverMesAnnoncesScreenState();
}

class _DriverMesAnnoncesScreenState
    extends ConsumerState<DriverMesAnnoncesScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  /// Les annonces et leurs mutations vivent dans `advertisementProvider` : c'est
  /// lui qui recharge la liste après chaque écriture, plutôt que chaque action
  /// d'écran qui l'oublierait. `build` observe le provider, ces raccourcis en
  /// lisent l'état courant.
  List<Map<String, dynamic>> get _ads => ref.read(advertisementProvider).myAds;
  bool get _isLoading => ref.read(advertisementProvider).isLoading;

  String? _busyOfferId;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _loadAds();
    // Colis des clients (libre service) sur lesquels le chauffeur peut faire une offre
    Future.microtask(() => ref.read(parcelProvider.notifier).loadFreeParcels());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadColis() async {
    await ref.read(parcelProvider.notifier).loadFreeParcels();
  }

  void _openColis(parcel) {
    final authState = ref.read(authProvider);
    final currentUserId = authState.user?.id;

    final existingBid = currentUserId != null && parcel.bids is List
        ? (parcel.bids as List).cast<Bid?>().firstWhere(
              (b) => b?.driverId == currentUserId,
              orElse: () => null,
            )
        : null;

    if (existingBid != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NegotiationChatScreen(
            peerId: parcel.senderId,
            peerName: parcel.senderName,
            parcelId: parcel.id,
            bidId: existingBid.id,
            role: 'driver',
            onChanged: _loadColis,
          ),
        ),
      ).then((_) {
        if (mounted) _loadColis();
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => FreeParcelDetailsScreen(parcel: parcel)),
      ).then((_) {
        if (mounted) _loadColis();
      });
    }
  }

  Future<void> _loadAds() =>
      ref.read(advertisementProvider.notifier).loadMyAdvertisements();

  /// Affiche le message renvoyé par l'API. Les refus métier (annonce engagée,
  /// offre déjà acceptée) portent une explication précise qu'il ne faut pas
  /// remplacer par un texte générique.
  void _showResult(Map<String, dynamic> result, String successMessage) {
    if (!mounted) return;
    final succeeded = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(succeeded
            ? successMessage
            : result['message']?.toString() ?? 'Opération impossible'),
        backgroundColor: succeeded ? null : AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child:
                Text(confirmLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _createAd() async {
    // Le provider recharge déjà la liste après une création réussie.
    await showCreateAnnonceSheet(context);
  }

  Future<void> _editAd(Map<String, dynamic> ad) async {
    final saved = await showEditAnnonceSheet(context, ad);
    if (saved == true && mounted) {
      _showResult({'success': true}, 'Annonce modifiée');
    }
  }

  Future<void> _closeAd(String adId) async {
    final confirmed = await _confirm(
      title: 'Fermer l\'annonce ?',
      message: 'L\'annonce ne sera plus visible pour les clients et les offres '
          'encore en attente seront refusées.',
      confirmLabel: 'Fermer',
    );
    if (!confirmed) return;
    final result =
        await ref.read(advertisementProvider.notifier).closeAdvertisement(adId);
    _showResult(result, 'Annonce fermée');
  }

  /// Suppression définitive. L'API la refuse si une offre a été acceptée — son
  /// message invite alors à fermer l'annonce, ce qui préserve l'historique.
  Future<void> _deleteAd(String adId) async {
    final confirmed = await _confirm(
      title: 'Supprimer l\'annonce ?',
      message: 'L\'annonce et les offres reçues seront définitivement '
          'effacées. Pour garder la trace du trajet, fermez-la plutôt.',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed) return;
    final result =
        await ref.read(advertisementProvider.notifier).deleteAdvertisement(adId);
    _showResult(result, 'Annonce supprimée');
  }

  Future<void> _acceptOffer(String adId, String offerId) async {
    setState(() => _busyOfferId = offerId);
    try {
      final result =
          await ref.read(advertisementProvider.notifier).acceptOffer(adId, offerId);
      if (result['success'] == true) {
        ref.read(parcelProvider.notifier).loadDriverParcels();
      }
      _showResult(result, 'Offre acceptée');
    } finally {
      if (mounted) setState(() => _busyOfferId = null);
    }
  }

  Future<void> _rejectOffer(String adId, String offerId) async {
    setState(() => _busyOfferId = offerId);
    try {
      final result =
          await ref.read(advertisementProvider.notifier).rejectOffer(adId, offerId);
      _showResult(result, 'Offre refusée');
    } finally {
      if (mounted) setState(() => _busyOfferId = null);
    }
  }

  void _openChat(Map<String, dynamic> ad, Map<String, dynamic> offer) {
    final client = offer['client'] as Map<String, dynamic>?;
    final peerId = (offer['clientId'] ?? client?['id'])?.toString();
    final peerName = client?['fullName']?.toString() ?? 'Client';
    final adId = ad['id']?.toString();
    final offerId = offer['id']?.toString();

    String? parcelId = offer['parcelId']?.toString() ??
        (offer['parcel'] as Map<String, dynamic>?)?['id']?.toString();

    if (parcelId != null && parcelId.isNotEmpty && parcelId == adId) {
      parcelId = null;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NegotiationChatScreen(
          peerId: peerId ?? '',
          peerName: peerName,
          parcelId: parcelId,
          advertisementId: adId,
          offerId: offerId,
          role: 'driver',
          isOwner: true,
          onChanged: _loadAds,
        ),
      ),
    );
  }

  /// Affiche les infos du colis depuis l'offre correspondante.
  Future<void> _showParcelInfo(String adId, String offerId) async {
    try {
      final parcel = await _apiService.getParcelFromAdvertisement(
        adId,
        offerId: offerId,
      );

      if (!mounted) return;

      if (parcel != null) {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.cardColor,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
          ),
          builder: (ctx) => _ParcelSheet(parcel: parcel.toJson()),
        );
      } else {
        final detail = await _apiService.getAdvertisementDetail(adId);
        if (!mounted) return;
        final offers = detail['offers'] as List<dynamic>? ?? const [];
        final match = offers.firstWhere(
          (o) => (o as Map)['id']?.toString() == offerId,
          orElse: () => null,
        );
        final parcelData =
            (match is Map ? match['parcel'] : null) as Map<String, dynamic>?;
        if (parcelData != null) {
          showModalBottomSheet(
            context: context,
            backgroundColor: AppTheme.cardColor,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg)),
            ),
            builder: (ctx) => _ParcelSheet(parcel: parcelData),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun colis associé à cette offre'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observe le provider pour que la liste se redessine après chaque mutation
    // d'annonce ; les raccourcis `_ads` / `_isLoading` en relisent l'état.
    ref.watch(advertisementProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: widget.embedded ? null : const AppBottomNav(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header row : titre + bouton "Créer une annonce"
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
              child: Row(
                children: [
                  if (!widget.embedded) ...[
                    PcIconButton(
                      Icons.arrow_back_rounded,
                      variant: PcIconButtonVariant.soft,
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Retour',
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      'Mes annonces',
                      style: AppFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (_tabController.index == 0)
                    PcButton(
                      'Créer une annonce',
                      icon: Icons.add_rounded,
                      size: PcButtonSize.sm,
                      onPressed: _createAd,
                    ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              labelStyle: AppFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Voyages'),
                Tab(text: 'Colis à livrer'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAdsTab(),
                  _buildColisTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Onglet 1 : ses annonces de voyage
  Widget _buildAdsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadAds,
      child: _ads.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                PcEmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'Aucune annonce',
                  message: 'Vous n\'avez pas encore créé d\'annonce. '
                      'Publiez un trajet pour recevoir des offres de clients.',
                  action: PcButton(
                    'Créer une annonce',
                    icon: Icons.add_rounded,
                    size: PcButtonSize.sm,
                    onPressed: _createAd,
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _ads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _buildAdCard(_ads[index]),
            ),
    );
  }

  // Onglet 2 : annonces de colis des clients (libre service) à livrer
  Widget _buildColisTab() {
    final parcelState = ref.watch(parcelProvider);
    final colis = parcelState.freeParcels;
    if (parcelState.isLoadingFreeParcels && colis.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (colis.isEmpty && parcelState.error != null) {
      return RefreshIndicator(
        onRefresh: _loadColis,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            PcEmptyState(
              icon: Icons.wifi_off_rounded,
              tone: PcTone.amber,
              title: 'Impossible de charger les colis',
              message: 'Vérifiez votre connexion puis réessayez.',
              action: PcButton(
                'Réessayer',
                icon: Icons.refresh_rounded,
                size: PcButtonSize.sm,
                onPressed: _loadColis,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadColis,
      child: colis.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                PcEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Aucun colis disponible',
                  message: 'Aucune annonce de colis à livrer pour le moment. '
                      'Revenez plus tard pour faire une offre.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: colis.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final parcel = colis[index];
                return ParcelCard(
                  parcel: parcel,
                  onTap: () => _openColis(parcel),
                );
              },
            ),
    );
  }

  void _openAdDetail(Map<String, dynamic> ad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VoyageDetailScreen(
          ad: ad,
          onChat: (offer) => _openChat(ad, offer),
          onAccept: (offerId) =>
              _acceptOffer(ad['id']?.toString() ?? '', offerId),
          onReject: (offerId) =>
              _rejectOffer(ad['id']?.toString() ?? '', offerId),
          onShowParcel: (offerId) =>
              _showParcelInfo(ad['id']?.toString() ?? '', offerId),
          onRefresh: _loadAds,
          busyOfferId: _busyOfferId,
          onCloseAd: () => _closeAd(ad['id']?.toString() ?? ''),
        ),
      ),
    ).then((_) {
      if (mounted) _loadAds();
    });
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final departure = ad['departureCity']?.toString() ?? '—';
    final arrival = ad['arrivalCity']?.toString() ?? '—';
    final proposedPrice = ad['proposedPrice'];
    final weight = ad['availableWeight'];
    final status = ad['status']?.toString() ?? 'open';
    final description = ad['description']?.toString();
    final departureAt = ad['departureAt']?.toString();
    final offers = ad['offers'] as List<dynamic>? ?? const [];
    final adId = ad['id']?.toString() ?? '';
    final isOpen = status == 'open' || status == 'active';

    return PcCard(
      onTap: () => _openAdDetail(ad),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header : route + statut + contrôle de fermeture
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined,
                  size: 18, color: AppTheme.slate500),
              const SizedBox(width: 4),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    children: [
                      TextSpan(text: departure),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_right_alt_rounded,
                              size: 18, color: AppTheme.slate400),
                        ),
                      ),
                      TextSpan(text: arrival),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PcBadge(_adStatusLabel(status), tone: _adStatusTone(status)),
              const SizedBox(width: 4),
              // Modifier et fermer ne concernent qu'une annonce ouverte ; la
              // suppression reste offerte sur une annonce fermée pour faire le
              // ménage. L'API tranche dans tous les cas.
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    size: 20, color: AppTheme.slate500),
                tooltip: 'Actions',
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      _editAd(ad);
                    case 'close':
                      _closeAd(adId);
                    case 'delete':
                      _deleteAd(adId);
                  }
                },
                itemBuilder: (_) => [
                  if (isOpen)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_rounded, size: 20),
                        title: Text('Modifier'),
                      ),
                    ),
                  if (isOpen)
                    const PopupMenuItem(
                      value: 'close',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.event_busy_rounded, size: 20),
                        title: Text('Fermer'),
                      ),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline_rounded,
                          size: 20, color: AppTheme.error),
                      title: Text('Supprimer',
                          style: TextStyle(color: AppTheme.error)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ligne méta : poids / prix / départ
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              if (weight != null)
                _metaItem(
                  'Poids dispo',
                  Text('$weight kg',
                      style: AppTheme.mono(
                          fontSize: 13, color: AppTheme.textPrimary)),
                ),
              if (proposedPrice != null)
                _metaItem(
                  'Prix proposé',
                  Text(_fcfa(proposedPrice),
                      style: AppTheme.mono(
                          fontSize: 13, color: AppTheme.textPrimary)),
                )
              else
                _metaItem(
                  'Prix',
                  Text('À négocier',
                      style: AppFonts.manrope(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.slate400,
                      )),
                ),
              _metaItem(
                'Départ',
                Text(_formatDate(departureAt),
                    style: AppFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate700)),
              ),
            ],
          ),

          // Description
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: AppFonts.manrope(
                  fontSize: 13, color: AppTheme.slate700, height: 1.45),
            ),
          ],

          // Offres reçues
          const SizedBox(height: 14),
          const PcDivider(),
          const SizedBox(height: 12),
          if (offers.isNotEmpty) ...[
            Text(
              'Offres reçues (${offers.length})',
              style: AppFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            for (final o in offers)
              _buildOfferRow(adId, o as Map<String, dynamic>),
          ] else
            Text(
              'Aucune offre reçue pour cette annonce.',
              style: AppFonts.manrope(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppTheme.slate400,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfferRow(String adId, Map<String, dynamic> offer) {
    final client = offer['client'] as Map<String, dynamic>?;
    final clientName = client?['fullName']?.toString() ?? 'Client';
    final price = offer['price'];
    final status = offer['status']?.toString() ?? 'pending';
    final offerId = offer['id']?.toString() ?? '';
    final message = offer['message']?.toString();
    final parcel = offer['parcel'] as Map<String, dynamic>?;
    final tracking = parcel?['trackingNumber']?.toString();
    final isPending = status == 'pending';
    final busy = _busyOfferId == offerId;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.slate100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PcAvatar(clientName, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                    ),
                    if (tracking != null)
                      GestureDetector(
                        onTap: () => _showParcelInfo(adId, offerId),
                        child: Text(
                          tracking,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.mono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.teal600),
                        ),
                      )
                    else if (message != null && message.isNotEmpty)
                      Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.manrope(
                            fontSize: 11, color: AppTheme.slate500),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fcfa(price),
                style: AppTheme.mono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.teal600),
              ),
              const SizedBox(width: 8),
              PcBadge(_offerStatusLabel(status),
                  tone: _offerStatusTone(status)),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PcButton(
                    'Chat',
                    icon: Icons.forum_outlined,
                    variant: PcButtonVariant.secondary,
                    size: PcButtonSize.sm,
                    onPressed: () => _openChat(
                        _ads.firstWhere((a) => a['id']?.toString() == adId,
                            orElse: () => <String, dynamic>{}),
                        offer),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: PcButton(
                    'Refuser',
                    icon: Icons.close_rounded,
                    variant: PcButtonVariant.ghost,
                    size: PcButtonSize.sm,
                    loading: busy,
                    onPressed: busy ? null : () => _rejectOffer(adId, offerId),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: PcButton(
                    'Accepter',
                    icon: Icons.check_rounded,
                    size: PcButtonSize.sm,
                    loading: busy,
                    onPressed: busy ? null : () => _acceptOffer(adId, offerId),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaItem(String label, Widget value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate600),
        ),
        const SizedBox(height: 3),
        value,
      ],
    );
  }

  // --- Helpers d'affichage ---

  String _fcfa(dynamic value) {
    final n = (value is num) ? value : num.tryParse('$value') ?? 0;
    final s = n.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf FCFA';
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Flexible';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Flexible';
    return DateFormat('dd/MM/yyyy').format(dt.toLocal());
  }

  String _adStatusLabel(String status) {
    switch (status) {
      case 'closed':
        return 'Fermée';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Ouverte';
    }
  }

  PcTone _adStatusTone(String status) {
    switch (status) {
      case 'closed':
        return PcTone.red;
      case 'cancelled':
        return PcTone.amber;
      default:
        return PcTone.green;
    }
  }

  String _offerStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Acceptée';
      case 'rejected':
        return 'Refusée';
      default:
        return 'En attente';
    }
  }

  PcTone _offerStatusTone(String status) {
    switch (status) {
      case 'accepted':
        return PcTone.green;
      case 'rejected':
        return PcTone.red;
      default:
        return PcTone.amber;
    }
  }
}

/// Feuille de détails du colis lié à une offre (aligné Web : dialog colis).
class _ParcelSheet extends StatefulWidget {
  final Map<String, dynamic> parcel;
  const _ParcelSheet({required this.parcel});

  @override
  State<_ParcelSheet> createState() => _ParcelSheetState();
}

class _ParcelSheetState extends State<_ParcelSheet> {
  // Lecture des notes vocales attachées au colis.
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingAudioIndex;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingAudioIndex = null);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Résout une URL de média : les chemins relatifs `/uploads/...` sont
  /// préfixés avec le backend, comme dans le reste de l'application.
  String _mediaUrl(String url) =>
      url.startsWith('http') ? url : ApiService.resolveMediaUrl(url);

  List<String> _urlList(dynamic value) => value is List
      ? value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
      : const [];

  void _openPhotoViewer(String url) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Icon(Icons.broken_image_rounded,
                        color: Colors.white54, size: 48),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openVideo(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: VideoPlayerWidget(videoUrl: url),
      ),
    );
  }

  Future<void> _toggleParcelAudio(int index, String url) async {
    try {
      if (_playingAudioIndex == index) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playingAudioIndex = null);
        return;
      }
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      if (mounted) setState(() => _playingAudioIndex = index);
    } catch (_) {
      if (mounted) setState(() => _playingAudioIndex = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lecture audio impossible'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    final tracking = parcel['trackingNumber']?.toString();
    final description = parcel['description']?.toString();
    final weight = parcel['weight'];
    final type = parcel['type']?.toString();
    final status = parcel['status']?.toString();
    final receiverName = parcel['receiverName']?.toString();
    final receiverPhone = parcel['receiverPhone']?.toString();
    final receiverAddress = parcel['receiverAddress']?.toString();
    final photos = _urlList(parcel['photoUrls']);
    final videos = _urlList(parcel['videoUrls']);
    final audios = _urlList(parcel['audioUrls']);
    final hasMedia =
        photos.isNotEmpty || videos.isNotEmpty || audios.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tracking != null ? 'Colis — $tracking' : 'Colis',
                    style: AppFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (description != null && description.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.slate50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(description,
                    style: AppFonts.manrope(
                        fontSize: 13, color: AppTheme.slate700, height: 1.45)),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                if (weight != null) _kv('Poids', '$weight kg', mono: true),
                if (type != null) _kv('Type', type),
                if (status != null) _kv('Statut', status),
                if (receiverName != null) _kv('Destinataire', receiverName),
                if (receiverPhone != null)
                  _kv('Tél destinataire', receiverPhone, mono: true),
              ],
            ),
            if (receiverAddress != null) ...[
              const SizedBox(height: 12),
              _kv('Adresse', receiverAddress),
            ],
            if (hasMedia) ...[
              const SizedBox(height: 18),
              _buildMediaSection(photos, videos, audios),
            ],
            const SizedBox(height: 18),
            PcButton(
              'Fermer',
              variant: PcButtonVariant.secondary,
              block: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(
      List<String> photos, List<String> videos, List<String> audios) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MediaLabel(
              icon: Icons.attach_file_rounded, text: 'Pièces jointes'),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MediaLabel(
                icon: Icons.photo_library_rounded,
                text: 'Photos (${photos.length})'),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final url = _mediaUrl(photos[i]);
                  return GestureDetector(
                    onTap: () => _openPhotoViewer(url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: Image.network(
                        url,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: AppTheme.slate100,
                          child: Icon(Icons.broken_image_rounded,
                              color: AppTheme.slate400),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (videos.isNotEmpty) ...[
            if (photos.isNotEmpty) const SizedBox(height: 16),
            const SizedBox(height: 4),
            _MediaLabel(
                icon: Icons.videocam_rounded,
                text: 'Vidéos (${videos.length})'),
            const SizedBox(height: 10),
            for (var i = 0; i < videos.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _MediaTile(
                icon: Icons.play_circle_fill_rounded,
                label: 'Vidéo ${i + 1}',
                onTap: () => _openVideo(_mediaUrl(videos[i])),
              ),
            ],
          ],
          if (audios.isNotEmpty) ...[
            if (photos.isNotEmpty || videos.isNotEmpty)
              const SizedBox(height: 16),
            const SizedBox(height: 4),
            const _MediaLabel(
                icon: Icons.graphic_eq_rounded, text: 'Notes vocales'),
            const SizedBox(height: 10),
            for (var i = 0; i < audios.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _MediaTile(
                icon: _playingAudioIndex == i
                    ? Icons.stop_circle_rounded
                    : Icons.play_circle_fill_rounded,
                label: 'Note vocale ${i + 1}',
                onTap: () => _toggleParcelAudio(i, _mediaUrl(audios[i])),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {bool mono = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: AppFonts.manrope(fontSize: 12, color: AppTheme.slate500)),
        const SizedBox(height: 3),
        Text(
          value,
          style: mono
              ? AppTheme.mono(fontSize: 12, color: AppTheme.textPrimary)
              : AppFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
        ),
      ],
    );
  }
}

/// Libellé de section média (icône + titre) — aligné parcel_detail_screen.
class _MediaLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MediaLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Tuile média cliquable (vidéo / note vocale) — aligné parcel_detail_screen.
class _MediaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoyageDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ad;
  final void Function(Map<String, dynamic> offer) onChat;
  final void Function(String offerId) onAccept;
  final void Function(String offerId) onReject;
  final void Function(String offerId) onShowParcel;
  final VoidCallback onRefresh;
  final VoidCallback onCloseAd;
  final String? busyOfferId;

  const _VoyageDetailScreen({
    required this.ad,
    required this.onChat,
    required this.onAccept,
    required this.onReject,
    required this.onShowParcel,
    required this.onRefresh,
    required this.onCloseAd,
    this.busyOfferId,
  });

  @override
  State<_VoyageDetailScreen> createState() => _VoyageDetailScreenState();
}

class _VoyageDetailScreenState extends State<_VoyageDetailScreen> {
  String _fcfa(dynamic value) {
    final n = (value is num) ? value : num.tryParse('$value') ?? 0;
    final s = n.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf FCFA';
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Flexible';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Flexible';
    return DateFormat('dd/MM/yyyy').format(dt.toLocal());
  }

  String _offerStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Acceptée';
      case 'rejected':
        return 'Refusée';
      default:
        return 'En attente';
    }
  }

  PcTone _offerStatusTone(String status) {
    switch (status) {
      case 'accepted':
        return PcTone.green;
      case 'rejected':
        return PcTone.red;
      default:
        return PcTone.amber;
    }
  }

  String _adStatusLabel(String status) {
    switch (status) {
      case 'closed':
        return 'Fermée';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Ouverte';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final departure = ad['departureCity']?.toString() ?? '—';
    final arrival = ad['arrivalCity']?.toString() ?? '—';
    final proposedPrice = ad['proposedPrice'];
    final weight = ad['availableWeight'];
    final status = ad['status']?.toString() ?? 'open';
    final description = ad['description']?.toString();
    final departureAt = ad['departureAt']?.toString();
    final offers = ad['offers'] as List<dynamic>? ?? const [];
    final isOpen = status == 'open' || status == 'active';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
              child: Row(
                children: [
                  PcIconButton(
                    Icons.arrow_back_rounded,
                    variant: PcIconButtonVariant.soft,
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Retour',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Détail du voyage',
                      style: AppFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (isOpen)
                    PcButton(
                      'Fermer l\'annonce',
                      icon: Icons.close_rounded,
                      variant: PcButtonVariant.ghost,
                      size: PcButtonSize.sm,
                      onPressed: widget.onCloseAd,
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => widget.onRefresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 18, color: AppTheme.slate500),
                              const SizedBox(width: 6),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: AppFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                    children: [
                                      TextSpan(text: departure),
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6),
                                          child: Icon(
                                              Icons.arrow_right_alt_rounded,
                                              size: 22,
                                              color: AppTheme.slate400),
                                        ),
                                      ),
                                      TextSpan(text: arrival),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PcBadge(_adStatusLabel(status),
                                  tone: widget.ad['status'] == 'closed'
                                      ? PcTone.red
                                      : widget.ad['status'] == 'cancelled'
                                          ? PcTone.amber
                                          : PcTone.green),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 28,
                            runSpacing: 12,
                            children: [
                              if (weight != null)
                                _detailMeta('Poids dispo', '$weight kg'),
                              if (proposedPrice != null)
                                _detailMeta(
                                    'Prix proposé', _fcfa(proposedPrice))
                              else
                                _detailMeta('Prix', 'À négocier'),
                              _detailMeta('Départ', _formatDate(departureAt)),
                            ],
                          ),
                          if (description != null &&
                              description.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              description,
                              style: AppFonts.manrope(
                                  fontSize: 14,
                                  color: AppTheme.slate700,
                                  height: 1.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Icon(Icons.handshake_rounded,
                            size: 20, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Propositions des clients (${offers.length})',
                          style: AppFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (offers.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        alignment: Alignment.center,
                        child: Text(
                          'Aucune proposition reçue pour ce voyage.',
                          style: AppFonts.manrope(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.slate400,
                          ),
                        ),
                      )
                    else
                      ...offers.map((o) {
                        final offer = o as Map<String, dynamic>;
                        return _buildDetailOfferRow(offer);
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailMeta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate500),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTheme.mono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildDetailOfferRow(Map<String, dynamic> offer) {
    final client = offer['client'] as Map<String, dynamic>?;
    final clientName = client?['fullName']?.toString() ?? 'Client';
    final price = offer['price'];
    final status = offer['status']?.toString() ?? 'pending';
    final offerId = offer['id']?.toString() ?? '';
    final message = offer['message']?.toString();
    final parcel = offer['parcel'] as Map<String, dynamic>?;
    final tracking = parcel?['trackingNumber']?.toString();
    final parcelWeight = parcel?['weight'];
    final parcelReceiver = parcel?['receiverName']?.toString();
    final isPending = status == 'pending';
    final isMine = widget.busyOfferId == offerId;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isPending ? AppTheme.slate200 : AppTheme.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PcAvatar(clientName, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: AppFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                    ),
                    if (tracking != null ||
                        parcelWeight != null ||
                        parcelReceiver != null)
                      GestureDetector(
                        onTap: () => widget.onShowParcel(offerId),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 14,
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  [
                                    if (tracking != null) tracking,
                                    if (parcelWeight != null)
                                      '${parcelWeight}kg',
                                    if (parcelReceiver != null) parcelReceiver,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.mono(
                                      fontSize: 12,
                                      color: AppTheme.teal600,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fcfa(price),
                    style: AppTheme.mono(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.teal600),
                  ),
                  const SizedBox(height: 4),
                  PcBadge(_offerStatusLabel(status),
                      tone: _offerStatusTone(status)),
                ],
              ),
            ],
          ),
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                message,
                style: AppFonts.manrope(
                    fontSize: 13, color: AppTheme.slate700, height: 1.4),
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PcButton(
                    'Chat',
                    icon: Icons.forum_outlined,
                    variant: PcButtonVariant.secondary,
                    size: PcButtonSize.sm,
                    onPressed: () => widget.onChat(offer),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PcButton(
                    'Refuser',
                    icon: Icons.close_rounded,
                    variant: PcButtonVariant.ghost,
                    size: PcButtonSize.sm,
                    loading: isMine,
                    onPressed: isMine ? null : () => widget.onReject(offerId),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PcButton(
                    'Accepter',
                    icon: Icons.check_rounded,
                    size: PcButtonSize.sm,
                    loading: isMine,
                    onPressed: isMine ? null : () => widget.onAccept(offerId),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
