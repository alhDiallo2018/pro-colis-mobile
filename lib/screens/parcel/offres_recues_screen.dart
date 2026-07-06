import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/providers/auth_provider.dart';
import 'package:procolis/providers/parcel_provider.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:procolis/widgets/app_bottom_nav.dart';
import 'package:procolis/widgets/pc_components.dart';

/// Écran "Offres reçues" côté client.
///
/// Agrège toutes les offres (bids) reçues sur l'ensemble des colis du client
/// — une carte par offre — avec le chauffeur, le colis concerné, le prix, le
/// message + la contre-proposition, l'audio, et les actions "Accepter" /
/// "Négocier". Parité avec le web `OffresRecuesScreen.tsx`.
class OffresRecuesScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const OffresRecuesScreen({super.key, this.embedded = false});

  @override
  ConsumerState<OffresRecuesScreen> createState() => _OffresRecuesScreenState();
}

/// Regroupe une offre avec le colis auquel elle se rattache pour l'affichage.
class _ReceivedOffer {
  final Parcel parcel;
  final Bid bid;

  const _ReceivedOffer(this.parcel, this.bid);
}

class _OffresRecuesScreenState extends ConsumerState<OffresRecuesScreen> {
  final _apiService = ApiService();
  final _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _playingAudioUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await ref.read(parcelProvider.notifier).loadMyParcels();
      await ref.read(parcelProvider.notifier).loadFreeParcels();
    } catch (e) {
      debugPrint('Erreur chargement offres reçues: $e');
      if (mounted) {
        _showSnack('Impossible de charger les offres', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Récupère toutes les offres reçues sur les colis appartenant au client,
  /// triées : en attente d'abord, puis les plus récentes.
  List<_ReceivedOffer> _collectOffers() {
    final user = ref.read(authProvider).user;
    final parcelState = ref.watch(parcelProvider);

    final candidates = <Parcel>[
      ...parcelState.parcels,
      ...parcelState.freeParcels,
    ];
    final unique = <String, Parcel>{
      for (final parcel in candidates) parcel.id: parcel,
    }.values.toList();

    final offers = <_ReceivedOffer>[];
    for (final parcel in unique) {
      final isOwner = user == null ||
          parcel.senderId == user.id ||
          parcel.senderPhone == user.phone ||
          parcel.senderName == user.fullName;
      if (!isOwner || parcel.bids.isEmpty) continue;
      for (final bid in parcel.bids) {
        offers.add(_ReceivedOffer(parcel, bid));
      }
    }

    offers.sort((a, b) {
      // Les offres en attente remontent en tête.
      final aPending = a.bid.isPending ? 0 : 1;
      final bPending = b.bid.isPending ? 0 : 1;
      if (aPending != bPending) return aPending.compareTo(bPending);
      return b.bid.createdAt.compareTo(a.bid.createdAt);
    });

    return offers;
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : _buildBody();

    if (widget.embedded) {
      return ColoredBox(color: AppTheme.backgroundColor, child: content);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Offres reçues'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: content,
      bottomNavigationBar: widget.embedded ? null : const AppBottomNav(),
    );
  }

  Widget _buildBody() {
    final offers = _collectOffers();

    if (offers.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.cardColor,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            PcEmptyState(
              icon: Icons.inbox_rounded,
              tone: PcTone.primary,
              title: 'Aucune offre',
              message: 'Aucune offre reçue pour vos annonces.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.cardColor,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          PcSectionHeader('${offers.length} offres reçues'),
          const SizedBox(height: 4),
          ...offers.map(
            (offer) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReceivedOfferCard(
                parcel: offer.parcel,
                bid: offer.bid,
                playingAudioUrl: _playingAudioUrl,
                isSubmitting: _isSubmitting,
                onPlayAudio: _toggleAudio,
                onNegotiate: () => _showNegotiateSheet(offer.bid),
                onAccept: () => _acceptBid(offer.parcel, offer.bid),
              ),
            ),
          ),
        ],
      ),
    );
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
        await _load();
      } else {
        final error = ref.read(parcelProvider).error;
        _showSnack(error ?? 'Impossible d\'accepter cette offre', isError: true);
      }
    } catch (e) {
      debugPrint('Erreur acceptation offre: $e');
      if (mounted) _showSnack('Erreur lors de l\'acceptation', isError: true);
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

    await Future<void>.delayed(const Duration(milliseconds: 350));
    priceController.dispose();
    messageController.dispose();
  }

  Future<void> _negotiateBid(Bid bid, double price, String? message) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final result =
          await _apiService.negotiateBid(bid.id, {'price': price, 'message': message});
      if (!mounted) return;
      if (result['success'] == true) {
        _showSnack('Contre-offre envoyée');
        await _load();
      } else {
        _showSnack(
          result['message']?.toString() ?? 'Négociation impossible',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Erreur négociation offre: $e');
      if (mounted) _showSnack('Erreur lors de la négociation', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppTheme.red500 : AppTheme.green500,
      ),
    );
  }
}

