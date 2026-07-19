// mobile/lib/widgets/negotiation_chat_widget.dart
// Widget de chat de négociation réutilisable — aligné sur le web NegotiationChat.
// Supporte messages texte, propositions de prix, enregistrement vocal, détail colis.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/parcel.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

const _prixPrefix = '__PRIX__';

class NegotiationChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;

  final String? parcelId;
  final Parcel? parcel;

  final String? bidId;
  final String? advertisementId;
  final String? offerId;

  final void Function()? onChanged;

  const NegotiationChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.parcelId,
    this.parcel,
    this.bidId,
    this.advertisementId,
    this.offerId,
    this.onChanged,
  });

  @override
  State<NegotiationChatScreen> createState() => _NegotiationChatScreenState();
}

class _NegotiationChatScreenState extends State<NegotiationChatScreen> {
  final ApiService _api = ApiService();
  final _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _msgCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Parcel? _parcel;

  bool _showPrice = false;
  bool _recording = false;
  bool _paused = false;
  int _recordSecs = 0;
  Timer? _recordTimer;
  String? _recordPath;
  String? _playingAudio;

  @override
  void initState() {
    super.initState();
    _parcel = widget.parcel;
    if (_parcel == null && widget.parcelId != null) {
      _loadParcel();
    }
    _loadMessages();
    Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _loadMessages();
    });
    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted && (s == PlayerState.completed || s == PlayerState.stopped)) {
        setState(() => _playingAudio = null);
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _priceCtrl.dispose();
    _scrollCtrl.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadParcel() async {
    if (widget.parcelId == null) return;
    try {
      final p = await _api.getParcelById(widget.parcelId!);
      if (mounted && p != null) setState(() => _parcel = p);
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await _api.getMessagesThread(
        widget.peerId,
        parcelId: widget.parcelId,
      );
      if (mounted) {
        setState(() { _messages = msgs; _loading = false; });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _fcfa(double v) {
    final n = v.toInt();
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  Future<void> _sendText() async {
    final body = _msgCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    _msgCtrl.clear();
    await _send(body: body);
  }

  Future<void> _sendPrice() async {
    final raw = _priceCtrl.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0 || _sending) return;
    final msg = _msgCtrl.text.trim();

    if (widget.bidId != null) {
      await _api.negotiateBid(widget.bidId!, {
        'price': amount.toInt(),
        if (msg.isNotEmpty) 'message': msg,
      });
    } else if (widget.offerId != null && widget.advertisementId != null) {
      await _api.negotiateAdvertisementOffer(
        widget.advertisementId!,
        widget.offerId!,
        {'price': amount.toInt(), if (msg.isNotEmpty) 'message': msg},
      );
    }

    final body = '$_prixPrefix:${amount.toInt()}${msg.isNotEmpty ? ':$msg' : ''}';
    _msgCtrl.clear();
    _priceCtrl.clear();
    setState(() => _showPrice = false);
    await _send(body: body);
  }

  Future<void> _send({String? body, String? audioUrl}) async {
    setState(() => _sending = true);
    await _api.sendMessage({
      'receiverId': widget.peerId,
      if (body != null) 'body': body,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (widget.parcelId != null) 'parcelId': widget.parcelId,
    });
    await _loadMessages();
    widget.onChanged?.call();
    if (mounted) setState(() => _sending = false);
  }

  void _handleAcceptPrice(int amount) async {
    final body = '$_prixPrefix:$amount:Accepté à $_fcfa(amount.toDouble()) FCFA';
    await _send(body: body);
    if (widget.bidId != null) {
      await _api.negotiateBid(widget.bidId!, {
        'price': amount, 'message': 'Offre acceptée',
      });
    }
    widget.onChanged?.call();
  }

  void _handleCounterPrice(int amount) {
    setState(() {
      _showPrice = true;
      _priceCtrl.clear();
      _msgCtrl.text = 'Contre-proposition à ${_fcfa(amount.toDouble())} FCFA : ';
    });
  }

  // --- Voice recording ---
  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      try {
        final dir = Directory.systemTemp;
        final path = '${dir.path}/nego_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _recordPath = path;
        await _audioRecorder.start(
          path: path, encoder: AudioEncoder.aacLc, samplingRate: 44100,
        );
        setState(() { _recording = true; _paused = false; _recordSecs = 0; });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordSecs++);
        });
      } catch (_) {}
    }
  }

  Future<void> _pauseRecording() async {
    _recordTimer?.cancel();
    try {
      await _audioRecorder.pause();
      setState(() => _paused = true);
    } catch (_) {}
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      setState(() => _paused = false);
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSecs++);
      });
    } catch (_) {}
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final p = await _audioRecorder.stop();
      if (p != null && mounted) {
        setState(() { _recording = false; _paused = false; });
        final file = XFile(p);
        final url = await _api.uploadFile(file: file, mediaType: 'audio');
        if (url != null) await _send(audioUrl: url);
      }
    } catch (_) {
      if (mounted) setState(() { _recording = false; _paused = false; });
    }
  }

  void _cancelRecording() {
    _recordTimer?.cancel();
    _audioRecorder.stop();
    setState(() { _recording = false; _paused = false; });
  }

  Future<void> _toggleAudio(String url) async {
    if (_playingAudio == url) {
      await _audioPlayer.stop();
      setState(() => _playingAudio = null);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      setState(() => _playingAudio = url);
    }
  }

  void _showParcelDetail() {
    if (_parcel == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_parcel!.trackingNumber,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_parcel!.description.isNotEmpty)
                _detailRow('Description', _parcel!.description),
              _detailRow('Poids', _parcel!.formattedWeight),
              _detailRow('Type', _parcel!.type.label),
              _detailRow('Statut', _parcel!.status.label),
              if (_parcel!.receiverName.isNotEmpty)
                _detailRow('Destinataire', _parcel!.receiverName),
              if (_parcel!.receiverPhone.isNotEmpty)
                _detailRow('Tél', _parcel!.receiverPhone),
              if (_parcel!.receiverAddress != null &&
                  _parcel!.receiverAddress!.isNotEmpty)
                _detailRow('Adresse', _parcel!.receiverAddress!),
              if (_parcel!.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Photos',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Wrap(
                  spacing: 8,
                  children: _parcel!.photoUrls
                      .map((u) => Image.network(u, width: 72, height: 72,
                          fit: BoxFit.cover))
                      .toList(),
                ),
              ],
              if (_parcel!.audioUrls.isNotEmpty)
                ..._parcel!.audioUrls.map((u) => _audioBubble(u)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _audioBubble(String url) {
    final playing = _playingAudio == url;
    return GestureDetector(
      onTap: () => _toggleAudio(url),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.slate100,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: AppTheme.teal600, size: 22),
            const SizedBox(width: 6),
            Text(playing ? 'Lecture…' : 'Message vocal',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.peerName,
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          if (_parcel != null) _buildParcelHeader(),
          Expanded(child: _buildMessages()),
          if (_showPrice) _buildPriceBar(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildParcelHeader() {
    final p = _parcel!;
    return GestureDetector(
      onTap: _showParcelDetail,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.slate50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.teal50,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(p.trackingNumber,
                  style: AppTheme.mono(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppTheme.teal600)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                [p.departureGarageName, p.arrivalGarageName]
                    .where((e) => e != null && e.isNotEmpty).join(' → '),
                style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppTheme.slate700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.info_outline, size: 18, color: AppTheme.teal500),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum, size: 32, color: AppTheme.slate300),
            const SizedBox(height: 8),
            Text('Démarrez la négociation avec ${widget.peerName}.',
                style: GoogleFonts.manrope(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        final body = m['body']?.toString() ?? '';
        final audioUrl = m['audioUrl']?.toString();
        final time = _formatTime(m['createdAt']?.toString());
        final mine = m['senderId']?.toString() == widget.peerId ? false : true;
        final priceData = _parsePrice(body);

        if (priceData != null) {
          return _PriceBubble(
            amount: priceData.amount,
            message: priceData.message,
            mine: mine,
            time: time,
            onAccept: mine ? null : () => _handleAcceptPrice(priceData.amount),
            onCounter: mine ? null : () => _handleCounterPrice(priceData.amount),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MsgBubble(
            body: body,
            audioUrl: audioUrl,
            playingAudio: _playingAudio,
            mine: mine,
            time: time,
            onPlayAudio: (u) => _toggleAudio(u),
          ),
        );
      },
    );
  }

  Widget _buildPriceBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      color: AppTheme.cardColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Montant FCFA',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(99),
                  borderSide: const BorderSide(color: AppTheme.amber400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(99),
                  borderSide: const BorderSide(color: AppTheme.amber400),
                ),
                filled: true,
                fillColor: AppTheme.amber50,
              ),
              style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendPrice,
            child: Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                color: AppTheme.amber500, shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: _recording
          ? Row(
              children: [
                GestureDetector(
                  onTap: _cancelRecording,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.slate100, shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _paused ? AppTheme.amber50 : AppTheme.red50,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                              color: _paused ? AppTheme.amber500 : AppTheme.red500,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _paused ? 'En pause ${_recordSecs}s' : 'Enregistrement... ${_recordSecs}s',
                          style: TextStyle(
                            color: _paused ? AppTheme.amber500 : AppTheme.red500,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_paused)
                  GestureDetector(
                    onTap: _resumeRecording,
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(
                        color: AppTheme.teal500, shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _pauseRecording,
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(
                        color: AppTheme.amber500, shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pause_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _stopRecording,
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(
                      color: AppTheme.teal500, shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showPrice = !_showPrice),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _showPrice ? AppTheme.amber500 : AppTheme.slate100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.payments,
                        color: _showPrice ? Colors.white : AppTheme.textSecondary, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    onSubmitted: (_) =>
                        _showPrice ? _sendPrice() : _sendText(),
                    decoration: InputDecoration(
                      hintText: 'Message à ${widget.peerName}...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(99),
                        borderSide: const BorderSide(color: AppTheme.slate200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(99),
                        borderSide: const BorderSide(color: AppTheme.slate200),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_msgCtrl.text.trim().isNotEmpty)
                  GestureDetector(
                    onTap: _showPrice ? _sendPrice : _sendText,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _showPrice ? AppTheme.amber500 : AppTheme.teal500,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _startRecording,
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(
                        color: AppTheme.teal500, shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic, color: Colors.white, size: 22),
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}

({int amount, String? message})? _parsePrice(String body) {
  if (!body.startsWith(_prixPrefix)) return null;
  final parts = body.substring(_prixPrefix.length + 1).split(':');
  final a = int.tryParse(parts[0]);
  if (a == null || a <= 0) return null;
  return (amount: a, message: parts.length > 1 ? parts.sublist(1).join(':').trim() : null);
}

class _MsgBubble extends StatelessWidget {
  final String body;
  final String? audioUrl;
  final String? playingAudio;
  final bool mine;
  final String time;
  final void Function(String) onPlayAudio;

  const _MsgBubble({
    required this.body,
    this.audioUrl,
    this.playingAudio,
    required this.mine,
    required this.time,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: EdgeInsets.all(body.isNotEmpty ? 10 : 6),
        decoration: BoxDecoration(
          color: mine ? AppTheme.teal500 : AppTheme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
          border: mine ? null : Border.all(color: AppTheme.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (body.isNotEmpty)
              Text(body,
                  style: GoogleFonts.manrope(
                      fontSize: 13, fontWeight: FontWeight.w500,
                      color: mine ? Colors.white : AppTheme.slate700)),
            if (audioUrl != null && audioUrl!.isNotEmpty)
              GestureDetector(
                onTap: () => onPlayAudio(audioUrl!),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      playingAudio == audioUrl
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      color: mine ? Colors.white : AppTheme.teal600, size: 22),
                    const SizedBox(width: 4),
                    Text(playingAudio == audioUrl ? 'Lecture…' : 'Message vocal',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: mine ? Colors.white70 : AppTheme.textSecondary)),
                  ],
                ),
              ),
            Text(time,
                style: TextStyle(
                    fontSize: 9.5,
                    color: mine ? Colors.white60 : AppTheme.slate400)),
          ],
        ),
      ),
    );
  }
}

class _PriceBubble extends StatelessWidget {
  final int amount;
  final String? message;
  final bool mine;
  final String time;
  final VoidCallback? onAccept;
  final VoidCallback? onCounter;

  const _PriceBubble({
    required this.amount,
    this.message,
    required this.mine,
    required this.time,
    this.onAccept,
    this.onCounter,
  });

  String _fcfa(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.amber50,
          border: Border.all(color: AppTheme.amber100),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments, size: 18, color: AppTheme.amber600),
                const SizedBox(width: 6),
                Text(mine ? 'Prix proposé' : 'Proposition de prix',
                    style: GoogleFonts.manrope(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppTheme.amber700)),
              ],
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: _fcfa(amount),
                    style: AppTheme.mono(
                        fontSize: 24, fontWeight: FontWeight.w800,
                        color: AppTheme.amber600),
                  ),
                  const TextSpan(
                    text: ' FCFA',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppTheme.amber600),
                  ),
                ],
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message!,
                  style: GoogleFonts.manrope(
                      fontSize: 13, color: AppTheme.slate700)),
            ],
            if (!mine && onAccept != null && onCounter != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  PcButton('Contre-proposition',
                      variant: PcButtonVariant.secondary,
                      size: PcButtonSize.sm, onPressed: onCounter),
                  const SizedBox(width: 8),
                  PcButton('Accepter', icon: Icons.check_rounded,
                      size: PcButtonSize.sm, onPressed: onAccept),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(time,
                  style: const TextStyle(
                      fontSize: 9.5, color: AppTheme.amber500)),
            ),
          ],
        ),
      ),
    );
  }
}
