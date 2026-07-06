// mobile/lib/screens/shared/messages_screen.dart
// Enhanced messaging with price proposals, voice recording, and parcel details.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/parcel.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  /// Ouvre directement le fil de discussion avec ce pair (chauffeur ou client).
  final String? initialPeerId;
  final String? initialPeerName;
  final String? initialParcelId;

  const MessagesScreen({
    super.key,
    this.initialPeerId,
    this.initialPeerName,
    this.initialParcelId,
  });

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _activePeerId;
  String? _activePeerName;
  String? _activeParcelId;
  Parcel? _activeParcel;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _isSending = false;

  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  String? _recordingFilePath;

  bool _showPriceInput = false;
  final _priceController = TextEditingController();
  String? _pendingNegotiateBidId;

  String? _currentlyPlayingAudioUrl;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_activePeerId != null) _loadMessages();
      _loadConversations();
    });
    _audioPlayer.onPlayerStateChanged.listen(_onAudioPlayerStateChanged);

    // Ouverture directe du fil d'un colis (depuis le détail du colis).
    final hasPeer =
        widget.initialPeerId != null && widget.initialPeerId!.isNotEmpty;
    final hasParcel =
        widget.initialParcelId != null && widget.initialParcelId!.isNotEmpty;
    if (hasPeer || hasParcel) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoOpenInitial());
    }
  }

  /// Ouvre directement la discussion pour un colis, sans passer par le
  /// sélecteur : d'abord une conversation existante du colis (historique),
  /// sinon un nouveau fil vide avec l'interlocuteur fourni.
  Future<void> _autoOpenInitial() async {
    final parcelId = widget.initialParcelId;

    // 1) Conversation existante pour ce colis → on l'ouvre telle quelle.
    if (parcelId != null && parcelId.isNotEmpty) {
      await _loadConversations();
      final me = ref.read(authProvider).user;
      for (final conv in _conversations) {
        final convParcelId = conv['parcel']?['id']?.toString();
        if (convParcelId != parcelId) continue;
        final receiver = conv['receiver'];
        final peer =
            receiver?['id'] == me?.id ? conv['sender'] : receiver;
        final peerId = peer?['id']?.toString();
        if (peerId != null && peerId.isNotEmpty) {
          await _openConversation(
            peerId,
            peer?['fullName']?.toString() ??
                widget.initialPeerName ??
                'Conversation',
            parcelId: parcelId,
          );
          return;
        }
      }
    }

    // 2) Pas d'historique : nouveau fil vide avec l'interlocuteur fourni.
    final peerId = widget.initialPeerId;
    if (peerId != null && peerId.isNotEmpty) {
      await _openConversation(
        peerId,
        widget.initialPeerName ?? 'Conversation',
        parcelId: parcelId,
      );
    }
    // 3) Sinon (aucun interlocuteur connu) : on laisse la liste s'afficher.
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _recordTimer?.cancel();
    _messageController.dispose();
    _priceController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onAudioPlayerStateChanged(PlayerState state) {
    if (mounted) {
      setState(() {
        _isPlayingAudio = state == PlayerState.playing;
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _currentlyPlayingAudioUrl = null;
        }
      });
    }
  }

  Future<void> _loadConversations() async {
    try {
      final convs = await _apiService.getConversations();
      if (mounted) {
        setState(() => _conversations = convs);
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    if (_activePeerId == null) return;
    try {
      final msgs = await _apiService.getMessagesThread(
        _activePeerId!,
        parcelId: _activeParcelId,
      );
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _loadParcelDetail() async {
    if (_activeParcelId == null) return;
    try {
      final parcel = await _apiService.getParcelById(_activeParcelId!);
      if (mounted && parcel != null) {
        setState(() => _activeParcel = parcel);
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openConversation(
      String peerId, String peerName, {String? parcelId}) async {
    setState(() {
      _activePeerId = peerId;
      _activePeerName = peerName;
      _activeParcelId = parcelId;
      _activeParcel = null;
      _isLoading = true;
      _showPriceInput = false;
      _pendingNegotiateBidId = null;
      _priceController.clear();
    });
    if (parcelId != null) {
      await _loadParcelDetail();
    }
    await _loadMessages();
    setState(() => _isLoading = false);
  }

  Future<void> _sendMessage({String? audioUrl}) async {
    final body = _messageController.text.trim();
    if ((body.isEmpty && audioUrl == null) ||
        _activePeerId == null ||
        _isSending) return;

    setState(() => _isSending = true);
    final data = <String, dynamic>{
      'receiverId': _activePeerId,
      'body': audioUrl != null ? '' : body,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (_activeParcelId != null) 'parcelId': _activeParcelId,
    };
    await _apiService.sendMessage(data);
    _messageController.clear();
    setState(() {
      _isSending = false;
      _showPriceInput = false;
    });
    _priceController.clear();
    await _loadMessages();
  }

  Future<void> _sendPriceMessage() async {
    final priceText = _priceController.text.trim();
    final messageText = _messageController.text.trim();
    if (priceText.isEmpty || _activePeerId == null || _isSending) return;

    final amount = double.tryParse(priceText);
    if (amount == null || amount <= 0) return;

    final body = messageText.isNotEmpty
        ? '__PRIX__:${amount.toInt()}:$messageText'
        : '__PRIX__:${amount.toInt()}';

    setState(() => _isSending = true);

    if (_pendingNegotiateBidId != null) {
      await _apiService.negotiateBid(_pendingNegotiateBidId!, {
        'price': amount.toInt(),
        if (messageText.isNotEmpty) 'message': messageText,
      });
    }

    final data = <String, dynamic>{
      'receiverId': _activePeerId,
      'body': body,
      if (_activeParcelId != null) 'parcelId': _activeParcelId,
    };
    await _apiService.sendMessage(data);
    _messageController.clear();
    _priceController.clear();
    setState(() {
      _isSending = false;
      _showPriceInput = false;
      _pendingNegotiateBidId = null;
    });
    await _loadMessages();
  }

  Future<void> _startRecording() async {
    if (kIsWeb) {
      _showSnackBar('L\'enregistrement vocal n\'est pas disponible sur le web');
      return;
    }
    if (await _audioRecorder.hasPermission()) {
      try {
        final tempDir = Directory.systemTemp;
        final filePath = '${tempDir.path}/procolis_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _recordingFilePath = filePath;
        await _audioRecorder.start(
          path: filePath,
          encoder: AudioEncoder.aacLc,
          samplingRate: 44100,
        );
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _recordDuration++);
          }
        });
      } catch (e) {
        _showSnackBar('Erreur lors du démarrage de l\'enregistrement');
      }
    } else {
      _showSnackBar('Permission microphone refusée');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;

    if (!_isRecording) return;

    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (path != null && _activePeerId != null) {
      _showSnackBar('Envoi du message vocal...');
      final audioUrl = await _apiService.uploadChatAudio(XFile(path));
      if (audioUrl != null && mounted) {
        await _sendMessage(audioUrl: audioUrl);
      } else {
        _showSnackBar('Erreur lors de l\'envoi du message vocal');
      }
    }
  }

  Future<void> _togglePlayAudio(String url) async {
    if (_currentlyPlayingAudioUrl == url && _isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingAudioUrl = null;
        _isPlayingAudio = false;
      });
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      setState(() {
        _currentlyPlayingAudioUrl = url;
        _isPlayingAudio = true;
      });
    }
  }

  Future<void> _acceptPrice(String bidId, double amount) async {
    if (_activeParcelId == null || _activePeerId == null) return;
    final nf = NumberFormat.decimalPattern('fr_FR');
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.acceptBid(_activeParcelId!, bidId);
      if (result['success'] == true) {
        _showSnackBar('Prix accepté avec succès');
        await _apiService.sendMessage({
          'receiverId': _activePeerId,
          'body': 'J\'accepte le prix de ${nf.format(amount)} FCFA.',
          if (_activeParcelId != null) 'parcelId': _activeParcelId,
        });
        await _loadMessages();
        await _loadParcelDetail();
      } else {
        _showSnackBar(result['message']?.toString() ?? 'Erreur lors de l\'acceptation');
      }
    } catch (_) {
      _showSnackBar('Erreur lors de l\'acceptation');
    }
    setState(() => _isLoading = false);
  }

  void _showCounterOfferInline(String bidId, double currentAmount) {
    final nf = NumberFormat.decimalPattern('fr_FR');
    setState(() {
      _showPriceInput = true;
      _priceController.clear();
      _messageController.text = 'Contre-proposition à ${nf.format(currentAmount)} FCFA : ';
      _pendingNegotiateBidId = bidId;
    });
  }

  void _showParcelDetailSheet() {
    final parcel = _activeParcel;
    if (parcel == null) return;

    final formatter = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Détails du colis',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tracking and status
                    _buildParcelDetailRow(
                        'N° de suivi', parcel.trackingNumber),
                    const SizedBox(height: 8),
                    _buildParcelDetailRow(
                        'Statut', parcel.status.label),
                    const SizedBox(height: 16),

                    // Description
                    if (parcel.description.isNotEmpty) ...[
                      const Text('Description',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.slate500)),
                      const SizedBox(height: 4),
                      Text(parcel.description,
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.textPrimary)),
                      const SizedBox(height: 16),
                    ],

                    // Weight & Type
                    Row(
                      children: [
                        Expanded(
                          child: _buildParcelDetailBox(
                              'Poids', parcel.formattedWeight,
                              Icons.fitness_center),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildParcelDetailBox(
                              'Type', parcel.type.label, parcel.type.icon),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Price info if available
                    if (parcel.price != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildParcelDetailBox('Prix',
                                formatter.format(parcel.price!), Icons.monetization_on),
                          ),
                          if (parcel.negotiatedPrice != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildParcelDetailBox('Prix négocié',
                                  formatter.format(parcel.negotiatedPrice!),
                                  Icons.handshake,
                                  color: AppTheme.green500),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Route
                    const Text('Itinéraire',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.slate500)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.trip_origin,
                            size: 16, color: AppTheme.slate500),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(parcel.departureGarageName,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textPrimary))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.flag,
                            size: 16, color: AppTheme.slate500),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                parcel.arrivalGarageName ?? 'Non défini',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textPrimary))),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Receiver info
                    const Text('Destinataire',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.slate500)),
                    const SizedBox(height: 8),
                    _buildParcelDetailRow('Nom', parcel.receiverName),
                    const SizedBox(height: 4),
                    _buildParcelDetailRow('Téléphone', parcel.receiverPhone),
                    if (parcel.receiverEmail != null &&
                        parcel.receiverEmail!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildParcelDetailRow('Email', parcel.receiverEmail!),
                    ],
                    if (parcel.receiverAddress != null &&
                        parcel.receiverAddress!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildParcelDetailRow(
                          'Adresse', parcel.receiverAddress!),
                    ],
                    const SizedBox(height: 16),

                    // Sender info
                    const Text('Expéditeur',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.slate500)),
                    const SizedBox(height: 8),
                    _buildParcelDetailRow('Nom', parcel.senderName),
                    const SizedBox(height: 4),
                    _buildParcelDetailRow('Téléphone', parcel.senderPhone),
                    const SizedBox(height: 16),

                    // Driver info if assigned
                    if (parcel.hasDriver) ...[
                      const Text('Chauffeur',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.slate500)),
                      const SizedBox(height: 8),
                      _buildParcelDetailRow(
                          'Nom', parcel.driverName ?? ''),
                      if (parcel.driverPhone != null) ...[
                        const SizedBox(height: 4),
                        _buildParcelDetailRow(
                            'Téléphone', parcel.driverPhone!),
                      ],
                      const SizedBox(height: 16),
                    ],

                    // Photos
                    if (parcel.photoUrls.isNotEmpty) ...[
                      const Text('Photos',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.slate500)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: parcel.photoUrls.map((url) {
                          return GestureDetector(
                            onTap: () => _openUrl(url),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(10),
                              child: Image.network(
                                url,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(
                                  width: 80,
                                  height: 80,
                                  color: AppTheme.slate100,
                                  child: const Icon(
                                      Icons.broken_image,
                                      color: AppTheme.slate400),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Videos
                    if (parcel.videoUrls.isNotEmpty) ...[
                      const Text('Vidéos',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.slate500)),
                      const SizedBox(height: 8),
                      ...parcel.videoUrls.map((url) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => _openUrl(url),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.slate50,
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppTheme.slate200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.videocam,
                                      color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Voir la vidéo',
                                      style: TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                  ),
                                  const Icon(Icons.open_in_new,
                                      size: 16,
                                      color: AppTheme.slate400),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Audio messages
                    if (parcel.audioUrls.isNotEmpty) ...[
                      const Text('Messages vocaux',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.slate500)),
                      const SizedBox(height: 8),
                      ...parcel.audioUrls.map((url) {
                        final isThisPlaying =
                            _currentlyPlayingAudioUrl == url &&
                                _isPlayingAudio;
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => _togglePlayAudio(url),
                            child: Container(
                              padding:
                                  const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.amber50,
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppTheme
                                        .amber400
                                        .withAlpha(60)),
                              ),
                              child: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Icon(
                                    isThisPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: AppTheme
                                        .amber700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isThisPlaying
                                        ? 'Lecture...'
                                        : 'Écouter le message vocal',
                                    style: TextStyle(
                                        color: AppTheme
                                            .amber700,
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Dates
                    const Text('Dates',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.slate500)),
                    const SizedBox(height: 8),
                    _buildParcelDetailRow(
                        'Créé le', parcel.formattedDateTime),
                    if (parcel.pickupDate != null) ...[
                      const SizedBox(height: 4),
                      _buildParcelDetailRow(
                        'Ramassage',
                        '${parcel.pickupDate!.day}/${parcel.pickupDate!.month}/${parcel.pickupDate!.year}',
                      ),
                    ],
                    if (parcel.deliveryDate != null) ...[
                      const SizedBox(height: 4),
                      _buildParcelDetailRow(
                          'Livré le', parcel.formattedDeliveryDate),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParcelDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.slate500,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style:
                  TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildParcelDetailBox(
      String label, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color ?? AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.slate500,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color ?? AppTheme.textPrimary)),
        ],
      ),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showSnackBar('Impossible d\'ouvrir le lien');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '${date.day}/${date.month}';
    } catch (_) {
      return '';
    }
  }

  String _formatRecordDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _activePeerId != null
          ? AppBar(
              backgroundColor: AppTheme.cardColor,
              centerTitle: false,
              titleSpacing: 4,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppTheme.slate600,
                onPressed: _closeConversation,
              ),
              title: Row(
                children: [
                  PcAvatar(_activePeerName ?? 'Conversation',
                      size: 34, status: PcAvatarStatus.online),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _activePeerName ?? 'Conversation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                        ),
                        if (_activeParcel != null)
                          Text(
                            '#${_activeParcel!.trackingNumber}',
                            style: AppTheme.mono(
                                fontSize: 11, color: AppTheme.teal600),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : AppBar(
              backgroundColor: AppTheme.cardColor,
              centerTitle: false,
              title: Text('Messages',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: AppTheme.textPrimary)),
            ),
      body: _activePeerId != null ? _buildChatView() : _buildConversationList(),
      // Barre de nav uniquement sur la liste des conversations, pas dans le chat
      bottomNavigationBar:
          _activePeerId != null ? null : const AppBottomNav(),
    );
  }

  void _closeConversation() {
    _audioPlayer.stop();
    setState(() {
      _activePeerId = null;
      _activePeerName = null;
      _activeParcelId = null;
      _activeParcel = null;
      _messages = [];
      _isRecording = false;
      _showPriceInput = false;
      _pendingNegotiateBidId = null;
      _currentlyPlayingAudioUrl = null;
      _isPlayingAudio = false;
    });
    _recordTimer?.cancel();
    _recordTimer = null;
    _messageController.clear();
    _priceController.clear();
  }

  Widget _buildConversationList() {
    if (_isLoading && _conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      return const PcEmptyState(
        icon: Icons.forum_rounded,
        tone: PcTone.primary,
        title: 'Aucune conversation',
        message: 'Vos échanges avec les chauffeurs et clients apparaîtront ici.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const PcDivider(),
        itemBuilder: (context, index) {
          final conv = _conversations[index];
          final sender = conv['sender'];
          final receiver = conv['receiver'];
          final user = ref.read(authProvider).user;
          final isReceiver = receiver?['id'] == user?.id;
          final peer = isReceiver ? sender : receiver;
          final peerName = peer?['fullName']?.toString() ?? 'Inconnu';
          // Compteur de messages non lus pour cette conversation.
          // Utilise le champ fourni par l'API si présent, sinon le dérive
          // (destinataire = moi et message non lu), comme MessagesScreen.tsx.
          final unreadRaw = conv['unreadCount'] ?? conv['unread'];
          final unread = unreadRaw is num
              ? unreadRaw.toInt()
              : (isReceiver && conv['isRead'] != true ? 1 : 0);
          final lastMsg = conv['body']?.toString() ?? '';
          final parcel = conv['parcel'];
          final tracking = parcel?['trackingNumber']?.toString();
          final preview = lastMsg.startsWith('__PRIX__:')
              ? _pricePreview(lastMsg)
              : lastMsg;

          return PcListRow(
            leading: PcAvatar(peerName, size: 46),
            title: peerName,
            subtitle: preview.isEmpty ? 'Nouvelle conversation' : preview,
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (unread > 0) ...[
                  PcBadge(
                    unread > 99 ? '99+' : '$unread',
                    tone: PcTone.primary,
                    variant: PcBadgeVariant.solid,
                  ),
                  const SizedBox(height: 6),
                ],
                if (conv['createdAt'] != null)
                  Text(
                    _formatTime(conv['createdAt'].toString()),
                    style: AppTheme.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate400),
                  ),
                if (tracking != null && tracking.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.teal50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('#$tracking',
                        style: AppTheme.mono(
                            fontSize: 10, color: AppTheme.teal600)),
                  ),
                ],
              ],
            ),
            onTap: () => _openConversation(
              peer?['id']?.toString() ?? '',
              peerName,
              parcelId: parcel?['id']?.toString(),
            ),
          );
        },
      ),
    );
  }

  String _pricePreview(String body) {
    final remaining = body.substring('__PRIX__:'.length);
    final amountStr = remaining.split(':').first;
    final amount = double.tryParse(amountStr);
    final nf = NumberFormat.decimalPattern('fr_FR');
    return amount != null
        ? 'Proposition : ${nf.format(amount)} FCFA'
        : 'Proposition de prix';
  }

  Widget _buildChatView() {
    final user = ref.read(authProvider).user;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Parcel info header
        if (_activeParcel != null) _buildParcelHeader(),

        // Messages list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return _buildMessageBubble(msg, user);
            },
          ),
        ),

        // Recording indicator
        if (_isRecording) _buildRecordingIndicator(),

        // Price input row
        if (_showPriceInput) _buildPriceInputRow(),

        // Input bar
        _buildInputBar(),
      ],
    );
  }

  Widget _buildParcelHeader() {
    final parcel = _activeParcel!;
    final colors = AppTheme.statusColors(parcel.status);
    return GestureDetector(
      onTap: _showParcelDetailSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.teal50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.teal100),
        ),
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  size: 20, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('#${parcel.trackingNumber}',
                          style: AppTheme.mono(
                              fontSize: 12.5, color: AppTheme.teal600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(parcel.status.label,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: colors.foreground)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${parcel.departureGarageName} → ${parcel.arrivalGarageName ?? "—"}',
                    style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.slate600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppTheme.teal600),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, dynamic user) {
    final isMe = msg['senderId'] == user?.id;
    final body = msg['body']?.toString() ?? '';
    final audioUrl = msg['audioUrl']?.toString();
    final bidId = msg['bidId']?.toString() ?? msg['negotiationId']?.toString();
    final hasAudio = audioUrl != null && audioUrl.isNotEmpty;

    if (hasAudio) {
      return _buildAudioBubble(msg, isMe);
    }

    if (body.startsWith('__PRIX__:')) {
      return _buildPriceProposal(msg, isMe, body, bidId);
    }

    return _buildTextBubble(msg, isMe, body);
  }

  Widget _buildTextBubble(Map<String, dynamic> msg, bool isMe, String body) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : AppTheme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppTheme.slate200),
          boxShadow: isMe ? null : AppTheme.shadowXs(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body,
                style: GoogleFonts.manrope(
                    color: isMe ? Colors.white : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.35)),
            if (msg['createdAt'] != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatTime(msg['createdAt'].toString()),
                  style: AppTheme.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isMe
                          ? Colors.white.withAlpha(200)
                          : AppTheme.slate400),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBubble(Map<String, dynamic> msg, bool isMe) {
    final audioUrl = msg['audioUrl']?.toString() ?? '';
    final isThisPlaying =
        _currentlyPlayingAudioUrl == audioUrl && _isPlayingAudio;

    final playBg = isMe ? Colors.white.withAlpha(46) : AppTheme.teal50;
    final playFg = isMe ? Colors.white : AppTheme.primary;
    final waveColor = isMe ? Colors.white.withAlpha(150) : AppTheme.teal100;
    final waveActiveColor = isMe ? Colors.white : AppTheme.primary;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : AppTheme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppTheme.slate200),
          boxShadow: isMe ? null : AppTheme.shadowXs(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _togglePlayAudio(audioUrl),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: playBg, shape: BoxShape.circle),
                child: Icon(
                  isThisPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 22,
                  color: playFg,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildWaveform(
                    active: isThisPlaying,
                    color: waveColor,
                    activeColor: waveActiveColor),
                const SizedBox(height: 6),
                Text(
                  isThisPlaying
                      ? 'Lecture…'
                      : (msg['createdAt'] != null
                          ? _formatTime(msg['createdAt'].toString())
                          : 'Message vocal'),
                  style: AppTheme.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isMe
                          ? Colors.white.withAlpha(200)
                          : AppTheme.slate400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const List<double> _waveHeights = [
    8, 14, 20, 12, 24, 16, 10, 22, 14, 18, 9, 20, 13, 8, 16, 11,
  ];

  Widget _buildWaveform({
    required bool active,
    required Color color,
    required Color activeColor,
  }) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_waveHeights.length, (i) {
          return Container(
            width: 2.5,
            height: _waveHeights[i],
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            decoration: BoxDecoration(
              color: active && i.isEven ? activeColor : color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPriceProposal(
      Map<String, dynamic> msg, bool isMe, String body, String? bidId) {
    final remaining = body.substring('__PRIX__:'.length);
    final parts = remaining.split(':');
    final amountStr = parts.first;
    final priceMessage =
        parts.length > 1 ? parts.sublist(1).join(':') : '';
    final amount = double.tryParse(amountStr);
    final nf = NumberFormat.decimalPattern('fr_FR');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: AppTheme.amber50,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(color: AppTheme.amber100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_rounded,
                    size: 18, color: AppTheme.amber600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isMe ? 'PRIX PROPOSÉ' : 'PROPOSITION DE PRIX',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.amber700,
                        letterSpacing: 0.5),
                  ),
                ),
                if (msg['createdAt'] != null)
                  Text(
                    _formatTime(msg['createdAt'].toString()),
                    style: AppTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.amber500),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  amount != null ? nf.format(amount) : amountStr,
                  style: AppTheme.mono(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.amber600),
                ),
                const SizedBox(width: 4),
                Text('FCFA',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.amber600)),
              ],
            ),
            if (priceMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withAlpha(200),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(priceMessage,
                    style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.slate600)),
              ),
            ],
            if (!isMe && bidId != null && bidId.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PcButton(
                      'Contre-proposer',
                      variant: PcButtonVariant.secondary,
                      size: PcButtonSize.sm,
                      block: true,
                      onPressed: () =>
                          _showCounterOfferInline(bidId, amount ?? 0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PcButton(
                      'Accepter',
                      icon: Icons.check_rounded,
                      size: PcButtonSize.sm,
                      block: true,
                      onPressed: () => _acceptPrice(bidId, amount ?? 0),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.red50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.red100),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppTheme.red400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Enregistrement…',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.red500),
          ),
          const SizedBox(width: 8),
          Text(
            _formatRecordDuration(_recordDuration),
            style: AppTheme.mono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.red500),
          ),
          const Spacer(),
          PcIconButton(
            Icons.stop_rounded,
            variant: PcIconButtonVariant.danger,
            size: PcButtonSize.sm,
            round: true,
            onPressed: _stopRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInputRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: AppTheme.cardColor,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.amber50,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.amber100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded,
                      size: 20, color: AppTheme.amber600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Montant en FCFA…',
                        hintStyle: GoogleFonts.manrope(
                            color: AppTheme.amber500.withAlpha(160),
                            fontSize: 14),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                      style: AppTheme.mono(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.amber700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSendButton(amber: true, onTap: _sendPriceMessage),
        ],
      ),
    );
  }

  Widget _buildSendButton({bool amber = false, required VoidCallback onTap}) {
    final bg = amber ? AppTheme.amber400 : AppTheme.primary;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _isSending ? null : onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: _isSending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: amber ? AppTheme.amberOnFg : Colors.white),
                  )
                : Icon(Icons.send_rounded,
                    size: 20,
                    color: amber ? AppTheme.amberOnFg : Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Add / price toggle button
            PcIconButton(
              Icons.payments_rounded,
              variant: _showPriceInput
                  ? PcIconButtonVariant.soft
                  : PcIconButtonVariant.ghost,
              round: true,
              tooltip: 'Proposer un prix',
              onPressed: () {
                setState(() {
                  _showPriceInput = !_showPriceInput;
                  if (!_showPriceInput) {
                    _priceController.clear();
                  }
                });
              },
            ),
            const SizedBox(width: 4),

            // Pill text field with mic
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.slate50,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Votre message…',
                          hintStyle: GoogleFonts.manrope(
                              color: AppTheme.slate400, fontSize: 14),
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (_showPriceInput) {
                            _sendPriceMessage();
                          } else {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isRecording
                            ? Icons.mic_off_rounded
                            : Icons.mic_none_rounded,
                        size: 22,
                        color: _isRecording
                            ? AppTheme.red400
                            : AppTheme.slate500,
                      ),
                      tooltip: 'Message vocal',
                      onPressed: _isRecording ? _stopRecording : _startRecording,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Solid send button
            _buildSendButton(onTap: () {
              if (_showPriceInput) {
                _sendPriceMessage();
              } else {
                _sendMessage();
              }
            }),
          ],
        ),
      ),
    );
  }
}