// ============================================================
// Carte d'une offre reçue
// ============================================================

class _ReceivedOfferCard extends StatelessWidget {
  final Parcel parcel;
  final Bid bid;
  final String? playingAudioUrl;
  final bool isSubmitting;
  final ValueChanged<String> onPlayAudio;
  final VoidCallback onNegotiate;
  final VoidCallback onAccept;

  const _ReceivedOfferCard({
    required this.parcel,
    required this.bid,
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
    return AppTheme.slate200;
  }

  @override
  Widget build(BuildContext context) {
    final driverName = bid.driverName.isEmpty ? 'Chauffeur' : bid.driverName;
    final isPlaying = bid.audioUrl != null && playingAudioUrl == bid.audioUrl;
    final hasMessage = bid.message?.trim().isNotEmpty == true;
    final hasResponse = bid.responseMessage?.trim().isNotEmpty == true;
    final audioUrl = bid.audioUrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: _cardBorder,
          width: bid.isAccepted || bid.isRejected ? 2 : 1,
        ),
        boxShadow: AppTheme.softShadow(alpha: 0.045),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PcAvatar(driverName, size: 46, status: PcAvatarStatus.online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (parcel.trackingNumber.isNotEmpty)
                      Text(
                        parcel.receiverName.isNotEmpty
                            ? '${parcel.trackingNumber} · ${parcel.receiverName}'
                            : parcel.trackingNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.mono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (bid.isAccepted)
                const PcBadge('Acceptée',
                    tone: PcTone.green, icon: Icons.check_rounded)
              else if (bid.isRejected)
                const PcBadge('Refusée',
                    tone: PcTone.red, icon: Icons.close_rounded)
              else
                const PcBadge('En attente', tone: PcTone.amber),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Proposition',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatMoney(bid.price)} FCFA',
                style: AppTheme.mono(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.teal600,
                ),
              ),
            ],
          ),
          if (hasMessage || hasResponse) ...[
            const SizedBox(height: 10),
            if (hasMessage)
              _Bubble(
                side: _BubbleSide.left,
                who: driverName,
                text: bid.message!.trim(),
              ),
            if (hasResponse) ...[
              const SizedBox(height: 6),
              _Bubble(
                side: _BubbleSide.right,
                who: 'Vous (contre-proposition)',
                text: bid.responseMessage!.trim(),
              ),
            ],
          ],
          if (audioUrl != null && audioUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            _AudioBubble(
              isPlaying: isPlaying,
              onTap: () => onPlayAudio(audioUrl),
            ),
          ],
          const SizedBox(height: 12),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 18, color: AppTheme.green500),
                    const SizedBox(width: 6),
                    Text(
                      'Offre acceptée',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.green500,
                      ),
                    ),
                  ],
                )
              else if (bid.isRejected)
                Text(
                  'Offre refusée',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.slate400,
                  ),
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

  static String _formatWhen(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${date.day}/${date.month}/${date.year}';
  }
}

enum _BubbleSide { left, right }

class _Bubble extends StatelessWidget {
  final _BubbleSide side;
  final String who;
  final String text;

  const _Bubble({required this.side, required this.who, required this.text});

  @override
  Widget build(BuildContext context) {
    final isLeft = side == _BubbleSide.left;
    return Align(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Column(
          crossAxisAlignment:
              isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: isLeft ? 4 : 0,
                right: isLeft ? 0 : 4,
                bottom: 2,
              ),
              child: Text(
                who,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate400,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isLeft ? AppTheme.slate100 : AppTheme.teal600,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isLeft ? 4 : 12),
                  topRight: Radius.circular(isLeft ? 12 : 4),
                  bottomLeft: const Radius.circular(12),
                  bottomRight: const Radius.circular(12),
                ),
              ),
              child: Text(
                text,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isLeft ? AppTheme.textPrimary : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioBubble extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _AudioBubble({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.slate100,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: AppTheme.teal600,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              isPlaying ? 'Lecture…' : 'Message audio',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Feuille de négociation (contre-offre)
// ============================================================

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
    final driverName = bid.driverName.isEmpty ? 'Chauffeur' : bid.driverName;
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
              'Négocier avec $driverName',
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
