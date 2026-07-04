// mobile/lib/screens/shared/messages_screen.dart
// Enhanced messaging with price proposals, voice recording, and parcel details.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/parcel.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

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

  String? _currentlyPlayingAudioUrl;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_activePeerId != null) _loadMessages();
      _loadConversations();
    });
    _audioPlayer.onPlayerStateChanged.listen(_onAudioPlayerStateChanged);
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

  Future<void> _acceptPrice(String bidId) async {
    if (_activeParcelId == null) return;
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.acceptBid(_activeParcelId!, bidId);
      if (result['success'] == true) {
        _showSnackBar('Prix accepté avec succès');
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

  Future<void> _showCounterOfferDialog(String bidId, double currentAmount) async {
    final counterPriceController = TextEditingController(text: currentAmount.toInt().toString());
    final counterMessageController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contre-proposition',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: counterPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nouveau prix (FCFA)',
                hintText: 'Ex: 5000',
                filled: true,
                fillColor: AppTheme.slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: counterMessageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message (optionnel)',
                hintText: 'Votre message...',
                filled: true,
                fillColor: AppTheme.slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, {
                'price': counterPriceController.text.trim(),
                'message': counterMessageController.text.trim(),
              });
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (result != null && result['price'] != null) {
      final newPrice = double.tryParse(result['price']);
      if (newPrice != null && newPrice > 0) {
        setState(() => _isLoading = true);
        try {
          final response = await _apiService.negotiateBid(bidId, {
            'price': newPrice.toInt(),
            if (result['message'] != null && (result['message'] as String).isNotEmpty)
              'message': result['message'],
          });
          if (response['success'] == true) {
            _showSnackBar('Contre-proposition envoyée');
            await _loadMessages();
          } else {
            _showSnackBar(response['message']?.toString() ?? 'Erreur lors de la contre-proposition');
          }
        } catch (_) {
          _showSnackBar('Erreur lors de la contre-proposition');
        }
        setState(() => _isLoading = false);
      }
    }
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
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _audioPlayer.stop();
                  setState(() {
                    _activePeerId = null;
                    _activePeerName = null;
                    _activeParcelId = null;
                    _activeParcel = null;
                    _messages = [];
                    _isRecording = false;
                    _showPriceInput = false;
                    _currentlyPlayingAudioUrl = null;
                    _isPlayingAudio = false;
                  });
                  _recordTimer?.cancel();
                  _recordTimer = null;
                  _messageController.clear();
                  _priceController.clear();
                },
              ),
              title: Text(_activePeerName ?? 'Conversation'),
            )
          : AppBar(
              backgroundColor: AppTheme.cardColor,
              title: const Text('Messages',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ),
      body: _activePeerId != null ? _buildChatView() : _buildConversationList(),
    );
  }

  Widget _buildConversationList() {
    if (_isLoading && _conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Aucune conversation',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text('Vos messages apparaîtront ici',
                style: TextStyle(fontSize: 13, color: AppTheme.slate400)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conv = _conversations[index];
          final sender = conv['sender'];
          final receiver = conv['receiver'];
          final user = ref.read(authProvider).user;
          final isReceiver = receiver?['id'] == user?.id;
          final peer = isReceiver ? sender : receiver;
          final peerName = peer?['fullName']?.toString() ?? 'Inconnu';
          final lastMsg = conv['body']?.toString() ?? '';
          final parcel = conv['parcel'];

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary,
              child: Text(
                peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(peerName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              parcel != null
                  ? '#${parcel['trackingNumber']}: $lastMsg'
                  : lastMsg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.slate500, fontSize: 13),
            ),
            trailing: conv['createdAt'] != null
                ? Text(
                    _formatTime(conv['createdAt'].toString()),
                    style: TextStyle(color: AppTheme.slate400, fontSize: 12),
                  )
                : null,
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
    return GestureDetector(
      onTap: _showParcelDetailSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.teal50,
          border: const Border(bottom: BorderSide(color: AppTheme.teal100)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.teal100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2,
                  size: 18, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${parcel.trackingNumber}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                  const SizedBox(height: 2),
                  Text(
                    '${parcel.departureGarageName} → ${parcel.arrivalGarageName ?? "—"}',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('Destinataire: ${parcel.receiverName}',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.slate500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppTheme.slate400),
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
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          border: isMe ? null : Border.all(color: AppTheme.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body,
                style: TextStyle(
                    color: isMe ? Colors.white : AppTheme.textPrimary,
                    fontSize: 14)),
            if (msg['createdAt'] != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(msg['createdAt'].toString()),
                style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withAlpha(180)
                        : AppTheme.slate400),
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

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : AppTheme.amber50,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          border: isMe
              ? null
              : Border.all(color: AppTheme.amber400.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _togglePlayAudio(audioUrl),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withAlpha(40)
                      : AppTheme.amber50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isThisPlaying ? Icons.pause : Icons.play_arrow,
                  size: 20,
                  color: isMe ? Colors.white : AppTheme.amber700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isThisPlaying ? 'Lecture...' : 'Message vocal',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isMe ? Colors.white : AppTheme.amber700),
                ),
                if (msg['createdAt'] != null)
                  Text(
                    _formatTime(msg['createdAt'].toString()),
                    style: TextStyle(
                        fontSize: 10,
                        color: isMe
                            ? Colors.white.withAlpha(180)
                            : AppTheme.slate400),
                  ),
              ],
            ),
          ],
        ),
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
    final formatter = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final formattedAmount =
        amount != null ? formatter.format(amount) : amountStr;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.amber50, AppTheme.green50],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.green500.withAlpha(50), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.amber400.withAlpha(25),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.green100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_offer,
                          size: 13, color: AppTheme.green700),
                      const SizedBox(width: 4),
                      const Text('Proposition de prix',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.green700)),
                    ],
                  ),
                ),
                const Spacer(),
                if (msg['createdAt'] != null)
                  Text(
                    _formatTime(msg['createdAt'].toString()),
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.slate400),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(formattedAmount,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.green700)),
            if (priceMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withAlpha(180),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(priceMessage,
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ),
            ],
            // Action buttons for received price proposals
            if (!isMe && bidId != null && bidId.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: () => _acceptPrice(bidId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.green500,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Accepter'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        onPressed: () =>
                            _showCounterOfferDialog(bidId, amount ?? 0),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.amber700,
                          side: const BorderSide(
                              color: AppTheme.amber400, width: 1.5),
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Contre-proposition'),
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.amber50,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppTheme.red400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Enregistrement... ${_formatRecordDuration(_recordDuration)}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.red400),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.red400,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.stop, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInputRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on,
              size: 20, color: AppTheme.amber400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Montant en FCFA...',
                hintStyle:
                    TextStyle(color: AppTheme.slate400, fontSize: 13),
                filled: true,
                fillColor: AppTheme.slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                isDense: true,
              ),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.amber400,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              color: Colors.white,
              onPressed: _isSending ? () {} : _sendPriceMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: Row(
        children: [
          // Mic button
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isRecording ? AppTheme.red50 : AppTheme.slate50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _isRecording ? Icons.mic_off : Icons.mic,
                size: 22,
                color: _isRecording ? AppTheme.red400 : AppTheme.slate500,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Currency / price button
          GestureDetector(
            onTap: () {
              setState(() {
                _showPriceInput = !_showPriceInput;
                if (!_showPriceInput) {
                  _priceController.clear();
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _showPriceInput
                    ? AppTheme.amber50
                    : AppTheme.slate50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.monetization_on,
                size: 22,
                color: _showPriceInput
                    ? AppTheme.amber500
                    : AppTheme.slate500,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Text input
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Écrivez un message...',
                hintStyle: TextStyle(color: AppTheme.slate400, fontSize: 14),
                filled: true,
                fillColor: AppTheme.slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          const SizedBox(width: 8),

          // Send button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              color: Colors.white,
              onPressed: () {
                if (_isSending) return;
                if (_showPriceInput) {
                  _sendPriceMessage();
                } else {
                  _sendMessage();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
