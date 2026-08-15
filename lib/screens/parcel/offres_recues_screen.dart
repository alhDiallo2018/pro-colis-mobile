import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/providers/auth_provider.dart';
import 'package:procolis/providers/parcel_provider.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:procolis/utils/parcel_access_policy.dart';
import 'package:procolis/widgets/app_bottom_nav.dart';
import 'package:procolis/widgets/negotiation_chat_widget.dart';
import 'package:procolis/widgets/pc_components.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/screens/shared/messages_screen.dart';

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

/// Proposition directe (Flux B) sans bid : le client a envoyé une
/// proposition à un chauffeur spécifique.
class _ReceivedProposal {
  final Parcel parcel;

  const _ReceivedProposal(this.parcel);
}

/// Arguments pour la contre-proposition.
class _CounterArgs {
  final int price;
  final String message;
  const _CounterArgs({required this.price, this.message = ''});
}

class _OffresRecuesScreenState extends ConsumerState<OffresRecuesScreen> {
  final _audioPlayer = AudioPlayer();
  final _apiService = ApiService();
  StreamSubscription<void>? _audioCompleteSubscription;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _playingAudioUrl;

  @override
  void initState() {
    super.initState();
    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingAudioUrl = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _audioCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
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
      if (!isParcelSender(parcel, user) || parcel.bids.isEmpty) continue;
      for (final bid in parcel.bids) {
        offers.add(_ReceivedOffer(parcel, bid));
      }
    }

    offers.sort((a, b) {
      final aPending = a.bid.isPending ? 0 : 1;
      final bPending = b.bid.isPending ? 0 : 1;
      if (aPending != bPending) return aPending.compareTo(bPending);
      return b.bid.createdAt.compareTo(a.bid.createdAt);
    });

