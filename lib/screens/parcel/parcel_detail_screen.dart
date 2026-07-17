// mobile/lib/screens/parcel/parcel_detail_screen.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/parcel.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/video_player_widget.dart';
import '../shared/messages_screen.dart';
import 'confirm_delivery_screen.dart';

/// Action de cycle de vie côté chauffeur : un seul bouton contextuel qui
/// fait avancer la mission (aligné sur le web MissionsScreen). L'étape
/// `deliver` bascule vers le flux OTP (ConfirmDeliveryScreen).
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

class ParcelDetailScreen extends ConsumerStatefulWidget {
  final Parcel? parcel;
  final String? parcelId;

  const ParcelDetailScreen({super.key, this.parcel, this.parcelId})
      : assert(parcel != null || parcelId != null,
            'Either parcel or parcelId must be provided');

  @override
  ConsumerState<ParcelDetailScreen> createState() => _ParcelDetailScreenState();
}

class _ParcelDetailScreenState extends ConsumerState<ParcelDetailScreen> {
  final ApiService _apiService = ApiService();
  late Parcel _parcel;
  List<ParcelEvent> _events = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _otpCode;
  bool _isLoadingOtp = false;

  // Lecture des notes vocales attachées au colis.
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingAudioIndex;

  // Notation du chauffeur (côté client, colis livré).
  bool _hasRated = false;
  double? _driverAvgRating;
  int? _driverRatingCount;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingAudioIndex = null);
    });
    if (widget.parcel != null) {
      _parcel = widget.parcel!;
      _loadDetailData();
    } else if (widget.parcelId != null) {
      _loadParcelById(widget.parcelId!);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadParcelById(String id) async {
    setState(() => _isLoading = true);
    try {
      final parcel = await _apiService.getParcelById(id);
      if (parcel == null) {
        if (mounted) _showSnack('Colis introuvable');
        return;
      }
      _parcel = parcel;
      final events = await _apiService.getParcelTimeline(id);
      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
      _loadDriverRating();
    } catch (e) {
      if (mounted) {
        _showSnack('Impossible de charger le colis');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDetailData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getParcelById(_parcel.id),
        _apiService.getParcelTimeline(_parcel.id),
      ]);

      if (!mounted) return;
      setState(() {
        final updatedParcel = results[0] as Parcel?;
        _parcel = updatedParcel ?? _parcel;
        _events = results[1] as List<ParcelEvent>;
      });
      _fetchOtp();
      _loadDriverRating();
    } catch (error) {
      debugPrint('Erreur chargement détail colis: $error');
      if (mounted) {
        _showSnack('Impossible de charger les dernières informations');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchOtp() async {
    if (!_parcel.status.isInProgress) return;
    setState(() => _isLoadingOtp = true);
    try {
      final code = await _apiService.getDeliveryCode(_parcel.id);
      if (mounted) {
        setState(() {
          _otpCode = code.isNotEmpty ? code : null;
          _isLoadingOtp = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOtp = false);
    }
  }

  Future<void> _cancelParcel() async {
    if (_parcel.isFinished || _isUpdating) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le colis ?'),
        content: const Text(
          'Cette action marquera le colis comme annulé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red500),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);
    try {
      final ok = await ref
          .read(parcelProvider.notifier)
          .cancelParcel(_parcel.id, reason: 'Annulation depuis le détail');
      if (ok && mounted) {
        setState(
            () => _parcel = _parcel.copyWith(status: ParcelStatus.cancelled));
        _showSnack('Colis annulé');
      }
    } catch (error) {
      debugPrint('Erreur annulation colis: $error');
      if (mounted) {
        _showSnack('Annulation impossible');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _callDriver() async {
    final phone = _parcel.driverPhone;
    if (phone == null || phone.isEmpty) {
      _showSnack('Téléphone chauffeur indisponible');
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      _showSnack('Appel impossible');
    }
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareTracking() async {
    final trackingUrl = 'https://sendprocolis.com/track/${_parcel.trackingNumber}';
    try {
      await Share.share(
        '📦 Suivi de colis PRO COLIS\n\n'
        '🔹 N° de suivi: ${_parcel.trackingNumber}\n'
        '🔹 Statut: ${_parcel.status.label}\n'
        '🔹 Expéditeur: ${_parcel.senderName}\n'
        '🔹 Destinataire: ${_parcel.receiverName}\n\n'
        '🔗 Suivez votre colis en ligne: $trackingUrl',
        subject: 'Suivi de colis PRO COLIS',
        sharePositionOrigin: _shareOrigin(),
      );
    } catch (e, s) {
      // Repli : copie du numéro de suivi si le partage natif échoue.
      debugPrint('❌ [SHARE] $e\n$s');
      await Clipboard.setData(
        ClipboardData(text: 'Suivi SendProcolis ${_parcel.trackingNumber}'),
      );
      _showSnack('Partage indisponible ($e)');
    }
  }

  Future<void> _openTrackingUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Impossible d\'ouvrir le lien');
    }
  }

  String _formatReceiptDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _showReceipt() {
    final GlobalKey receiptKey = GlobalKey();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '📄 Reçu de livraison',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share, color: AppTheme.primary),
                            onPressed: () => _shareReceipt(sheetContext, receiptKey),
                            tooltip: 'Partager',
                          ),
                          IconButton(
                            icon: const Icon(Icons.link, color: AppTheme.primary),
                            onPressed: _shareTracking,
                            tooltip: 'Partager le lien',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: RepaintBoundary(
                      key: receiptKey,
                      child: _buildReceiptWidget(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _shareReceipt(BuildContext context, GlobalKey receiptKey) async {
    try {
      final boundary = receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _showSnack('Impossible de capturer le reçu');
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showSnack('Erreur lors de la capture du reçu');
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/receipt_${_parcel.trackingNumber}.png');
      await file.writeAsBytes(pngBytes);

      final trackingUrl = 'https://sendprocolis.com/track/${_parcel.trackingNumber}';
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📦 Suivi de colis PRO COLIS\n\n'
            '🔹 N° de suivi: ${_parcel.trackingNumber}\n'
            '🔹 Statut: ${_parcel.status.label}\n'
            '🔹 Expéditeur: ${_parcel.senderName}\n'
            '🔹 Destinataire: ${_parcel.receiverName}\n'
            '🔹 Montant: ${_parcel.formattedPrice}\n\n'
            '🔗 Suivez votre colis en ligne: $trackingUrl',
        subject: 'Reçu de livraison PRO COLIS',
        sharePositionOrigin: _shareOrigin(),
      );
    } catch (e, s) {
      debugPrint('❌ [SHARE RECEIPT] $e\n$s');
      _showSnack('Partage du reçu indisponible ($e)');
    }
  }

  Widget _buildReceiptWidget() {
    final parcel = _parcel;
    final isDelivered = parcel.status.value == 'delivered';
    final trackingUrl = 'https://sendprocolis.com/track/${parcel.trackingNumber}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'PRO COLIS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDelivered
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDelivered
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  isDelivered ? '✅ Livré' : '📦 En cours',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDelivered
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                QrImageView(
                  data: trackingUrl,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                  padding: const EdgeInsets.all(8),
                ),
                const SizedBox(height: 8),
                Text(
                  '📱 Scanner pour suivre',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    parcel.trackingNumber,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openTrackingUrl(trackingUrl),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_in_new,
                            size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Voir en ligne',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildReceiptInfoRow('📋 N° de suivi', parcel.trackingNumber,
              isBold: true),
          const SizedBox(height: 8),
          _buildReceiptInfoRow('📅 Date', _formatReceiptDate(parcel.createdAt)),
          const SizedBox(height: 8),
          _buildReceiptInfoRow('📦 Statut', parcel.status.label),
          const SizedBox(height: 8),
          _buildReceiptInfoRow('👤 Expéditeur', parcel.senderName),
          const SizedBox(height: 8),
          _buildReceiptInfoRow('👤 Destinataire', parcel.receiverName),
          const SizedBox(height: 8),
          _buildReceiptInfoRow('📍 Départ', parcel.departureGarageName),
          if (parcel.arrivalGarageName != null) ...[
            const SizedBox(height: 8),
            _buildReceiptInfoRow('📍 Arrivée', parcel.arrivalGarageName!),
          ],
          const SizedBox(height: 8),
          _buildReceiptInfoRow('📦 Poids', parcel.formattedWeight),
          const SizedBox(height: 8),
          _buildReceiptInfoRow('💰 Montant', parcel.formattedPrice),
          if (isDelivered && parcel.deliveryDate != null) ...[
            const SizedBox(height: 8),
            _buildReceiptInfoRow(
                '✅ Livré le', _formatReceiptDate(parcel.deliveryDate!)),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Text(
                  'PRO COLIS - Service de transport interurbain',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 4),
                Text(
                  '📞 +221 33 123 45 67 | 📧 contact@sendprocolis.com',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptInfoRow(String label, String value,
      {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== MÉDIAS (PIÈCES JOINTES) ====================

  /// Résout une URL de média : les chemins relatifs `/uploads/...` sont
  /// préfixés avec le backend, comme dans le reste de l'application.
  String _mediaUrl(String url) => url.startsWith('http')
      ? url
      : ApiService.resolveMediaUrl(url);

  bool get _hasMedia =>
      _parcel.photoUrls.isNotEmpty ||
      _parcel.videoUrls.isNotEmpty ||
      _parcel.audioUrls.isNotEmpty;

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
      _showSnack('Lecture audio impossible');
    }
  }

  List<Widget> _buildMediaSection() {
    if (!_hasMedia) return const [];

    final photos = _parcel.photoUrls;
    final videos = _parcel.videoUrls;
    final audios = _parcel.audioUrls;

    return [
      const SizedBox(height: 18),
      const PcSectionHeader('Pièces jointes'),
      PcCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photos.isNotEmpty) ...[
              _MediaLabel(icon: Icons.photo_library_rounded, text: 'Photos'),
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
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        child: Image.network(
                          url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: AppTheme.slate100,
                            child: const Icon(Icons.broken_image_rounded,
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
              _MediaLabel(
                  icon: Icons.videocam_rounded, text: 'Vidéos'),
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
              _MediaLabel(
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
      ),
    ];
  }

  Future<void> _openConfirmDelivery() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmDeliveryScreen(parcel: _parcel),
      ),
    );

    if (updated == true) {
      await _loadDetailData();
    }
  }

  Future<void> _openDeliveryProof() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryProofScreen(parcel: _parcel),
      ),
    );

    if (updated == true) {
      _showSnack('Preuve de livraison enregistrée');
      await _loadDetailData();
    }
  }

  void _openChat() {
    // Détermine l'interlocuteur selon le rôle : le client parle au chauffeur,
    // le chauffeur (ou garage) parle au client. On ouvre la vraie messagerie
    // synchronisée avec le backend (envoi persisté + polling), pas la maquette.
    final myId = ref.read(authProvider).user?.id;

    String? peerId;
    String peerName;
    if (myId != null && myId == _parcel.senderId) {
      peerId = (_parcel.driverId != null && _parcel.driverId!.isNotEmpty)
          ? _parcel.driverId
          : _parcel.bestBid?.driverId;
      peerName = _driverName;
    } else {
      peerId = _parcel.senderId;
      peerName = _parcel.senderName;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          initialPeerId: peerId,
          initialPeerName: peerName,
          initialParcelId: _parcel.id,
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _arrival => _parcel.arrivalGarageName?.isNotEmpty == true
      ? _parcel.arrivalGarageName!
      : 'Arrivée';

  String get _price {
    final amount = _parcel.negotiatedPrice ??
        _parcel.price ??
        _parcel.proposedPrice ??
        _parcel.totalAmount ??
        0;
    return '${_formatNumber(amount)} FCFA';
  }

  String get _driverName {
    if (_parcel.driverName?.isNotEmpty == true) return _parcel.driverName!;
    if (_parcel.bestBid != null) return _parcel.bestBid!.driverName;
    return 'Chauffeur non assigné';
  }

  String get _driverPhone {
    if (_parcel.driverPhone?.isNotEmpty == true) return _parcel.driverPhone!;
    if (_parcel.bestBid != null) return _parcel.bestBid!.driverPhone;
    return '';
  }

  String get _eta {
    final target = _parcel.estimatedDeliveryDate ?? _parcel.deliveryDate;
    if (target == null) return '~4 h';
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return 'Arrivé';
    if (diff.inDays > 0) return '${diff.inDays} j';
    if (diff.inHours > 0) return '~${diff.inHours} h';
    return '${diff.inMinutes.clamp(1, 59)} min';
  }

  bool get _canConfirmDelivery =>
      !_parcel.isDelivered &&
      !_parcel.isCancelled &&
      (_parcel.status == ParcelStatus.outForDelivery ||
          _parcel.status == ParcelStatus.arrived ||
          _parcel.status == ParcelStatus.inTransit);

  /// L'utilisateur courant est-il le chauffeur assigné à ce colis ? Seul lui
  /// voit l'échelle d'étapes de mission (jamais le client).
  bool get _isAssignedDriver {
    final me = ref.read(authProvider).user;
    if (me == null || !me.isDriver) return false;
    return _parcel.driverId == me.id ||
        (_parcel.driverId == null && _parcel.bestBid?.driverId == me.id);
  }

  _DriverStepAction? get _driverStep =>
      _parcel.isCancelled || _parcel.isDelivered
          ? null
          : _driverNextStep(_parcel.status);

  Future<void> _advanceStep(String step) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final res = await _apiService.advanceParcel(_parcel.id, step);
      if (res['success'] == false) {
        _showSnack(res['message']?.toString() ?? 'Action impossible');
      } else {
        await _loadDetailData();
      }
    } catch (_) {
      _showSnack('Action impossible');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  /// L'utilisateur courant est-il le client propriétaire (expéditeur) du colis ?
  /// Seul lui peut noter le chauffeur — jamais le chauffeur lui-même.
  bool get _isClientOwner {
    final me = ref.read(authProvider).user;
    if (me == null || me.isDriver) return false;
    return _parcel.senderId.isNotEmpty && _parcel.senderId == me.id;
  }

  /// La note du chauffeur n'est proposée que si : (a) je suis le client
  /// propriétaire, (b) le colis est livré, (c) un chauffeur est assigné.
  bool get _canRateDriver =>
      _isClientOwner && _parcel.isDelivered && _parcel.hasDriver;

  /// Libellé de la note moyenne du chauffeur pour la carte (ex: "★ 4,6 · 12 avis").
  String? get _driverRatingLabel {
    final avg = _driverAvgRating;
    final count = _driverRatingCount;
    if (avg == null || count == null || count == 0) return null;
    return '★ ${avg.toStringAsFixed(1).replaceAll('.', ',')} · $count avis';
  }

  /// Récupère (best-effort) la note moyenne du chauffeur pour l'afficher.
  /// Silencieux en cas d'échec ou de liste vide.
  Future<void> _loadDriverRating() async {
    final driverId = _parcel.driverId;
    if (driverId == null || driverId.isEmpty) return;
    try {
      final ratings = await _apiService.getDriverRatings(driverId);
      if (ratings.isEmpty) return;
      final values = ratings
          .map((r) => (r['rating'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      if (values.isEmpty) return;
      final avg = values.reduce((a, b) => a + b) / values.length;
      if (mounted) {
        setState(() {
          _driverAvgRating = avg;
          _driverRatingCount = values.length;
        });
      }
    } catch (_) {
      // Best-effort : on n'affiche simplement rien de plus.
    }
  }

  /// Ouvre la feuille de notation du chauffeur (1–5 étoiles + commentaire).
  Future<void> _rateDriver() async {
    final driverId = _parcel.driverId;
    if (driverId == null || driverId.isEmpty) return;

    final commentCtrl = TextEditingController();
    int selected = 0;
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (selected == 0 || submitting) return;
              setSheetState(() => submitting = true);
              final res = await _apiService.rateDriver(
                driverId: driverId,
                rating: selected,
                parcelId: _parcel.id,
                comment: commentCtrl.text.trim().isEmpty
                    ? null
                    : commentCtrl.text.trim(),
              );
              if (res['success'] == false) {
                setSheetState(() => submitting = false);
                if (mounted) {
                  _showSnack(
                      res['message']?.toString() ?? 'Envoi de la note impossible');
                }
                return;
              }
              if (mounted) setState(() => _hasRated = true);
              Navigator.pop(sheetContext);
              _showSnack('Merci pour votre note !');
              _loadDriverRating();
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.slate300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Noter le chauffeur',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          IconButton(
                            onPressed: submitting
                                ? null
                                : () => setSheetState(() => selected = i),
                            iconSize: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              i <= selected
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: i <= selected
                                  ? AppTheme.amber400
                                  : AppTheme.slate300,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentCtrl,
                      enabled: !submitting,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Commentaire (facultatif)',
                        filled: true,
                        fillColor: AppTheme.slate100,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PcButton(
                      'Envoyer',
                      onPressed: selected == 0 ? null : submit,
                      icon: Icons.send_rounded,
                      size: PcButtonSize.lg,
                      block: true,
                      loading: submitting,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    commentCtrl.dispose();
  }

  String _formatNumber(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match[1]} ',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Détail du colis'),
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
        actions: [
          IconButton(
            onPressed: _shareTracking,
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Partager',
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadDetailData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          children: [
            if (_isLoading)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            const SizedBox(height: 10),
            _TrackingHero(
              parcel: _parcel,
              arrival: _arrival,
              eta: _eta,
              price: _price,
            ),
            const SizedBox(height: 12),
            _TagsRow(parcel: _parcel),
            const SizedBox(height: 16),
            _DriverCard(
              name: _driverName,
              phone: _driverPhone,
              garage: _parcel.departureGarageName,
              ratingLabel: _driverRatingLabel,
              onCall: _callDriver,
              onChat: _openChat,
            ),
            const SizedBox(height: 16),
            PcCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  PcListRow(
                    icon: Icons.category_rounded,
                    iconTone: PcTone.primary,
                    title: 'Type',
                    trailing: _InfoValue(value: _parcel.type.label),
                  ),
                  const PcDivider(),
                  PcListRow(
                    icon: Icons.scale_rounded,
                    iconTone: PcTone.primary,
                    title: 'Poids',
                    trailing:
                        _InfoValue(value: _parcel.formattedWeight, mono: true),
                  ),
                  const PcDivider(),
                  PcListRow(
                    icon: Icons.person_pin_rounded,
                    iconTone: PcTone.primary,
                    title: 'Destinataire',
                    trailing: _InfoValue(
                      value: _parcel.receiverName.isEmpty
                          ? 'Non renseigné'
                          : _parcel.receiverName,
                    ),
                  ),
                  const PcDivider(),
                  PcListRow(
                    icon: Icons.call_rounded,
                    iconTone: PcTone.primary,
                    title: 'Téléphone',
                    trailing: _InfoValue(
                      value: _parcel.receiverPhone.isEmpty
                          ? 'Non renseigné'
                          : _parcel.receiverPhone,
                      mono: true,
                    ),
                  ),
                ],
              ),
            ),
            if (_parcel.price != null &&
                _parcel.price! > 0 &&
                (_parcel.paymentStatus != 'completed' &&
                    _parcel.paymentStatus != 'paid'))
              _PaydunyaPayCard(
                parcelId: _parcel.id,
                amount: _parcel.price!,
                trackingNumber: _parcel.trackingNumber,
                apiService: _apiService,
                onDone: _loadDetailData,
              ),
            ..._buildMediaSection(),
            if (_parcel.status.isInProgress && _otpCode != null) ...[
              const SizedBox(height: 18),
              _DeliveryCodeCard(otp: _otpCode!, isLoading: _isLoadingOtp),
            ],
            const SizedBox(height: 18),
            const PcSectionHeader('Suivi'),
            PcCard(
              padding: const EdgeInsets.all(16),
              child: _DesignTimeline(
                parcel: _parcel,
                events: _events,
              ),
            ),
            const SizedBox(height: 16),
            if (_parcel.isDelivered) ...[
              PcCard(
                padding: const EdgeInsets.all(14),
                onTap: _openDeliveryProof,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.green50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preuve de livraison',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Photo, signature et remarque',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_canRateDriver) ...[
              PcButton(
                _hasRated ? 'Chauffeur noté ★' : 'Noter le chauffeur',
                onPressed: _hasRated ? null : _rateDriver,
                icon: Icons.star_rounded,
                variant: PcButtonVariant.amber,
                size: PcButtonSize.lg,
                block: true,
              ),
              const SizedBox(height: 12),
            ],
            if (_isAssignedDriver && _driverStep != null) ...[
              PcButton(
                _driverStep!.label,
                onPressed: _isUpdating
                    ? null
                    : () => _driverStep!.step == 'deliver'
                        ? _openConfirmDelivery()
                        : _advanceStep(_driverStep!.step),
                icon: _driverStep!.icon,
                size: PcButtonSize.lg,
                block: true,
                loading: _isUpdating,
              ),
              const SizedBox(height: 12),
            ] else if (_canConfirmDelivery) ...[
              PcButton(
                'Confirmer la livraison',
                onPressed: _openConfirmDelivery,
                icon: Icons.lock_open_rounded,
                size: PcButtonSize.lg,
                block: true,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: PcButton(
                    'Voir le reçu',
                    onPressed: _showReceipt,
                    icon: Icons.receipt_long_rounded,
                    variant: PcButtonVariant.secondary,
                    block: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _parcel.isDelivered
                      ? PcButton(
                          'Preuve',
                          onPressed: _openDeliveryProof,
                          icon: Icons.verified_rounded,
                          variant: PcButtonVariant.primary,
                          block: true,
                        )
                      : PcButton(
                          'Annuler',
                          onPressed: _parcel.isFinished || _isUpdating
                              ? null
                              : _cancelParcel,
                          icon: Icons.cancel_rounded,
                          variant: PcButtonVariant.danger,
                          loading: _isUpdating,
                          block: true,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingHero extends StatelessWidget {
  final Parcel parcel;
  final String arrival;
  final String eta;
  final String price;

  const _TrackingHero({
    required this.parcel,
    required this.arrival,
    required this.eta,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.brandShadow(),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  parcel.trackingNumber,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _HeroStatusBadge(status: parcel.status),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _RouteEnd(
                  label: 'Départ',
                  city: parcel.departureGarageName,
                  alignEnd: false,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _RouteLine(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RouteEnd(
                  label: 'Arrivée',
                  city: arrival,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMeta(label: 'Distance', value: '240 km'),
              const SizedBox(width: 18),
              _HeroMeta(label: 'Reste', value: eta),
              const SizedBox(width: 18),
              Expanded(
                child: _HeroMeta(label: 'Prix', value: price),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteEnd extends StatelessWidget {
  final String label;
  final String city;
  final bool alignEnd;

  const _RouteEnd({
    required this.label,
    required this.city,
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
            color: Colors.white70,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 2,
            color: Colors.white.withOpacity( 0.42),
          ),
          Positioned(
            left: 34,
            child: Container(
              padding: const EdgeInsets.all(2),
              color: Colors.transparent,
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.mono(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HeroStatusBadge extends StatelessWidget {
  final ParcelStatus status;

  const _HeroStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: colors.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final String name;
  final String phone;
  final String garage;
  final String? ratingLabel;
  final VoidCallback onCall;
  final VoidCallback onChat;

  const _DriverCard({
    required this.name,
    required this.phone,
    required this.garage,
    this.ratingLabel,
    required this.onCall,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return PcCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          PcAvatar(
            name.isEmpty ? 'PC' : name,
            size: 48,
            status: PcAvatarStatus.online,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  ratingLabel != null
                      ? '$garage · $ratingLabel'
                      : '$garage · 4,9 ★ · Camionnette',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PcIconButton(
            Icons.call_rounded,
            variant: PcIconButtonVariant.soft,
            onPressed: phone.isEmpty ? null : onCall,
            tooltip: 'Appeler',
          ),
          const SizedBox(width: 6),
          PcIconButton(
            Icons.chat_rounded,
            variant: PcIconButtonVariant.soft,
            onPressed: onChat,
            tooltip: 'Message',
          ),
        ],
      ),
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SoftIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryLight,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            color: onTap == null ? AppTheme.slate400 : AppTheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _InfoValue extends StatelessWidget {
  final String value;
  final bool mono;

  const _InfoValue({required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: mono
            ? AppTheme.mono(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              )
            : const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
      ),
    );
  }
}

class _DesignTimeline extends StatelessWidget {
  final Parcel parcel;
  final List<ParcelEvent> events;

  const _DesignTimeline({
    required this.parcel,
    required this.events,
  });

  List<_TimelineStep> get _steps {
    if (events.isNotEmpty) {
      final sorted = [...events]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return sorted
          .map(
            (event) => _TimelineStep(
              title: event.status.label,
              subtitle: event.description,
              date: _formatEventDate(event.timestamp),
              done: true,
              color: event.status.color,
            ),
          )
          .toList();
    }

    // Fallback visuel calé sur le Stepper de la maquette quand l'API ne
    // renvoie pas encore d'événements de suivi pour le colis.
    final all = [
      _StepInfo(ParcelStatus.pending, 'Colis créé', parcel.createdAt),
      _StepInfo(ParcelStatus.confirmed, 'Chauffeur assigné', parcel.pickupDate),
      _StepInfo(ParcelStatus.inTransit, 'En route vers la destination', null),
      _StepInfo(ParcelStatus.delivered, 'Remis au destinataire', parcel.deliveryDate),
    ];
    final currentIndex = all.indexWhere((item) => item.status == parcel.status);
    final resolvedIndex = currentIndex < 0 ? 0 : currentIndex;

    return [
      for (var i = 0; i < all.length; i++)
        _TimelineStep(
          title: all[i].status.label,
          subtitle: all[i].label,
          date: all[i].date == null ? '' : _formatEventDate(all[i].date!),
          done: i <= resolvedIndex,
          color: all[i].status.color,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineTile(
            step: steps[i],
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }

  static String _formatEventDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final String date;
  final bool done;
  final Color color;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.done,
    required this.color,
  });
}

class _TimelineTile extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;

  const _TimelineTile({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = step.done ? step.color : AppTheme.slate300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: step.done ? color : AppTheme.cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: step.done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 48,
                  color: color.withOpacity( 0.32),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (step.date.isNotEmpty)
                      Text(
                        step.date,
                        style: AppTheme.mono(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ParcelChatScreen extends StatefulWidget {
  final Parcel parcel;
  final String driverName;
  final String driverPhone;

  const ParcelChatScreen({
    super.key,
    required this.parcel,
    required this.driverName,
    required this.driverPhone,
  });

  @override
  State<ParcelChatScreen> createState() => _ParcelChatScreenState();
}

class _ParcelChatScreenState extends State<ParcelChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Bonjour, je suis en route vers le point de départ.',
      time: '09:34',
      mine: false,
    ),
    const _ChatMessage(
      text: 'Parfait, le colis est prêt.',
      time: '09:36',
      mine: true,
    ),
    const _ChatMessage(
      audioLen: '0:08',
      time: '09:38',
      mine: false,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _callDriver() async {
    if (widget.driverPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: widget.driverPhone);
    await launchUrl(uri);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          time: _formatNow(),
          mine: true,
        ),
      );
      _messageController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _ChatAvatar(name: widget.driverName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.driverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'En ligne',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _SoftIconButton(
              icon: Icons.call_rounded,
              onTap: widget.driverPhone.isEmpty ? null : _callDriver,
            ),
          ),
        ],
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: Column(
        children: [
          _PinnedParcelChip(parcel: widget.parcel),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              itemCount: _messages.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Aujourd’hui',
                        style: TextStyle(
                          color: AppTheme.slate400,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                return _ChatBubble(message: _messages[index - 1]);
              },
            ),
          ),
          _MessageComposer(
            controller: _messageController,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String? text;
  final String? audioLen;
  final String time;
  final bool mine;

  const _ChatMessage({
    this.text,
    this.audioLen,
    required this.time,
    required this.mine,
  });
}

class _ChatAvatar extends StatelessWidget {
  final String name;

  const _ChatAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.primaryLight,
          child: Text(
            initials.isEmpty ? 'PC' : initials,
            style: const TextStyle(
              color: AppTheme.teal700,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: 1,
          child: Container(
            width: 10,
            height: 10,
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

class _PinnedParcelChip extends StatelessWidget {
  final Parcel parcel;

  const _PinnedParcelChip({required this.parcel});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryLight,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.teal100)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.inventory_2_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  parcel.trackingNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    color: AppTheme.teal700,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _MiniStatusBadge(status: parcel.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatusBadge extends StatelessWidget {
  final ParcelStatus status;

  const _MiniStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: status.color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final bubbleColor = mine ? AppTheme.primary : AppTheme.cardColor;
    final textColor = mine ? Colors.white : AppTheme.slate700;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          boxShadow: AppTheme.softShadow(alpha: 0.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.audioLen != null)
              _AudioMessage(
                mine: mine,
                audioLen: message.audioLen!,
              )
            else
              Text(
                message.text ?? '',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: AppTheme.mono(
                color: textColor.withOpacity( 0.62),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioMessage extends StatelessWidget {
  final bool mine;
  final String audioLen;

  const _AudioMessage({required this.mine, required this.audioLen});

  @override
  Widget build(BuildContext context) {
    final color = mine ? Colors.white : AppTheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_circle_rounded, color: color, size: 24),
        const SizedBox(width: 8),
        _MiniWaveform(color: color),
        const SizedBox(width: 8),
        Text(
          audioLen,
          style: AppTheme.mono(
            color: color.withOpacity( 0.82),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MiniWaveform extends StatelessWidget {
  final Color color;

  const _MiniWaveform({required this.color});

  @override
  Widget build(BuildContext context) {
    const heights = [10.0, 16.0, 12.0, 20.0, 14.0, 18.0];
    return Row(
      children: heights
          .map(
            (height) => Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: color.withOpacity( 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MessageComposer extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageComposer({
    required this.controller,
    required this.onSend,
  });

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncTextState);
  }

  @override
  void didUpdateWidget(covariant _MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_syncTextState);
    widget.controller.addListener(_syncTextState);
    _syncTextState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTextState);
    super.dispose();
  }

  void _syncTextState() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText == _hasText) return;
    setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          border: Border(top: BorderSide(color: AppTheme.slate200)),
        ),
        child: Row(
          children: [
            _ComposerIconButton(
              icon: Icons.add_rounded,
              background: Colors.transparent,
              foreground: AppTheme.slate600,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        minLines: 1,
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => widget.onSend(),
                        decoration: const InputDecoration(
                          hintText: 'Votre message…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.mic_rounded,
                      color: AppTheme.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ComposerIconButton(
              icon: Icons.send_rounded,
              background: _hasText ? AppTheme.primary : AppTheme.slate200,
              foreground: _hasText ? Colors.white : AppTheme.slate400,
              onTap: _hasText ? widget.onSend : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  const _ComposerIconButton({
    required this.icon,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: foreground, size: 22),
        ),
      ),
    );
  }
}

class _TagsRow extends StatelessWidget {
  final Parcel parcel;

  const _TagsRow({required this.parcel});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (parcel.isUrgent) const PcTag.express(),
        if (parcel.isInsured)
          const PcTag(
            'Assuré',
            icon: Icons.shield_rounded,
            tone: PcTone.green,
          ),
        PcTag(
          parcel.type.label,
          icon: parcel.type.icon,
          tone: PcTone.primary,
        ),
      ],
    );
  }
}

class _DeliveryCodeCard extends StatelessWidget {
  final String otp;
  final bool isLoading;

  const _DeliveryCodeCard({
    required this.otp,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return PcCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.vpn_key_rounded,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Code de livraison',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        otp,
                        style: AppTheme.mono(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                const SizedBox(height: 4),
                const Text(
                  'Communiquez ce code au livreur pour confirmer la réception',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
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

class _StepInfo {
  final ParcelStatus status;
  final String label;
  final DateTime? date;
  const _StepInfo(this.status, this.label, this.date);
}

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
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

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
      color: AppTheme.slate50,
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
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaydunyaPayCard extends StatefulWidget {
  final String parcelId;
  final double amount;
  final String trackingNumber;
  final ApiService apiService;
  final VoidCallback onDone;

  const _PaydunyaPayCard({
    required this.parcelId,
    required this.amount,
    required this.trackingNumber,
    required this.apiService,
    required this.onDone,
  });

  @override
  State<_PaydunyaPayCard> createState() => _PaydunyaPayCardState();
}

class _PaydunyaPayCardState extends State<_PaydunyaPayCard> {
  bool _loading = false;
  String? _error;
  double _commission = 0;
  double _netAmount = 0;
  double _percentage = 5;

  @override
  void initState() {
    super.initState();
    _loadCommission();
  }

  Future<void> _loadCommission() async {
    if (widget.amount <= 0) return;
    try {
      final estimate = await widget.apiService.estimateCommission(widget.amount);
      if (mounted) {
        setState(() {
          _commission = (estimate['commission'] as num?)?.toDouble() ?? (widget.amount * 0.05).clamp(100.0, 500.0);
          _netAmount = (estimate['netAmount'] as num?)?.toDouble() ?? widget.amount - _commission;
          _percentage = (estimate['percentage'] as num?)?.toDouble() ?? 5;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _commission = (widget.amount * 0.05).clamp(100.0, 500.0);
          _netAmount = widget.amount - _commission;
        });
      }
    }
  }

  String _fcfa(double v) {
    final n = v.toInt();
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return '${b.toString()} FCFA';
  }

  Widget _detailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 12.5, color: AppTheme.textSecondary)),
        Text(value, style: AppTheme.mono(fontSize: 12.5, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Future<void> _pay() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.apiService.createPaydunyaPayment(
        'parcel',
        parcelId: widget.parcelId,
        amount: widget.amount,
      );
      final paymentUrl = result['paymentUrl']?.toString() ?? '';
      if (paymentUrl.isNotEmpty) {
        await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
        widget.onDone();
      } else {
        setState(() => _error = 'URL de paiement introuvable');
      }
    } catch (e) {
      setState(() => _error = 'Erreur lors de la création du paiement');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PcCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.amber50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(Icons.payments_rounded, color: AppTheme.amber600, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Paiement',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Paiement de ${_fcfa(widget.amount)} pour le colis ${widget.trackingNumber}',
            style: GoogleFonts.manrope(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          if (_commission > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.amber50,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.amber100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Commission plateforme (${_percentage.toInt()}%)', '- ${_fcfa(_commission)}', AppTheme.red500),
                  const SizedBox(height: 4),
                  Container(height: 1, color: AppTheme.amber200),
                  const SizedBox(height: 4),
                  _detailRow('Montant reversé au chauffeur', _fcfa(_netAmount), AppTheme.green700),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.red500, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          PcButton(
            _loading ? 'Redirection...' : 'Payer ${_fcfa(widget.amount)} avec PayDunya',
            icon: Icons.payments_rounded,
            block: true,
            loading: _loading,
            onPressed: _loading ? null : _pay,
          ),
        ],
      ),
    );
  }
}
