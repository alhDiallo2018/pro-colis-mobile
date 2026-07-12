// lib/screens/parcel/free_parcels_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../models/parcel.dart';
import '../../models/voice_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/negotiation_chat_widget.dart';
import '../../widgets/parcel_card.dart';
import '../../widgets/pc_components.dart';
import '../driver/itinerary_map_screen.dart';
import '../shared/messages_screen.dart';

class FreeParcelsScreen extends ConsumerStatefulWidget {
  const FreeParcelsScreen({super.key});

  @override
  ConsumerState<FreeParcelsScreen> createState() => _FreeParcelsScreenState();
}

class _FreeParcelsScreenState extends ConsumerState<FreeParcelsScreen> {
  static const _filters = [
    'Tous',
    'Abidjan →',
    'Express',
    '< 10 kg',
    'Aujourd’hui'
  ];

  String _selectedFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(parcelProvider.notifier).loadFreeParcels());
  }

  List<Parcel> _filteredParcels(List<Parcel> parcels) {
    final today = DateTime.now();

    switch (_selectedFilter) {
      case 'Abidjan →':
        return parcels
            .where((parcel) =>
                parcel.departureGarageName.toLowerCase().contains('abidjan'))
            .toList();
      case 'Express':
        return parcels.where((parcel) => parcel.isUrgent).toList();
      case '< 10 kg':
        return parcels.where((parcel) => parcel.weight < 10).toList();
      case 'Aujourd’hui':
        return parcels
            .where((parcel) =>
                parcel.createdAt.year == today.year &&
                parcel.createdAt.month == today.month &&
                parcel.createdAt.day == today.day)
            .toList();
      default:
        return parcels;
    }
  }

  Future<void> _refresh() async {
    await ref.read(parcelProvider.notifier).loadFreeParcels();
  }

  void _openOffer(Parcel parcel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FreeParcelDetailsScreen(parcel: parcel),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final parcelState = ref.watch(parcelProvider);
    final currentUserId = ref.watch(authProvider).user?.id;
    final parcels = _filteredParcels(parcelState.freeParcels);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: const AppBottomNav(),
      body: Column(
        children: [
          _PoolHeader(
            count: parcelState.freeParcels.length,
            onRefresh: _refresh,
          ),
          _PoolFilterBar(
            filters: _filters,
            selected: _selectedFilter,
            onSelect: (filter) => setState(() => _selectedFilter = filter),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.cardColor,
              onRefresh: _refresh,
              child: parcelState.isLoadingFreeParcels
                  ? const _PoolLoadingList()
                  : parcels.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
                          children: const [
                            PcEmptyState(
                              icon: Icons.inventory_2_outlined,
                              tone: PcTone.primary,
                              title: 'Aucun colis à prendre',
                              message:
                                  'Les demandes clients en libre service apparaîtront ici.',
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                          itemCount: parcels.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final parcel = parcels[index];
                            return _FreeParcelItem(
                              parcel: parcel,
                              currentUserId: currentUserId,
                              onOffer: () => _openOffer(parcel),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class FreeParcelDetailsScreen extends ConsumerStatefulWidget {
  final Parcel parcel;

  const FreeParcelDetailsScreen({super.key, required this.parcel});

  @override
  ConsumerState<FreeParcelDetailsScreen> createState() =>
      _FreeParcelDetailsScreenState();
}

class _FreeParcelDetailsScreenState
    extends ConsumerState<FreeParcelDetailsScreen> {
  final _priceController = TextEditingController();
  final _messageController = TextEditingController();
  final _audioRecorder = Record();
  final _audioPlayer = AudioPlayer();

  Timer? _recordingTimer;
  VoiceMessage? _voiceMessage;
  String? _playingPath;
  bool _isRecording = false;
  bool _isSending = false;
  bool _sent = false;
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    final price = widget.parcel.proposedPrice ?? widget.parcel.price ?? 0;
    if (price > 0) _priceController.text = _formatFcfa(price);
    Permission.microphone.request();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _deleteVoiceFile();
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission microphone refusée')),
        );
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/bid_${DateTime.now().millisecondsSinceEpoch}.m4a';

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingDuration++);
      });

      await _audioRecorder.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        samplingRate: 44100,
      );
    } catch (error) {
      debugPrint('Erreur enregistrement offre: $error');
      _recordingTimer?.cancel();
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (path == null) {
        if (mounted) setState(() => _isRecording = false);
        return;
      }

      _deleteVoiceFile();
      setState(() {
        _voiceMessage = VoiceMessage(
          path: path,
          duration: _recordingDuration,
          createdAt: DateTime.now(),
        );
        _isRecording = false;
      });
    } catch (error) {
      debugPrint('Erreur arrêt enregistrement offre: $error');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _playVoice() async {
    final voice = _voiceMessage;
    if (voice == null) return;

    if (_playingPath == voice.path) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _playingPath = null);
      return;
    }

    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(voice.path));
    if (mounted) setState(() => _playingPath = voice.path);
    _audioPlayer.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _playingPath = null);
    });
  }

  void _deleteVoiceFile() {
    final voice = _voiceMessage;
    if (voice == null) return;
    try {
      final file = File(voice.path);
      if (file.existsSync()) file.deleteSync();
    } catch (error) {
      debugPrint('Erreur suppression audio offre: $error');
    }
  }

  void _removeVoice() {
    _deleteVoiceFile();
    setState(() {
      _voiceMessage = null;
      _playingPath = null;
    });
  }

  Future<void> _submitOffer() async {
    final price = double.tryParse(
      _priceController.text.replaceAll(RegExp(r'\D'), ''),
    );

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un prix valide')),
      );
      return;
    }

    setState(() => _isSending = true);

    final user = ref.read(authProvider).user;
    final bidData = <String, dynamic>{
      'parcelId': widget.parcel.id,
      'price': price,
      'message': _messageController.text.trim(),
      'driverId': user?.id ?? '',
      'driverName': user?.fullName ?? '',
      'driverPhone': user?.phone ?? '',
    };

    final voice = _voiceMessage;
    if (voice != null) {
      // L'API existante sait uploader ce XFile avant création de l'offre.
      bidData['audioFile'] = XFile(voice.path);
      bidData['audioDuration'] = voice.duration;
    }

    final result = await ref
        .read(parcelProvider.notifier)
        .createBid(bidData);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result['success'] == true) {
      setState(() => _sent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result['message'] ?? 'Erreur lors de l’envoi de l’offre'),
          backgroundColor: AppTheme.red500,
        ),
      );
    }
  }

  void _openItinerary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItineraryMapScreen(
          departureName: widget.parcel.departureGarageName,
          arrivalName: widget.parcel.arrivalGarageName ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return _OfferSuccessScreen(
        price: _priceController.text,
        parcel: widget.parcel,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Faire une offre'),
        titleSpacing: 0,
        toolbarHeight: 64,
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppTheme.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        shape: const Border(
          bottom: BorderSide(color: AppTheme.slate200),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            ParcelCard(parcel: widget.parcel, onTap: () {}),
            const SizedBox(height: 12),
            PcButton(
              'Itinéraire',
              icon: Icons.map_rounded,
              variant: PcButtonVariant.secondary,
              block: true,
              onPressed: _openItinerary,
            ),
            const SizedBox(height: 26),
            _OfferPriceField(
              controller: _priceController,
              proposedPrice:
                  widget.parcel.proposedPrice ?? widget.parcel.price ?? 0,
            ),
            const SizedBox(height: 28),
            _OfferMessageField(controller: _messageController),
            const SizedBox(height: 26),
            _OfferVoiceField(
              voiceMessage: _voiceMessage,
              isRecording: _isRecording,
              recordingDuration: _recordingDuration,
              isPlaying: _playingPath == _voiceMessage?.path,
              onRecordTap: _isRecording ? _stopRecording : _startRecording,
              onPlay: _playVoice,
              onRemove: _removeVoice,
            ),
            const SizedBox(height: 26),
            PcButton(
              _isSending ? 'Envoi...' : 'Envoyer l’offre',
              icon: Icons.send_rounded,
              block: true,
              size: PcButtonSize.lg,
              loading: _isSending,
              onPressed: _isRecording || _isSending ? null : _submitOffer,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Liste — en-tête, filtres, item colis
// ============================================================

class _PoolHeader extends StatelessWidget {
  final int count;
  final VoidCallback onRefresh;

  const _PoolHeader({required this.count, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        16,
        14,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.teal50,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(Icons.sell_rounded,
                color: AppTheme.primary, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Colis à prendre',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Libre service chauffeur',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PcBadge('$count', tone: PcTone.primary),
          const SizedBox(width: 8),
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

class _PoolFilterBar extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelect;

  const _PoolFilterBar({
    required this.filters,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      child: SizedBox(
        height: 58,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            final filter = filters[index];
            return _PoolFilterChip(
              label: filter,
              selected: selected == filter,
              onTap: () => onSelect(filter),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: filters.length,
        ),
      ),
    );
  }
}

class _FreeParcelItem extends StatelessWidget {
  final Parcel parcel;
  final String? currentUserId;
  final VoidCallback onOffer;

  const _FreeParcelItem({
    required this.parcel,
    required this.currentUserId,
    required this.onOffer,
  });

  @override
  Widget build(BuildContext context) {
    final hasBid = currentUserId != null &&
        parcel.bids.any((bid) => bid.driverId == currentUserId);
    final bidCount = parcel.bids.length;
    final bidLabel = bidCount == 0
        ? 'Soyez le premier à proposer'
        : '$bidCount offre${bidCount > 1 ? 's' : ''} reçue${bidCount > 1 ? 's' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ParcelCard(parcel: parcel, onTap: onOffer),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.gavel_rounded, size: 16, color: AppTheme.slate400),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                bidLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (hasBid)
              const PcBadge(
                'Offre envoyée',
                tone: PcTone.amber,
                icon: Icons.check_circle_rounded,
              )
            else
              PcButton(
                'Faire une offre',
                icon: Icons.gavel_rounded,
                variant: PcButtonVariant.secondary,
                size: PcButtonSize.sm,
                onPressed: onOffer,
              ),
          ],
        ),
      ],
    );
  }
}

class _PoolLoadingList extends StatelessWidget {
  const _PoolLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      itemBuilder: (context, index) => const _PoolSkeletonCard(),
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemCount: 3,
    );
  }
}

class _PoolSkeletonCard extends StatelessWidget {
  const _PoolSkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget block(double width, double height) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.slate100,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return PcCard(
      radius: AppTheme.radiusLg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              block(130, 16),
              const Spacer(),
              block(90, 22),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              block(110, 22),
              const Spacer(),
              block(110, 22),
            ],
          ),
          const SizedBox(height: 20),
          block(double.infinity, 1),
          const SizedBox(height: 16),
          Row(
            children: [
              block(64, 16),
              const SizedBox(width: 16),
              block(90, 16),
              const Spacer(),
              block(78, 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _PoolFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PoolFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.slate200,
          ),
          boxShadow: selected ? AppTheme.softShadow(alpha: 0.10) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Formulaire d'offre — prix / message / note vocale
// ============================================================

class _OfferPriceField extends StatelessWidget {
  final TextEditingController controller;
  final double proposedPrice;

  const _OfferPriceField({
    required this.controller,
    required this.proposedPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Votre prix',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            border: Border.all(color: AppTheme.primary, width: 2),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_FcfaThousandsFormatter()],
                  style: AppTheme.mono(
                    color: AppTheme.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '0',
                  ),
                ),
              ),
              Text(
                'FCFA',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Prix proposé par le client : ${_formatFcfa(proposedPrice)} FCFA',
          style: AppTheme.mono(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _OfferMessageField extends StatelessWidget {
  final TextEditingController controller;

  const _OfferMessageField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Message au client (optionnel)',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          minLines: 4,
          maxLines: 4,
          maxLength: 160,
          style: GoogleFonts.manrope(fontSize: 15, color: AppTheme.slate700),
          decoration: InputDecoration(
            hintText: 'Ex : Je pars cet après-midi, livraison ce soir.',
            hintStyle:
                GoogleFonts.manrope(color: AppTheme.slate400, fontSize: 15),
            filled: true,
            fillColor: AppTheme.cardColor,
            counterStyle: GoogleFonts.manrope(
              color: AppTheme.slate400,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferVoiceField extends StatelessWidget {
  final VoiceMessage? voiceMessage;
  final bool isRecording;
  final int recordingDuration;
  final bool isPlaying;
  final VoidCallback onRecordTap;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  const _OfferVoiceField({
    required this.voiceMessage,
    required this.isRecording,
    required this.recordingDuration,
    required this.isPlaying,
    required this.onRecordTap,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final voice = voiceMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note vocale (optionnel)',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (voice != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              border: Border.all(color: AppTheme.slate200),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onPlay,
                  icon: Icon(
                    isPlaying
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_rounded,
                    color: AppTheme.primary,
                    size: 30,
                  ),
                ),
                Expanded(child: _VoiceWaveform(activeBars: isPlaying ? 9 : 5)),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(voice.duration),
                  style: AppTheme.mono(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppTheme.slate500,
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: onRecordTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              width: double.infinity,
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: isRecording ? AppTheme.red50 : AppTheme.cardColor,
                border: Border.all(
                  color: isRecording ? AppTheme.red400 : AppTheme.slate200,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.mic_rounded,
                    color: isRecording ? AppTheme.red500 : AppTheme.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isRecording
                          ? 'Enregistrement... touchez pour arrêter'
                          : 'Enregistrer une note vocale',
                      style: GoogleFonts.plusJakartaSans(
                        color: isRecording
                            ? AppTheme.red500
                            : AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isRecording)
                    Text(
                      _formatDuration(recordingDuration),
                      style: AppTheme.mono(
                        color: AppTheme.red500,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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

class _OfferSuccessScreen extends StatelessWidget {
  final String price;
  final Parcel parcel;

  const _OfferSuccessScreen({required this.price, required this.parcel});

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NegotiationChatScreen(
          peerId: parcel.senderId,
          peerName: parcel.senderName,
          parcelId: parcel.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    color: AppTheme.teal50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gavel_rounded,
                      color: AppTheme.primary, size: 50),
                ),
                const SizedBox(height: 22),
                Text(
                  'Offre envoyée !',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    text: 'Le client a reçu votre proposition de ',
                    children: [
                      TextSpan(
                        text: '$price FCFA',
                        style: AppTheme.mono(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                          text: '. Vous serez notifié de sa réponse.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 280,
                  child: Column(
                    children: [
                      PcButton(
                        'Discuter avec le client',
                        icon: Icons.chat_bubble_rounded,
                        variant: PcButtonVariant.secondary,
                        block: true,
                        onPressed: () => _openChat(context),
                      ),
                      const SizedBox(height: 10),
                      PcButton(
                        'Voir d’autres colis',
                        block: true,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(height: 10),
                      PcButton(
                        'Tableau de bord',
                        variant: PcButtonVariant.ghost,
                        block: true,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  final int activeBars;

  const _VoiceWaveform({required this.activeBars});

  @override
  Widget build(BuildContext context) {
    const heights = [12.0, 18.0, 26.0, 16.0, 22.0, 30.0, 14.0, 24.0, 18.0];

    return Row(
      children: [
        for (var i = 0; i < heights.length; i++)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 4,
                height: heights[i],
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i < activeBars ? AppTheme.primary : AppTheme.slate200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FcfaThousandsFormatter extends TextInputFormatter {
  const _FcfaThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]} ',
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatFcfa(double amount) {
  final rawAmount = amount.toStringAsFixed(0);
  return rawAmount.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]} ',
  );
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}