    return offers;
  }

  /// Récupère les propositions directes (Flux B) ouvertes sur les colis
  /// appartenant au client (proposalStatus = pending ou countered).
  List<_ReceivedProposal> _collectProposals() {
    final user = ref.read(authProvider).user;
    final parcelState = ref.watch(parcelProvider);

    final candidates = <String, Parcel>{
      for (final p in [...parcelState.parcels, ...parcelState.freeParcels])
        p.id: p,
    }.values.toList();

    final proposals = <_ReceivedProposal>[];
    for (final parcel in candidates) {
      if (!isParcelSender(parcel, user)) continue;
      if (!parcel.hasOpenProposal) continue;
      if (parcel.bids.any((b) => b.isActive)) continue;
      proposals.add(_ReceivedProposal(parcel));
    }

    return proposals;
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? Center(
            child: CircularProgressIndicator(color: AppTheme.primary))
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
    final proposals = _collectProposals();
    final isEmpty = offers.isEmpty && proposals.isEmpty;

    if (isEmpty) {
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

    final totalCount = offers.length + proposals.length;

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.cardColor,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          PcSectionHeader('$totalCount offre${totalCount > 1 ? 's' : ''} reçue${totalCount > 1 ? 's' : ''}'),
          const SizedBox(height: 4),
          for (final offer in offers)
            Padding(
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
          for (final proposal in proposals)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReceivedProposalCard(
                parcel: proposal.parcel,
                isSubmitting: _isSubmitting,
                onAccept: () => _acceptProposal(proposal.parcel),
                onReject: () => _rejectProposal(proposal.parcel),
                onCounter: () => _counterProposal(proposal.parcel),
                onOpenChat: () => _openProposalChat(proposal.parcel),
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
        _showSnack('Négociation démarrée. Le chauffeur va confirmer.');
        await _load();
      } else {
        final error = ref.read(parcelProvider).error;
        _showSnack(error ?? 'Impossible d\'accepter cette offre',
            isError: true);
      }
    } catch (e) {
      debugPrint('Erreur acceptation offre: $e');
      if (mounted) _showSnack('Erreur lors de l\'acceptation', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showNegotiateSheet(Bid bid) async {
    final driverId = bid.driverId;
    final driverName = bid.driverName.isNotEmpty ? bid.driverName : 'Chauffeur';
    final parcelId = bid.parcelId;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NegotiationChatScreen(
          peerId: driverId,
          peerName: driverName,
          parcelId: parcelId,
          bidId: bid.id,
          role: 'client',
          isOwner: true,
          onChanged: _load,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Propositions directes (Flux B)
  // ═══════════════════════════════════════════════════════════

  Future<void> _acceptProposal(Parcel parcel) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final result = await _apiService.respondToCounterProposal(
        parcel.id,
        'accept',
      );
      if (!mounted) return;
      if (result['success'] == false) {
        _showSnack(
            result['message']?.toString() ?? 'Échec de l\'acceptation',
            isError: true);
      } else {
        _showSnack('Proposition acceptée. Le chauffeur va confirmer.');
        await _load();
      }
    } catch (_) {
      _showSnack('Erreur lors de l\'acceptation', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _rejectProposal(Parcel parcel) async {
    if (_isSubmitting) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la proposition ?'),
        content: Text('Refuser la proposition de '
            '${parcel.proposedDriverName ?? "le chauffeur"} '
            'à ${_fmt(parcel.currentProposalPrice ?? 0)} FCFA ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red500),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await _apiService.respondToCounterProposal(
        parcel.id,
        'reject',
      );
      if (!mounted) return;
      if (result['success'] == false) {
        _showSnack(
            result['message']?.toString() ?? 'Impossible de refuser',
            isError: true);
      } else {
        _showSnack('Proposition refusée');
        await _load();
      }
    } catch (_) {
      _showSnack('Erreur lors du refus', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _counterProposal(Parcel parcel) async {
    final priceCtrl = TextEditingController(
        text: (parcel.currentProposalPrice ?? 0).toInt().toString());
    final msgCtrl = TextEditingController();

    final result = await showModalBottomSheet<_CounterArgs?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Contre-proposition',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Proposer un nouveau prix à '
                '${parcel.proposedDriverName ?? "le chauffeur"}',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Montant (FCFA)',
                  suffixText: 'FCFA',
                  filled: true,
                  fillColor: AppTheme.amber50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.amber400),
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.amber600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Message (facultatif)',
                  filled: true,
                  fillColor: AppTheme.slate100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PcButton(
                'Envoyer la contre-proposition',
                onPressed: () {
                  final price = double.tryParse(priceCtrl.text.trim());
                  if (price == null || price <= 0) return;
                  Navigator.pop(ctx, _CounterArgs(
                    price: price.toInt(),
                    message: msgCtrl.text.trim(),
                  ));
                },
                icon: Icons.send_rounded,
                size: PcButtonSize.lg,
                block: true,
              ),
            ],
          ),
        ),
      ),
    );

    priceCtrl.dispose();
    msgCtrl.dispose();

    if (result == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final apiResult = await _apiService.respondToCounterProposal(
        parcel.id,
        'counter',
        price: result.price.toDouble(),
        message: result.message.isNotEmpty ? result.message : null,
      );
      if (!mounted) return;
      if (apiResult['success'] == false) {
        _showSnack(
            apiResult['message']?.toString() ?? 'Contre-proposition échouée',
            isError: true);
      } else {
        _showSnack('Contre-proposition envoyée');
        await _load();
      }
    } catch (_) {
      _showSnack('Erreur lors de l\'envoi', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openProposalChat(Parcel parcel) {
    final driverId = parcel.proposedDriverId ?? parcel.senderId;
    final driverName =
        parcel.proposedDriverName?.isNotEmpty == true
            ? parcel.proposedDriverName!
            : 'Chauffeur';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          initialPeerId: driverId,
          initialPeerName: driverName,
          initialParcelId: parcel.id,
        ),
      ),
    );
  }

  String _fmt(double v) {
    final s = v.toInt().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
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
// Carte d'une offre reçue (Flux A)
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
                      style: AppFonts.plusJakartaSans(
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
              else if (bid.isNegotiating)
                const PcBadge('En négociation',
                    tone: PcTone.amber, icon: Icons.handshake_rounded)
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
                style: AppFonts.manrope(
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
            if (hasResponse)
              _Bubble(
                side: _BubbleSide.right,
                who: 'Vous (contre-proposition)',
                text: bid.responseMessage!.trim(),
              )
            else if (hasMessage)
              _Bubble(
                side: _BubbleSide.left,
                who: driverName,
                text: bid.message!.trim(),
              ),
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
                  style: AppFonts.manrope(
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
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: AppTheme.green500),
                    const SizedBox(width: 6),
                    Text(
                      'Offre acceptée',
                      style: AppFonts.manrope(
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
                  style: AppFonts.manrope(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.slate400,
                  ),
                )
              else if (bid.isPending) ...[
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
              ] else ...[
                PcButton(
                  'Négocier',
                  variant: PcButtonVariant.secondary,
                  size: PcButtonSize.sm,
                  onPressed: isSubmitting ? null : onNegotiate,
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

// ============================================================
// Carte d'une proposition directe (Flux B)
// ============================================================

class _ReceivedProposalCard extends StatelessWidget {
  final Parcel parcel;
  final bool isSubmitting;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCounter;
  final VoidCallback onOpenChat;

  const _ReceivedProposalCard({
    required this.parcel,
    required this.isSubmitting,
    required this.onAccept,
    required this.onReject,
    required this.onCounter,
    required this.onOpenChat,
  });

  String _fmt(double v) {
    final s = v.toInt().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final driverName =
        parcel.proposedDriverName?.isNotEmpty == true
            ? parcel.proposedDriverName!
            : 'Chauffeur';
    final price = parcel.currentProposalPrice ?? 0;
    final lastOfferBy = parcel.proposalLastOfferBy;
    final lastMsg = parcel.proposalLastMessage;
    final canAccept = parcel.clientCanAcceptProposal;
    final status = parcel.proposalStatus ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
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
                      style: AppFonts.plusJakartaSans(
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
              PcBadge(
                status == 'countered' ? 'Contre-offre' : 'En attente',
                tone: status == 'countered' ? PcTone.amber : PcTone.primary,
                icon: Icons.handshake_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Proposition',
                style: AppFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_fmt(price)} FCFA',
                style: AppTheme.mono(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.teal600,
                ),
              ),
            ],
          ),
          if (lastOfferBy != null && lastOfferBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Par : ${lastOfferBy == 'driver' ? 'Chauffeur' : 'Vous'}'
              '${parcel.proposalNegotiationCount > 0 ? ' · ${parcel.proposalNegotiationCount} échange${parcel.proposalNegotiationCount > 1 ? 's' : ''}' : ''}',
              style: TextStyle(fontSize: 11, color: AppTheme.slate500),
            ),
          ],
          if (lastMsg != null && lastMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.slate100,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                lastMsg,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: onOpenChat,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.slate100,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Icon(Icons.chat_rounded,
                      size: 18, color: AppTheme.textSecondary),
                ),
              ),
              const Spacer(),
              PcButton(
                'Refuser',
                variant: PcButtonVariant.danger,
                size: PcButtonSize.sm,
                onPressed: isSubmitting ? null : onReject,
              ),
              const SizedBox(width: 8),
              PcButton(
                'Contre-proposer',
                variant: PcButtonVariant.secondary,
                size: PcButtonSize.sm,
                onPressed: isSubmitting ? null : onCounter,
              ),
              if (canAccept) ...[
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
}

// ============================================================
// Widgets partagés (bulles, audio)
// ============================================================

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
                style: AppFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate400,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                style: AppFonts.manrope(
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
              style: AppFonts.manrope(
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
