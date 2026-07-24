// mobile/lib/screens/shared/admin_support_screen.dart
// Gestion des conversations de support côté admin / super-admin.
// Aligné sur la webapp AdminSupportScreen.tsx : lister les conversations,
// ouvrir un fil, répondre en tant que support (texte + vocal + photo + vidéo).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../widgets/pc_components.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  final ApiService _api = ApiService();
  final _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isThreadLoading = false;
  bool _isSending = false;
  bool _isBusyMedia = false;
  Timer? _pollTimer;

  // Conversation active
  String? _activeSupportUserId;
  String? _activeUserId;
  String? _activeUserName;
  String? _activeSupportName;

  // Enregistrement vocal
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  // Lecture audio
  String? _currentlyPlayingAudioUrl;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_activeUserId != null) _loadThread();
      _loadConversations();
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlayingAudio = state == PlayerState.playing;
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _currentlyPlayingAudioUrl = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _recordTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final convs = await _api.adminSupportConversations();
      if (mounted) {
        setState(() {
          _conversations = convs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadThread() async {
    if (_activeSupportUserId == null || _activeUserId == null) return;
    try {
      final msgs =
          await _api.adminSupportThread(_activeSupportUserId!, _activeUserId!);
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollToBottom();
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

  Future<void> _openConversation(Map<String, dynamic> conv) async {
    final user = conv['user'] as Map<String, dynamic>?;
    final support = conv['supportUser'] as Map<String, dynamic>?;
    final userId = (user?['id'] ?? conv['id'])?.toString();
    final supportUserId = support?['id']?.toString();
    if (userId == null || supportUserId == null) return;

    setState(() {
      _activeUserId = userId;
      _activeSupportUserId = supportUserId;
      _activeUserName = user?['fullName']?.toString() ?? 'Utilisateur';
      _activeSupportName = support?['fullName']?.toString() ?? 'Support';
      _messages = [];
      _isThreadLoading = true;
    });
    await _loadThread();
    if (mounted) setState(() => _isThreadLoading = false);
  }

  void _closeConversation() {
    _audioPlayer.stop();
    setState(() {
      _activeUserId = null;
      _activeSupportUserId = null;
      _activeUserName = null;
      _activeSupportName = null;
      _messages = [];
      _isRecording = false;
      _isPaused = false;
      _currentlyPlayingAudioUrl = null;
      _isPlayingAudio = false;
    });
    _recordTimer?.cancel();
    _recordTimer = null;
    _messageController.clear();
  }

  Future<void> _sendReply({
    String? audioUrl,
    String? photoUrl,
    String? videoUrl,
  }) async {
    final body = _messageController.text.trim();
    final hasAttachment =
        audioUrl != null || photoUrl != null || videoUrl != null;
    if ((body.isEmpty && !hasAttachment) ||
        _activeSupportUserId == null ||
        _activeUserId == null ||
        _isSending) return;

    setState(() => _isSending = true);
    final data = <String, dynamic>{
      'supportUserId': _activeSupportUserId,
      'receiverId': _activeUserId,
      'body': hasAttachment ? '' : body,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
    };
    final result = await _api.adminSupportReply(data);
    if (result['success'] == false && mounted) {
      _showSnackBar(result['message']?.toString() ?? "Échec de l'envoi.");
      setState(() => _isSending = false);
      return;
    }
    _messageController.clear();
    if (mounted) setState(() => _isSending = false);
    await _loadThread();
  }

  // --------- Pièces jointes ---------

  Future<void> _pickAndSendPhoto(ImageSource source) async {
    if (_isBusyMedia) return;
    try {
      final image =
          await _imagePicker.pickImage(source: source, imageQuality: 80);
      if (image == null) return;
      setState(() => _isBusyMedia = true);
      final url = await _api.uploadChatPhoto(image);
      if (url != null && mounted) {
        await _sendReply(photoUrl: url);
      } else if (mounted) {
        _showSnackBar("Erreur lors de l'envoi de la photo");
      }
    } catch (_) {
      if (mounted) _showSnackBar('Erreur lors de la sélection de la photo');
    } finally {
      if (mounted) setState(() => _isBusyMedia = false);
    }
  }

  Future<void> _pickAndSendVideo() async {
    if (_isBusyMedia) return;
    try {
      final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      setState(() => _isBusyMedia = true);
      final url = await _api.uploadChatVideo(video);
      if (url != null && mounted) {
        await _sendReply(videoUrl: url);
      } else if (mounted) {
        _showSnackBar("Erreur lors de l'envoi de la vidéo");
      }
    } catch (_) {
      if (mounted) _showSnackBar('Erreur lors de la sélection de la vidéo');
    } finally {
      if (mounted) setState(() => _isBusyMedia = false);
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galerie photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_rounded),
              title: const Text('Vidéo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  // --------- Enregistrement vocal ---------

  Future<void> _startRecording() async {
    if (kIsWeb) {
      _showSnackBar("L'enregistrement vocal n'est pas disponible sur le web");
      return;
    }
    if (await _audioRecorder.hasPermission()) {
      try {
        final tempDir = Directory.systemTemp;
        final filePath =
            '${tempDir.path}/sendprocolis_support_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          path: filePath,
          encoder: AudioEncoder.aacLc,
          samplingRate: 44100,
        );
        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordDuration = 0;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordDuration++);
        });
      } catch (_) {
        _showSnackBar("Erreur lors du démarrage de l'enregistrement");
      }
    } else {
      _showSnackBar('Permission microphone refusée');
    }
  }

  Future<void> _pauseRecording() async {
    _recordTimer?.cancel();
    try {
      await _audioRecorder.pause();
      setState(() => _isPaused = true);
    } catch (_) {}
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      setState(() => _isPaused = false);
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordDuration++);
      });
    } catch (_) {}
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    if (!_isRecording) return;
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
    if (path != null) {
      _showSnackBar('Envoi du message vocal...');
      final audioUrl = await _api.uploadChatAudio(XFile(path));
      if (audioUrl != null && mounted) {
        await _sendReply(audioUrl: audioUrl);
      } else if (mounted) {
        _showSnackBar("Erreur lors de l'envoi du message vocal");
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

  // --------- Helpers ---------

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showSnackBar("Impossible d'ouvrir le lien");
    }
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
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        centerTitle: false,
        titleSpacing: _activeUserId != null ? 4 : 16,
        leading: _activeUserId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppTheme.slate600,
                onPressed: _closeConversation,
              )
            : null,
        title: _activeUserId != null
            ? Row(
                children: [
                  PcAvatar(_activeUserName ?? 'Utilisateur',
                      size: 34, status: PcAvatarStatus.online),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _activeUserName ?? 'Utilisateur',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                        ),
                        Text(
                          'via ${_activeSupportName ?? "Support"}',
                          style: AppFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.slate500),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Text('Support',
                style: AppFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppTheme.textPrimary)),
      ),
      body: _activeUserId != null ? _buildThreadView() : _buildConversationList(),
    );
  }

  Widget _buildConversationList() {
    if (_isLoading && _conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conversations.isEmpty) {
      return const PcEmptyState(
        icon: Icons.support_agent_rounded,
        tone: PcTone.primary,
        title: 'Aucune conversation',
        message: 'Les demandes de support des utilisateurs apparaîtront ici.',
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
          final user = conv['user'] as Map<String, dynamic>?;
          final support = conv['supportUser'] as Map<String, dynamic>?;
          final userName = user?['fullName']?.toString() ?? 'Utilisateur';
          final supportName = support?['fullName']?.toString() ?? 'Support';
          final last =
              (conv['lastMessage'] ?? conv['body'])?.toString() ?? '';
          final count = conv['messageCount'];
          final lastAgent =
              (conv['lastAgent'] as Map<String, dynamic>?)?['fullName']?.toString();
          final agents = (conv['agents'] as List?)?.length ?? 0;
          final unread = conv['isRead'] != true &&
              conv['receiverId']?.toString() == support?['id']?.toString();

          return PcListRow(
            leading: PcAvatar(userName, size: 46),
            title: userName,
            subtitle: last.isEmpty ? 'Nouvelle demande' : last,
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (unread) ...[
                  const PcBadge('Nouveau',
                      tone: PcTone.primary, variant: PcBadgeVariant.solid),
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
                const SizedBox(height: 6),
                Text(
                  'via $supportName · ${count ?? 0} msg',
                  style: AppFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.slate400),
                ),
                if (lastAgent != null && lastAgent.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.teal50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined,
                            size: 11, color: AppTheme.teal600),
                        const SizedBox(width: 3),
                        Text(
                          agents > 1 ? '$lastAgent +${agents - 1}' : lastAgent,
                          style: AppFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.teal600),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            onTap: () => _openConversation(conv),
          );
        },
      ),
    );
  }

  Widget _buildThreadView() {
    if (_isThreadLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const PcEmptyState(
                  icon: Icons.forum_rounded,
                  tone: PcTone.primary,
                  title: 'Aucun message',
                  message: 'Répondez pour démarrer la conversation.',
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) =>
                      _buildMessageBubble(_messages[index]),
                ),
        ),
        if (_isRecording) _buildRecordingIndicator(),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    // Message "de moi" = envoyé par l'utilisateur de support (je réponds AS support).
    final isMe = msg['senderId']?.toString() == _activeSupportUserId;
    final body = msg['body']?.toString() ?? '';
    final audioUrl = msg['audioUrl']?.toString();
    final photoUrl = msg['photoUrl']?.toString();
    final videoUrl = msg['videoUrl']?.toString();
    final hasAudio = audioUrl != null && audioUrl.isNotEmpty;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;

    final Widget bubble;
    if (hasPhoto) {
      bubble = _buildMediaBubble(msg, isMe, body, photo: photoUrl);
    } else if (hasVideo) {
      bubble = _buildMediaBubble(msg, isMe, body, video: videoUrl);
    } else if (hasAudio) {
      bubble = _buildAudioBubble(msg, isMe, audioUrl);
    } else {
      bubble = _buildTextBubble(msg, isMe, body);
    }

    // Traçabilité : sur une réponse du support, on affiche l'agent réel.
    final agentName =
        (msg['handledBy'] as Map<String, dynamic>?)?['fullName']?.toString();
    if (isMe && agentName != null && agentName.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.badge_outlined,
                    size: 11, color: AppTheme.slate400),
                const SizedBox(width: 3),
                Text(
                  agentName,
                  style: AppFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate500),
                ),
              ],
            ),
          ),
          bubble,
        ],
      );
    }
    return bubble;
  }

  BoxDecoration _bubbleDecoration(bool isMe) => BoxDecoration(
        color: isMe ? AppTheme.primary : AppTheme.cardColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        border: isMe ? null : Border.all(color: AppTheme.slate200),
        boxShadow: isMe ? null : AppTheme.shadowXs(),
      );

  Widget _timestamp(Map<String, dynamic> msg, bool isMe) {
    if (msg['createdAt'] == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          _formatTime(msg['createdAt'].toString()),
          style: AppTheme.mono(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isMe ? Colors.white.withAlpha(200) : AppTheme.slate400),
        ),
      ),
    );
  }

  Widget _buildTextBubble(Map<String, dynamic> msg, bool isMe, String body) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: _bubbleDecoration(isMe),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body,
                style: AppFonts.manrope(
                    color: isMe ? Colors.white : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.35)),
            _timestamp(msg, isMe),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBubble(Map<String, dynamic> msg, bool isMe, String url) {
    final isThisPlaying = _currentlyPlayingAudioUrl == url && _isPlayingAudio;
    final playBg = isMe ? Colors.white.withAlpha(46) : AppTheme.teal50;
    final playFg = isMe ? Colors.white : AppTheme.primary;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: _bubbleDecoration(isMe),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _togglePlayAudio(url),
              child: Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(color: playBg, shape: BoxShape.circle),
                child: Icon(
                    isThisPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 22,
                    color: playFg),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isThisPlaying
                  ? 'Lecture…'
                  : (msg['createdAt'] != null
                      ? _formatTime(msg['createdAt'].toString())
                      : 'Message vocal'),
              style: AppTheme.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color:
                      isMe ? Colors.white.withAlpha(220) : AppTheme.slate500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaBubble(Map<String, dynamic> msg, bool isMe, String body,
      {String? photo, String? video}) {
    final url = photo ?? video ?? '';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: body.isNotEmpty
            ? const EdgeInsets.all(10)
            : const EdgeInsets.all(4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: _bubbleDecoration(isMe),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _openUrl(url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: photo != null
                    ? Image.network(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: AppTheme.slate100,
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      )
                    : Container(
                        height: 160,
                        width: MediaQuery.of(context).size.width * 0.6,
                        color: AppTheme.slate900,
                        child: const Center(
                          child: Icon(Icons.play_circle_fill,
                              size: 46, color: Colors.white70),
                        ),
                      ),
              ),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(body,
                  style: AppFonts.manrope(
                      color: isMe ? Colors.white : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.35)),
            ],
            _timestamp(msg, isMe),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.cardColor,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppTheme.slate500,
            onPressed: _cancelRecording,
          ),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _isPaused
                    ? AppTheme.amber50
                    : AppTheme.red50,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle,
                      size: 10,
                      color: _isPaused ? AppTheme.amber500 : AppTheme.red500),
                  const SizedBox(width: 8),
                  Text(
                    '${_isPaused ? "En pause" : "Enregistrement..."} ${_formatRecordDuration(_recordDuration)}',
                    style: AppFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            _isPaused ? AppTheme.amber700 : AppTheme.red500),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(_isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded),
            color: AppTheme.primary,
            onPressed: _isPaused ? _resumeRecording : _pauseRecording,
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: AppTheme.primary,
            onPressed: _stopAndSendRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: AppTheme.slate600,
              onPressed: (_isBusyMedia || _isRecording) ? null : _showMediaPicker,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Répondre à ${_activeUserName ?? "l'utilisateur"}...',
                  filled: true,
                  fillColor: AppTheme.slate50,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: AppTheme.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: AppTheme.slate200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 6),
            _messageController.text.trim().isNotEmpty
                ? _circleButton(
                    icon: Icons.send_rounded,
                    bg: AppTheme.primary,
                    fg: Colors.white,
                    onTap: _isSending ? null : () => _sendReply(),
                  )
                : _circleButton(
                    icon: Icons.mic_rounded,
                    bg: AppTheme.primary,
                    fg: Colors.white,
                    onTap: _isRecording ? null : _startRecording,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color bg,
    required Color fg,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: 22),
      ),
    );
  }
}
