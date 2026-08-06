// mobile/lib/widgets/negotiation_chat_widget.dart
// Widget de négociation — aligné sur le nouveau système de négociation.
// Affiche les propositions de prix (historique de négociation),
// la dernière proposition en évidence, boutons Accepter/Contre-proposer,
// et le chat textuel.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/parcel.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

class NegotiationChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;

  final String? parcelId;
  final Parcel? parcel;

  final String? bidId;
  final String? advertisementId;
  final String? offerId;

  final String? role;

  final bool isOwner;

  final void Function()? onChanged;
  final void Function(bool finalized)? onNegotiationFinalized;

  const NegotiationChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.parcelId,
    this.parcel,
    this.bidId,
    this.advertisementId,
    this.offerId,
    this.role,
    this.isOwner = false,
    this.onChanged,
    this.onNegotiationFinalized,
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
  List<BidNegotiation> _negotiations = [];
  bool _loading = true;
  bool _loadingMessages = false;
  bool _sending = false;
  bool _accepting = false;
  Parcel? _parcel;

  bool _showPrice = false;
  bool _recording = false;
  bool _paused = false;
  int _recordSecs = 0;
  Timer? _pollTimer;
  Timer? _recordTimer;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  String? _playingAudio;

  String? _lastProposedBy;
  double _lastPrice = 0;

  @override
  void initState() {
    super.initState();
    _parcel = widget.parcel;
    if (_parcel == null && widget.parcelId != null) {
      _loadParcel();
    }
    _loadMessages();
    _loadNegotiations();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _loadMessages();
        _loadNegotiations();
      }
    });
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted && (s == PlayerState.completed || s == PlayerState.stopped)) {
        setState(() => _playingAudio = null);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _recordTimer?.cancel();
    _playerStateSubscription?.cancel();
    _msgCtrl.dispose();
    _priceCtrl.dispose();
    _scrollCtrl.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadParcel() async {
    if (widget.parcelId == null || widget.parcelId!.isEmpty) return;
    if (widget.advertisementId != null && widget.parcelId == widget.advertisementId) return;
    try {
      final p = await _api.getParcelById(widget.parcelId!);
      if (mounted && p != null) setState(() => _parcel = p);
    } catch (error, stackTrace) {
      debugPrint(
        'NegotiationChatScreen: chargement du colis impossible '
        '($error)\n$stackTrace',
      );
    }
  }

  Future<void> _loadNegotiations() async {
    if (_loading) return;
    try {
      List<BidNegotiation> negotiations = [];
      if (widget.bidId != null) {
        final raw = await _api.getBidNegotiations(widget.bidId!);
        negotiations = raw.map((j) => BidNegotiation.fromJson(j)).toList();
      } else if (widget.offerId != null && widget.advertisementId != null) {
        final raw = await _api.getOfferNegotiations(
            widget.advertisementId!, widget.offerId!);
        negotiations = raw.map((j) => BidNegotiation.fromJson(j)).toList();
      }

      if (mounted && negotiations.isNotEmpty) {
        final last = negotiations.last;
        setState(() {
          _negotiations = negotiations;
          _lastPrice = last.price;
          _lastProposedBy = last.authorRole;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'NegotiationChatScreen: chargement negociations impossible '
        '($error)\n$stackTrace',
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMessages() async {
    if (_loadingMessages) return;
    _loadingMessages = true;
    try {
      final msgs = await _api.getMessagesThread(
        widget.peerId,
        parcelId: widget.parcelId,
      );
      if (mounted) {
        setState(() { _messages = msgs; });
        _scrollToBottom();
      }
    } catch (error, stackTrace) {
      debugPrint(
        'NegotiationChatScreen: chargement des messages impossible '
        '($error)\n$stackTrace',
      );
    } finally {
      _loadingMessages = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

  bool get _canAccept {
    if (_lastProposedBy == null || _negotiations.isEmpty) return false;
    if (!_isNegotiationActive) return false;
    if (widget.role != null) return _lastProposedBy != widget.role;
    return widget.isOwner;
  }

  bool get _isNegotiationActive {
    if (_negotiations.isEmpty) return true;
    return !_negotiations.any((n) => n.isAccepted);
  }

  // --- Text chat ---

  Future<void> _sendText() async {
    final body = _msgCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    _msgCtrl.clear();
    await _send(body: body);
  }

  // --- Price proposal ---

  Future<void> _sendPrice() async {
    final raw = _priceCtrl.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0 || _sending) return;
    final msg = _msgCtrl.text.trim();

    if (widget.bidId != null) {
      if (widget.role == 'driver') {
        await _api.driverRespondToBid(widget.bidId!, {
          'action': 'counter',
          'price': amount.toInt(),
          if (msg.isNotEmpty) 'message': msg,
        });
      } else {
        await _api.negotiateBid(widget.bidId!, {
          'price': amount.toInt(),
          if (msg.isNotEmpty) 'message': msg,
        });
      }
    } else if (widget.offerId != null && widget.advertisementId != null) {
      await _api.negotiateAdvertisementOffer(
        widget.advertisementId!,
        widget.offerId!,
        {'price': amount.toInt(), if (msg.isNotEmpty) 'message': msg},
      );
    }

    _msgCtrl.clear();
    _priceCtrl.clear();
    setState(() => _showPrice = false);
    await _loadNegotiations();
    widget.onChanged?.call();
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
    setState(() => _sending = false);
  }

  // --- Accept / Counter ---

  Future<void> _handleAccept() async {
    if (_accepting) return;
    setState(() => _accepting = true);

    Map<String, dynamic>? result;

    if (widget.offerId != null && widget.advertisementId != null) {
      if (widget.role == 'driver') {
        result = await _api.acceptAdvertisementOffer(
            widget.advertisementId!, widget.offerId!);
      } else {
        result = await _api.clientAcceptAdvertisementOffer(
            widget.advertisementId!, widget.offerId!);
      }
    } else if (widget.bidId != null) {
      if (widget.role == 'driver') {
        result = await _api.driverRespondToBid(widget.bidId!, {
          'action': 'accept',
          'price': _lastPrice.toInt(),
        });
      } else if (widget.parcelId != null) {
        result = await _api.acceptBid(widget.parcelId!, widget.bidId!);
      }
    }

    if (mounted) {
      if (result != null && result['finalized'] == true) {
        _showSnack('Accord confirmé ! Le colis a été assigné avec succès.');
        await _loadNegotiations();
        await _loadParcel();
        widget.onChanged?.call();
        widget.onNegotiationFinalized?.call(true);
      } else if (result != null && result['success'] == false) {
        _showSnack(result['message']?.toString() ?? 'L\'acceptation a échoué');
      } else {
        await _loadNegotiations();
        await _loadParcel();
        widget.onChanged?.call();
      }
      setState(() => _accepting = false);
    }
  }

  void _handleCounter() {
    setState(() {
      _showPrice = true;
      _priceCtrl.clear();
      _msgCtrl.text = '';
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // --- Voice recording ---
  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      try {
        final dir = Directory.systemTemp;
        final path = '${dir.path}/nego_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.peerName,
            style: AppFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          if (_parcel != null) _buildParcelHeader(),
          Expanded(child: _buildBody()),
          if (_showPrice && _isNegotiationActive) _buildPriceBar(),
          if (_isNegotiationActive) _buildInputBar(),
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
                [p.departureZoneName, p.arrivalZoneName]
                    .where((e) => e != null && e.isNotEmpty).join(' → '),
                style: AppFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppTheme.slate700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.info_outline, size: 18, color: AppTheme.teal500),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _getItemCount(),
      itemBuilder: (_, i) => _buildItem(i),
    );
  }

  int _getItemCount() {
    int count = 0;
    if (_negotiations.isNotEmpty) {
      count += 1; // header
      if (_canAccept && _isNegotiationActive) count += 1; // action buttons
      count += _negotiations.length; // history items
      count += 1; // chat separator
    }
    count += _messages.length;
    return count;
  }

  Widget _buildItem(int i) {
    int idx = 0;

    if (_negotiations.isNotEmpty) {
      if (i == idx) return _buildNegotiationHeader();
      idx++;

      if (_canAccept && _isNegotiationActive) {
        if (i == idx) return _buildActionButtons();
        idx++;
      }

      final negIdx = i - idx;
      if (negIdx < _negotiations.length) {
        return _buildNegotiationEntry(_negotiations[negIdx], negIdx == _negotiations.length - 1);
      }
      idx += _negotiations.length;

      if (i == idx) return _buildChatSeparator();
      idx++;
    }

    final msgIdx = i - idx;
    if (msgIdx < _messages.length) {
      final m = _messages[msgIdx];
      final body = m['body']?.toString() ?? '';
      final audioUrl = m['audioUrl']?.toString();
      final time = _formatTime(m['createdAt']?.toString());
      final mine = m['senderId']?.toString() == widget.peerId ? false : true;

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
    }

    return const SizedBox.shrink();
  }

  Widget _buildNegotiationHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.amber50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.amber200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake_rounded, size: 18, color: AppTheme.amber700),
              const SizedBox(width: 6),
              Text('Dernière proposition',
                  style: AppFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: AppTheme.amber700)),
            ],
          ),
          const SizedBox(height: 8),
          _buildPriceLine(_lastPrice),
          const SizedBox(height: 4),
          Text(
            'Proposé par : ${_lastProposedBy == 'driver' ? 'Chauffeur' : 'Client'}',
            style: AppFonts.manrope(fontSize: 13, color: AppTheme.slate700),
          ),
          if (_negotiations.isNotEmpty && _negotiations.last.message != null && _negotiations.last.message!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_negotiations.last.message!,
                style: AppFonts.manrope(fontSize: 12, color: AppTheme.slate500, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 4),
          Text(
            _formatDateTime(_negotiations.last.createdAt),
            style: TextStyle(fontSize: 10, color: AppTheme.slate400),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceLine(double price) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${_fcfa(price)}',
            style: AppTheme.mono(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: AppTheme.amber600),
          ),
          TextSpan(
            text: ' FCFA',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppTheme.amber600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: PcButton(
                    'Contre-proposer',
                    variant: PcButtonVariant.secondary,
                    size: PcButtonSize.sm,
                    icon: Icons.swap_horiz_rounded,
                    onPressed: _handleCounter,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: PcButton(
                    'Accepter',
                    icon: Icons.check_rounded,
                    size: PcButtonSize.sm,
                    loading: _accepting,
                    onPressed: _handleAccept,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _lastProposedBy == 'driver'
                ? 'Ce montant est proposé par le chauffeur'
                : 'Ce montant est proposé par le client',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNegotiationEntry(BidNegotiation n, bool isLast) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 12 : 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLast ? AppTheme.amber50 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: n.isAccepted
                  ? Colors.green
                  : n.isInitial
                      ? AppTheme.amber400
                      : Colors.deepOrange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.typeLabel,
                  style: AppFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppTheme.slate600),
                ),
                Row(
                  children: [
                    Text(
                      '${_fcfa(n.price)} FCFA',
                      style: AppFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppTheme.slate700),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      n.authorName ?? n.authorRole,
                      style: TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                if (n.message != null && n.message!.isNotEmpty)
                  Text(
                    n.message!,
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.slate500,
                        fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            _formatTime(n.createdAt.toIso8601String()),
            style: TextStyle(fontSize: 9, color: AppTheme.slate400),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppTheme.slate200)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('Messages',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ),
          Expanded(child: Divider(color: AppTheme.slate200)),
        ],
      ),
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
                  borderSide: BorderSide(color: AppTheme.amber400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(99),
                  borderSide: BorderSide(color: AppTheme.amber400),
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
              decoration: BoxDecoration(
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
      decoration: BoxDecoration(
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
                    child: Icon(Icons.close, color: AppTheme.textSecondary),
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
                      decoration: BoxDecoration(
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
                      decoration: BoxDecoration(
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
                    decoration: BoxDecoration(
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
                        borderSide: BorderSide(color: AppTheme.slate200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(99),
                        borderSide: BorderSide(color: AppTheme.slate200),
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
                      decoration: BoxDecoration(
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

  String _formatDateTime(DateTime d) {
    return '${d.day}/${d.month}/${d.year} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
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
                  style: AppFonts.manrope(
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
