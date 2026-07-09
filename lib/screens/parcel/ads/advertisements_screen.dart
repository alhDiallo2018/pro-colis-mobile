import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:procolis/models/advertisement.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/providers/auth_provider.dart';
import 'package:procolis/providers/parcel_provider.dart';
import 'package:procolis/screens/parcel/ads/advertisement_detail_screen.dart';
import 'package:procolis/screens/parcel/create_colis_sheet.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:procolis/widgets/app_bottom_nav.dart';
import 'package:procolis/widgets/pc_components.dart';

class AdvertisementsScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const AdvertisementsScreen({
    super.key,
    this.embedded = false,
  });

  @override
  ConsumerState<AdvertisementsScreen> createState() =>
      _AdvertisementsScreenState();
}

class _AdvertisementsScreenState extends ConsumerState<AdvertisementsScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  final _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _playingAudioUrl;
  late final TabController _tabController;
  List<Advertisement> _trips = const [];
  final _tripSearchController = TextEditingController();
  String _tripQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLibreService());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tripSearchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadLibreService() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await ref.read(parcelProvider.notifier).loadMyParcels();
      await ref.read(parcelProvider.notifier).loadFreeParcels();
      final rawTrips =
          await _apiService.getAdvertisements(params: {'status': 'open'});
      final trips = rawTrips.map(Advertisement.fromJson).toList();
      if (mounted) setState(() => _trips = trips);
    } catch (e) {
      debugPrint('Erreur chargement libre service: $e');
      if (mounted) {
        _showSnack('Impossible de charger le libre service', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _LibreServiceHeader(
          onRefresh: _loadLibreService,
          onBack: widget.embedded
              ? null
              : () => Navigator.of(context).maybePop(),
        ),
        Container(
          color: AppTheme.cardColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Mes annonces'),
              Tab(text: 'Voyages'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBody(),
              _buildTripsTab(),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: AppTheme.backgroundColor, child: content);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: content,
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  List<Advertisement> _filteredTrips() {
    final query = _tripQuery.trim().toLowerCase();
    if (query.isEmpty) return _trips;
    return _trips.where((trip) {
      final haystack = [
        trip.departureCity ?? '',
        trip.arrivalCity ?? '',
        trip.driverName,
        trip.description ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _openTrip(Advertisement trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvertisementDetailScreen(adId: trip.id),
      ),
    ).then((_) => _loadLibreService());
  }

  Widget _buildTripsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    final trips = _filteredTrips();

    Widget listArea;
    if (trips.isEmpty) {
      listArea = RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadLibreService,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.1),
            PcEmptyState(
              icon: Icons.local_shipping_outlined,
              tone: PcTone.primary,
              title: _tripQuery.trim().isEmpty
                  ? 'Aucun voyage disponible'
                  : 'Aucun résultat',
              message: _tripQuery.trim().isEmpty
                  ? 'Les voyages des chauffeurs apparaîtront ici.'
                  : 'Aucun voyage ne correspond à votre recherche.',
            ),
          ],
        ),
      );
    } else {
      listArea = RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.cardColor,
        onRefresh: _loadLibreService,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: trips.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _TripCard(
            trip: trips[index],
            onTap: () => _openTrip(trips[index]),
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildTripSearchField(),
        Expanded(child: listArea),
      ],
    );
  }

  Widget _buildTripSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: TextField(
        controller: _tripSearchController,
        onChanged: (value) => setState(() => _tripQuery = value),
        textInputAction: TextInputAction.search,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppTheme.slate50,
          hintText: 'Rechercher (ville, chauffeur, description)',
          hintStyle: GoogleFonts.manrope(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.slate400,
          ),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: AppTheme.slate400),
          suffixIcon: _tripQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.slate400),
                  onPressed: () {
                    _tripSearchController.clear();
                    setState(() => _tripQuery = '');
                  },
                ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.slate200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.slate200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    final selectedParcel = _selectLibreServiceParcel();
    if (selectedParcel == null) {
      return _EmptyLibreServiceState(onCreate: _openNewParcel);
    }

    final offers = [
      ...selectedParcel.pendingBids,
      ...selectedParcel.acceptedBids,
      ...selectedParcel.rejectedBids,
    ];

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.cardColor,
      onRefresh: _loadLibreService,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _LibreParcelCard(parcel: selectedParcel),
          const SizedBox(height: 18),
          PcSectionHeader('${offers.length} offres reçues'),
          const SizedBox(height: 4),
          if (offers.isEmpty)
            _NoOffersCard(onCreate: _openNewParcel)
          else
            ...offers.map(
              (offer) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OfferCard(
                  bid: offer,
                  selected: offer.isAccepted ||
                      selectedParcel.selectedBidId == offer.id,
                  playingAudioUrl: _playingAudioUrl,
                  isSubmitting: _isSubmitting,
                  onPlayAudio: _toggleAudio,
                  onNegotiate: () => _showNegotiateSheet(offer),
                  onAccept: () => _acceptBid(selectedParcel, offer),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Parcel? _selectLibreServiceParcel() {
    final user = ref.read(authProvider).user;
    final parcelState = ref.watch(parcelProvider);

    final candidates = <Parcel>[
      ...parcelState.parcels,
      ...parcelState.freeParcels,
    ];

    final unique = <String, Parcel>{
      for (final parcel in candidates) parcel.id: parcel,
    }.values.toList();

    // On privilégie les colis du client qui ont déjà des offres, comme dans
    // l'écran design "Libre service — client: offres reçues".
    final ownedLibreParcels = unique.where((parcel) {
      final isOwner = user == null ||
          parcel.senderId == user.id ||
          parcel.senderPhone == user.phone ||
          parcel.senderName == user.fullName;
      return isOwner && (parcel.isFreeForBidding || parcel.hasBids);
    }).toList();

    ownedLibreParcels.sort((a, b) {
      final byBidCount = b.bidsCount.compareTo(a.bidsCount);
      if (byBidCount != 0) return byBidCount;
      return b.createdAt.compareTo(a.createdAt);
    });

    if (ownedLibreParcels.isNotEmpty) return ownedLibreParcels.first;

    final fallback = unique.where((parcel) {
      return parcel.isFreeForBidding || parcel.status == ParcelStatus.free;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return fallback.isEmpty ? null : fallback.first;
  }

  Future<void> _toggleAudio(String audioUrl) async {
    try {
      if (_playingAudioUrl == audioUrl) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playingAudioUrl = null);
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(audioUrl));
      if (mounted) setState(() => _playingAudioUrl = audioUrl);

      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted && _playingAudioUrl == audioUrl) {
          setState(() => _playingAudioUrl = null);
        }
      });
    } catch (e) {
      debugPrint('Erreur lecture audio offre: $e');
      _showSnack('Lecture audio impossible', isError: true);
    }
  }

  Future<void> _acceptBid(Parcel parcel, Bid bid) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final success =
          await ref.read(parcelProvider.notifier).acceptBid(parcel.id, bid.id);
      if (!mounted) return;

      if (success) {
        _showSnack('Offre acceptée');
        await _loadLibreService();
      } else {
        final error = ref.read(parcelProvider).error;
        _showSnack(error ?? 'Impossible d\'accepter cette offre',
            isError: true);
      }
    } catch (e) {
      debugPrint('Erreur acceptation offre: $e');
      if (mounted) {
        _showSnack('Erreur lors de l\'acceptation', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showNegotiateSheet(Bid bid) async {
    final priceController =
        TextEditingController(text: bid.price.toStringAsFixed(0));
    final messageController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _NegotiateSheet(
            bid: bid,
            priceController: priceController,
            messageController: messageController,
            onSubmit: () async {
              final price =
                  double.tryParse(priceController.text.replaceAll(' ', ''));
              if (price == null || price <= 0) {
                _showSnack('Prix de contre-offre invalide', isError: true);
                return;
              }

              Navigator.pop(context);
              await _negotiateBid(
                bid,
                price,
                messageController.text.trim().isEmpty
                    ? null
                    : messageController.text.trim(),
              );
            },
          ),
        );
      },
    );

    // La route de bottom sheet reste brièvement montée pendant l'animation de
    // fermeture; disposer immédiatement les contrôleurs peut casser les champs.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    priceController.dispose();
    messageController.dispose();
  }

  Future<void> _negotiateBid(Bid bid, double price, String? message) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final result = await _apiService.negotiateBid(bid.id, {'price': price, 'message': message});
      if (!mounted) return;

      if (result['success'] == true) {
        _showSnack('Contre-offre envoyée');
        await _loadLibreService();
      } else {
        _showSnack(
          result['message']?.toString() ?? 'Négociation impossible',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Erreur négociation offre: $e');
      if (mounted) {
        _showSnack('Erreur lors de la négociation', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openNewParcel() {
    showCreateColisSheet(context).then((_) => _loadLibreService());
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }
}

class _LibreServiceHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback? onBack;

  const _LibreServiceHeader({required this.onRefresh, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 14,
        18,
        16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
          bottom: BorderSide(color: AppTheme.slate200),
        ),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            PcIconButton(
              Icons.arrow_back_rounded,
              onPressed: onBack,
              variant: PcIconButtonVariant.soft,
              tooltip: 'Retour',
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              'Libre service',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          PcIconButton(
            Icons.tune_rounded,
            onPressed: onRefresh,
            variant: PcIconButtonVariant.soft,
            tooltip: 'Actualiser',
          ),
        ],
      ),
    );
  }
}

