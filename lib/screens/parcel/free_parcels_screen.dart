// lib/screens/parcel/free_parcels_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../models/parcel.dart';
import '../../models/voice_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/procolis_design_system.dart';

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
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 16,
        title: const Row(
          children: [
            _AppBarIcon(icon: Icons.sell_rounded),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Colis à prendre'),
                  SizedBox(height: 2),
                  Text(
                    'Libre service chauffeur',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.tune_rounded, color: AppTheme.primary),
          ),
        ],
        shape: const Border(
          bottom: BorderSide(color: AppTheme.slate200),
        ),
      ),
      body: Column(
        children: [
          _PoolSummaryBand(
            visibleCount: parcels.length,
            totalCount: parcelState.freeParcels.length,
          ),
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: AppTheme.cardColor,
              border: Border(bottom: BorderSide(color: AppTheme.slate200)),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                return _PoolFilterChip(
                  label: filter,
                  selected: _selectedFilter == filter,
                  onTap: () => setState(() => _selectedFilter = filter),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _filters.length,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _refresh,
              child: parcelState.isLoadingFreeParcels
                  ? const _PoolLoadingList()
                  : parcels.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(24, 90, 24, 120),
                          children: const [
                            _EmptyPoolCard(),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          itemCount: parcels.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final parcel = parcels[index];
                            return _ParcelRouteCard(
                              parcel: parcel,
                              onTap: () => _openOffer(parcel),
                              footer: Row(
                                children: [
                                  const Icon(Icons.route_rounded,
                                      size: 18, color: AppTheme.slate500),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '240 km · ${parcel.bids.length} offre${parcel.bids.length > 1 ? 's' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _OfferActionButton(
                                    parcel: parcel,
                                    currentUserId: currentUserId,
                                    onTap: () => _openOffer(parcel),
                                  ),
                                ],
                              ),
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

  @override
  Widget build(BuildContext context) {
    if (_sent) return _OfferSuccessScreen(price: _priceController.text);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Faire une offre'),
        titleSpacing: 0,
        toolbarHeight: 72,
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
        shape: const Border(
          bottom: BorderSide(color: AppTheme.slate200),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _ParcelRouteCard(parcel: widget.parcel),
            const SizedBox(height: 30),
            _OfferPriceField(
              controller: _priceController,
              proposedPrice:
                  widget.parcel.proposedPrice ?? widget.parcel.price ?? 0,
            ),
            const SizedBox(height: 32),
            _OfferMessageField(controller: _messageController),
            const SizedBox(height: 30),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRecording || _isSending ? null : _submitOffer,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSending ? 'Envoi...' : 'Envoyer l’offre'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.deep500,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  final IconData icon;

  const _AppBarIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Icon(icon, color: AppTheme.primary, size: 23),
    );
  }
}

class _PoolSummaryBand extends StatelessWidget {
  final int visibleCount;
  final int totalCount;

  const _PoolSummaryBand({
    required this.visibleCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.cardColor,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: ProcolisCard(
        color: AppTheme.slate50,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(Icons.radar_rounded,
                  color: Colors.white, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$visibleCount colis affiché${visibleCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$totalCount disponible${totalCount > 1 ? 's' : ''} dans le pool',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.green50,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: AppTheme.green700,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PoolLoadingList extends StatelessWidget {
  const _PoolLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemBuilder: (context, index) => const _PoolSkeletonCard(),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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

    return ProcolisCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              block(130, 18),
              const Spacer(),
              block(110, 28),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              block(118, 24),
              const Spacer(),
              block(118, 24),
            ],
          ),
          const SizedBox(height: 22),
          block(double.infinity, 1),
          const SizedBox(height: 18),
          Row(
            children: [
              block(64, 18),
              const SizedBox(width: 18),
              block(98, 18),
              const Spacer(),
              block(84, 36),
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
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcelRouteCard extends StatelessWidget {
  final Parcel parcel;
  final Widget? footer;
  final VoidCallback? onTap;

  const _ParcelRouteCard({required this.parcel, this.footer, this.onTap});

  @override
  Widget build(BuildContext context) {
    final destination = parcel.arrivalGarageName?.isNotEmpty == true
        ? parcel.arrivalGarageName!
        : 'Arrivée';
    final price = parcel.proposedPrice ?? parcel.price ?? 0;
    final weight = parcel.weight.toStringAsFixed(
      parcel.weight.truncateToDouble() == parcel.weight ? 0 : 1,
    );

    return ProcolisCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  size: 19, color: AppTheme.slate400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parcel.trackingNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    color: AppTheme.slate700,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ProcolisStatusBadge(status: parcel.status),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _RouteEndpoint(
                  label: 'DÉPART',
                  value: parcel.departureGarageName,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.local_shipping_rounded,
                    color: AppTheme.primary, size: 26),
              ),
              Expanded(
                child: _RouteEndpoint(
                  label: 'ARRIVÉE',
                  value: destination,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _RouteMeta(
                icon: Icons.shopping_bag_outlined,
                value: '$weight\nkg',
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _RouteMeta(
                  icon: Icons.category_outlined,
                  value: parcel.type.label,
                ),
              ),
              const SizedBox(width: 14),
              const _RouteMeta(icon: Icons.schedule_rounded, value: '~5\nh'),
              const SizedBox(width: 16),
              Text(
                '${_formatFcfa(price)}\nFCFA',
                style: AppTheme.mono(
                  color: AppTheme.deep500,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 18),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _RouteEndpoint extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _RouteEndpoint({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.slate400,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RouteMeta extends StatelessWidget {
  final IconData icon;
  final String value;

  const _RouteMeta({required this.icon, required this.value});

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
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferActionButton extends StatelessWidget {
  final Parcel parcel;
  final String? currentUserId;
  final VoidCallback onTap;

  const _OfferActionButton({
    required this.parcel,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasBid = currentUserId != null &&
        parcel.bids.any((bid) => bid.driverId == currentUserId);

    if (hasBid) {
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.amber50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppTheme.amber500, size: 18),
            SizedBox(width: 6),
            Text(
              'Offre envoyée',
              style: TextStyle(
                color: AppTheme.amber700,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.gavel_rounded, size: 20),
      label: const Text('Faire une offre'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.deep500,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }
}

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
        const Text(
          'Votre prix',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            border: Border.all(color: AppTheme.deep500, width: 2.5),
            borderRadius: BorderRadius.circular(18),
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
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                  ),
                ),
              ),
              const Text(
                'FCFA',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Prix proposé par le client : ${_formatFcfa(proposedPrice)} FCFA',
          style: AppTheme.mono(
            color: AppTheme.textSecondary,
            fontSize: 16,
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
        const Text(
          'Message au client (optionnel)',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          minLines: 4,
          maxLines: 4,
          maxLength: 160,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Ex : Je pars cet après-midi, livraison ce soir.',
            hintStyle: const TextStyle(color: AppTheme.slate500, fontSize: 18),
            filled: true,
            fillColor: AppTheme.cardColor,
            counterStyle: const TextStyle(
              color: AppTheme.slate400,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.slate300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.slate300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.deep500, width: 1.5),
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
        const Text(
          'Note vocale (optionnel)',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (voice != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              border: Border.all(color: AppTheme.slate200),
              borderRadius: BorderRadius.circular(18),
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
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              height: 82,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: isRecording ? AppTheme.red50 : AppTheme.cardColor,
                border: Border.all(
                  color: isRecording ? AppTheme.red400 : AppTheme.slate200,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.mic_rounded,
                    color: isRecording ? AppTheme.red500 : AppTheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      isRecording
                          ? 'Enregistrement... touchez pour arrêter'
                          : 'Enregistrer une note vocale',
                      style: TextStyle(
                        color: isRecording
                            ? AppTheme.red500
                            : AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
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

  const _OfferSuccessScreen({required this.price});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
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
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gavel_rounded,
                      color: AppTheme.primary, size: 54),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Offre envoyée !',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
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
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 280,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Voir d’autres colis'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tableau de bord'),
                        ),
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

class _EmptyPoolCard extends StatelessWidget {
  const _EmptyPoolCard();

  @override
  Widget build(BuildContext context) {
    return ProcolisCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: AppTheme.primary, size: 34),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aucun colis à prendre',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Les demandes clients en libre service apparaîtront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
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
