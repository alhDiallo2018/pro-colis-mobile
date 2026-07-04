import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/providers/auth_provider.dart';
import 'package:procolis/providers/parcel_provider.dart';
import 'package:procolis/screens/parcel/new_parcel_screen.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/theme/app_theme.dart';

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

class _AdvertisementsScreenState extends ConsumerState<AdvertisementsScreen> {
  final _apiService = ApiService();
  final _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _playingAudioUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLibreService());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadLibreService() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await ref.read(parcelProvider.notifier).loadMyParcels();
      await ref.read(parcelProvider.notifier).loadFreeParcels();
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
        _LibreServiceHeader(onRefresh: _loadLibreService),
        Expanded(child: _buildBody()),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: AppTheme.backgroundColor, child: content);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: content,
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
          _SectionHeader(title: '${offers.length} offres reçues'),
          const SizedBox(height: 10),
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewParcelScreen()),
    ).then((_) => _loadLibreService());
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

  const _LibreServiceHeader({required this.onRefresh});

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
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Actualiser',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.slate100,
              foregroundColor: AppTheme.textPrimary,
            ),
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.softShadow(alpha: 0.06),
      ),
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
                  style: GoogleFonts.robotoMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(
                text: 'LIBRE SERVICE',
                icon: Icons.sell_rounded,
                foreground: const Color(0xFF1E55B8),
                background: const Color(0xFFE9F0FF),
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
                  style: GoogleFonts.robotoMono(
                    fontSize: 18,
                    height: 1.15,
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
          _AvatarInitials(name: bid.driverName),
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
                  'Garage partenaire · 4,8 ★',
                  style: TextStyle(
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
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.slate400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (bid.isAccepted)
                      const _StatusPill(
                        text: 'Acceptée',
                        icon: Icons.check_rounded,
                        foreground: AppTheme.green700,
                        background: AppTheme.green50,
                      )
                    else if (bid.isRejected)
                      const _StatusPill(
                        text: 'Rejetée',
                        icon: Icons.close_rounded,
                        foreground: AppTheme.red500,
                        background: AppTheme.red50,
                      )
                    else ...[
                      OutlinedButton(
                        onPressed: isSubmitting ? null : onNegotiate,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          side: const BorderSide(color: AppTheme.slate200),
                          foregroundColor: AppTheme.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                        ),
                        child: const Text('Négocier'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isSubmitting ? null : onAccept,
                        icon: const Icon(Icons.check_rounded, size: 17),
                        label: const Text('Accepter'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                        ),
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
            ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Envoyer la contre-offre'),
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
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.slate200),
            boxShadow: AppTheme.softShadow(alpha: 0.04),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.teal50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Icon(
                  Icons.sell_rounded,
                  color: AppTheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Aucune annonce libre service',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Publiez un colis en libre service pour recevoir les offres des chauffeurs.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter un colis'),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: AppTheme.slate400),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Aucune offre reçue pour le moment.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onCreate, child: const Text('Nouveau')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
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

  const _MetaItem({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: AppTheme.slate400),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              height: 1.25,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color foreground;
  final Color background;

  const _StatusPill({
    required this.text,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  final String name;

  const _AvatarInitials({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.teal50,
          child: Text(
            initials.isEmpty ? 'CH' : initials,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.teal700,
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: AppTheme.green500,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
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