class _LibreParcelCard extends StatelessWidget {
  final Parcel parcel;

  const _LibreParcelCard({required this.parcel});

  @override
  Widget build(BuildContext context) {
    final price =
        parcel.proposedPrice ?? parcel.negotiatedPrice ?? parcel.price;

    return PcCard(
      radius: AppTheme.radiusLg,
      padding: const EdgeInsets.all(18),
      shadow: AppTheme.softShadow(alpha: 0.06),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  size: 20, color: AppTheme.slate400),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  parcel.trackingNumber,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const PcBadge(
                'Libre service',
                tone: PcTone.primary,
                icon: Icons.sell_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _RouteEnd(
                  label: 'Départ',
                  city: parcel.departureGarageName,
                ),
              ),
              const Icon(Icons.local_shipping_outlined,
                  color: AppTheme.primary, size: 28),
              Expanded(
                child: _RouteEnd(
                  label: 'Arrivée',
                  city: parcel.arrivalGarageName ?? 'Destination',
                  alignRight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.slate200),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetaItem(
                  icon: Icons.shopping_bag_outlined,
                  value: '${_trimNumber(parcel.weight)} kg',
                  mono: true,
                ),
              ),
              Expanded(
                child: _MetaItem(
                  icon: Icons.category_outlined,
                  value: parcel.type.label,
                ),
              ),
              Expanded(
                child: _MetaItem(
                  icon: Icons.schedule_rounded,
                  value: '~${_etaHours(parcel)} h',
                ),
              ),
              Expanded(
                child: Text(
                  price == null ? '-- FCFA' : '${_formatMoney(price)} FCFA',
                  textAlign: TextAlign.right,
                  style: AppTheme.mono(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.teal600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _etaHours(Parcel parcel) {
    final eta = parcel.estimatedDeliveryDate;
    if (eta == null) return '2';
    final hours = eta.difference(DateTime.now()).inHours.abs();
    return hours.clamp(1, 96).toString();
  }
}

class _OfferCard extends StatelessWidget {
  final Bid bid;
  final bool selected;
  final String? playingAudioUrl;
  final bool isSubmitting;
  final ValueChanged<String> onPlayAudio;
  final VoidCallback onNegotiate;
  final VoidCallback onAccept;

  const _OfferCard({
    required this.bid,
    required this.selected,
    required this.playingAudioUrl,
    required this.isSubmitting,
    required this.onPlayAudio,
    required this.onNegotiate,
    required this.onAccept,
  });

  Color get _cardBackground {
    if (bid.isAccepted) return AppTheme.green50;
    if (bid.isRejected) return AppTheme.red50;
    return AppTheme.cardColor;
  }

  Color get _cardBorder {
    if (bid.isAccepted) return AppTheme.green500;
    if (bid.isRejected) return AppTheme.red400;
    return selected ? AppTheme.primary : AppTheme.slate200;
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = bid.audioUrl != null && playingAudioUrl == bid.audioUrl;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: _cardBorder,
          width: selected || bid.isAccepted || bid.isRejected ? 2 : 1,
        ),
        boxShadow: AppTheme.softShadow(alpha: 0.045),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PcAvatar(
            bid.driverName.isEmpty ? 'Chauffeur' : bid.driverName,
            size: 48,
            status: PcAvatarStatus.online,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bid.driverName.isEmpty ? 'Chauffeur' : bid.driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${_formatMoney(bid.price)} FCFA',
                      style: AppTheme.mono(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.teal600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Zone partenaire · 4,8 ★',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                _OfferMessage(
                  bid: bid,
                  isPlaying: isPlaying,
                  onPlayAudio: onPlayAudio,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatWhen(bid.createdAt),
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          color: AppTheme.slate400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (bid.isAccepted)
                      const PcBadge(
                        'Acceptée',
                        tone: PcTone.green,
                        icon: Icons.check_rounded,
                      )
                    else if (bid.isRejected)
                      const PcBadge(
                        'Rejetée',
                        tone: PcTone.red,
                        icon: Icons.close_rounded,
                      )
                    else ...[
                      PcButton(
                        'Négocier',
                        variant: PcButtonVariant.secondary,
                        size: PcButtonSize.sm,
                        onPressed: isSubmitting ? null : onNegotiate,
                      ),
                      const SizedBox(width: 8),
                      PcButton(
                        'Accepter',
                        icon: Icons.check_rounded,
                        size: PcButtonSize.sm,
                        onPressed: isSubmitting ? null : onAccept,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferMessage extends StatelessWidget {
  final Bid bid;
  final bool isPlaying;
  final ValueChanged<String> onPlayAudio;

  const _OfferMessage({
    required this.bid,
    required this.isPlaying,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final audioUrl = bid.audioUrl;
    final hasMessage = bid.message?.trim().isNotEmpty == true;

    if (audioUrl != null && audioUrl.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: AppTheme.slate100,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusSm),
            topRight: Radius.circular(AppTheme.radiusSm),
            bottomRight: Radius.circular(AppTheme.radiusSm),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => onPlayAudio(audioUrl),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: _Waveform()),
            const SizedBox(width: 8),
            Text(
              isPlaying ? 'En cours' : 'Message vocal',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (!hasMessage) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(top: 4),
      decoration: const BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusSm),
          topRight: Radius.circular(AppTheme.radiusSm),
          bottomRight: Radius.circular(AppTheme.radiusSm),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Text(
        bid.message!.trim(),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppTheme.slate700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _NegotiateSheet extends StatelessWidget {
  final Bid bid;
  final TextEditingController priceController;
  final TextEditingController messageController;
  final VoidCallback onSubmit;

  const _NegotiateSheet({
    required this.bid,
    required this.priceController,
    required this.messageController,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.slate300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Négocier avec ${bid.driverName}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Votre contre-offre',
                suffixText: 'FCFA',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message au chauffeur',
                hintText: 'Ex: Je peux confirmer à ce prix.',
              ),
            ),
            const SizedBox(height: 18),
            PcButton(
              'Envoyer la contre-offre',
              icon: Icons.send_rounded,
              block: true,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibreServiceState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyLibreServiceState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 120),
      children: [
        PcEmptyState(
          icon: Icons.sell_rounded,
          tone: PcTone.primary,
          title: 'Aucune annonce libre service',
          message:
              'Publiez un colis en libre service pour recevoir les offres des chauffeurs.',
          action: PcButton(
            'Ajouter un colis',
            icon: Icons.add_rounded,
            onPressed: onCreate,
          ),
        ),
      ],
    );
  }
}

class _NoOffersCard extends StatelessWidget {
  final VoidCallback onCreate;

  const _NoOffersCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return PcCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.slate100,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(Icons.inbox_outlined, color: AppTheme.slate500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aucune offre reçue pour le moment.',
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          PcButton(
            'Nouveau',
            variant: PcButtonVariant.ghost,
            size: PcButtonSize.sm,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _RouteEnd extends StatelessWidget {
  final String label;
  final String city;
  final bool alignRight;

  const _RouteEnd({
    required this.label,
    required this.city,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppTheme.slate400,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          city.isEmpty ? 'Ville' : city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            height: 1,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool mono;

  const _MetaItem({
    required this.icon,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = mono
        ? AppTheme.mono(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.slate600,
          )
        : GoogleFonts.manrope(
            fontSize: 14,
            height: 1.25,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.slate400),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform();

  @override
  Widget build(BuildContext context) {
    const heights = [8.0, 15.0, 11.0, 20.0, 13.0, 17.0, 9.0, 16.0, 12.0];
    return Row(
      children: [
        for (final height in heights)
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity( 0.38),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _formatMoney(num value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final reverseIndex = rounded.length - i;
    buffer.write(rounded[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write(' ');
  }
  return buffer.toString();
}

String _trimNumber(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

String _formatWhen(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'à l\'instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

const _tripMonths = [
  'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
  'juil', 'août', 'sep', 'oct', 'nov', 'déc'
];

String formatTripDate(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_tripMonths[d.month - 1]} · $hh:$mm';
}

class _TripCard extends StatelessWidget {
  final Advertisement trip;
  final VoidCallback onTap;

  const _TripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final from = trip.departureCity?.isNotEmpty == true ? trip.departureCity! : '—';
    final to = trip.arrivalCity?.isNotEmpty == true ? trip.arrivalCity! : '—';
    final driver = trip.driverName.isNotEmpty ? trip.driverName : 'Chauffeur';
    final tripDate = trip.departureAt;

    return PcCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.teal50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(from,
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 16, color: AppTheme.slate400),
                    ),
                    Flexible(
                      child: Text(to,
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.slate400),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (tripDate != null)
                _chip(Icons.event_rounded, formatTripDate(tripDate)),
              _chip(Icons.scale_rounded, trip.formattedWeight, mono: true),
              _chip(Icons.payments_rounded, trip.formattedPrice, mono: true),
              if (trip.offersCount > 0)
                _chip(Icons.local_offer_rounded,
                    '${trip.offersCount} offre${trip.offersCount > 1 ? 's' : ''}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              PcAvatar(driver, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(driver,
                    style: GoogleFonts.manrope(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('Détail',
                  style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, {bool mono = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.slate400),
          const SizedBox(width: 6),
          Text(label,
              style: mono
                  ? AppTheme.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate700)
                  : GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate700)),
        ],
      ),
    );
  }
}
