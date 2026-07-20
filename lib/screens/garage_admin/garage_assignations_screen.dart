// mobile/lib/screens/garage_admin/garage_assignations_screen.dart
// Écran d'assignation chauffeurs→colis - aligné Web

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/parcel.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/video_player_widget.dart';

class GarageAssignationsScreen extends ConsumerStatefulWidget {
  const GarageAssignationsScreen({super.key});

  @override
  ConsumerState<GarageAssignationsScreen> createState() =>
      _GarageAssignationsScreenState();
}

class _GarageAssignationsScreenState
    extends ConsumerState<GarageAssignationsScreen> {
  final ApiService _apiService = ApiService();
  List<Parcel> _pendingParcels = [];
  List<User> _drivers = [];
  bool _isLoading = true;
  Map<String, String?> _selectedDriver = {}; // parcelId → driverId
  Map<String, bool> _assigningState = {}; // parcelId → isAssigning

  // Lecture des notes vocales attachées aux colis (pièces jointes).
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingAudioKey; // '<parcelId>:<index>'

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingAudioKey = null);
    });
    _loadData();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final parcels = await _apiService.getGarageParcels();
      final pendingParcels = parcels
          .where((p) =>
              p.status == ParcelStatus.pending ||
              p.status == ParcelStatus.confirmed ||
              p.status == ParcelStatus.free)
          .toList();

      final drivers = await _apiService.getGarageDrivers();

      if (mounted) {
        setState(() {
          _pendingParcels = pendingParcels;
          // Aligné Web : on liste TOUS les chauffeurs du garage, pas
          // seulement les disponibles. Le statut est affiché par ligne.
          _drivers = drivers;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignDriver(String parcelId, String driverId) async {
    setState(() => _assigningState[parcelId] = true);
    try {
      final result = await _apiService.assignDriverToParcel(parcelId, driverId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['success'] == true
                ? 'Chauffeur assigné avec succès'
                : result['message'] ?? 'Erreur'),
            backgroundColor:
                result['success'] == true ? AppTheme.green600 : AppTheme.error,
          ),
        );
        if (result['success'] == true) await _loadData();
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _assigningState[parcelId] = false);
    }
  }

  Future<void> _bulkAssign() async {
    final assignments = <Map<String, String>>[];
    for (final parcel in _pendingParcels) {
      final driverId = _selectedDriver[parcel.id];
      if (driverId != null) {
        assignments.add({'parcelId': parcel.id, 'driverId': driverId});
      }
    }
    if (assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucune assignation à effectuer'),
            backgroundColor: AppTheme.warningColor),
      );
      return;
    }

    for (final a in assignments) {
      await _apiService.assignDriverToParcel(
          a['parcelId']!, a['driverId']!);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Assignation en masse effectuée'),
          backgroundColor: AppTheme.green600),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: Text('Assignations',
            style: AppFonts.plusJakartaSans(
                fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          if (_pendingParcels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: PcButton(
                'Tout assigner',
                icon: Icons.done_all_rounded,
                variant: PcButtonVariant.ghost,
                size: PcButtonSize.sm,
                onPressed: _bulkAssign,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Statistiques.
                  Row(
                    children: [
                      Expanded(
                        child: PcStatBox(
                          icon: Icons.inventory_2_rounded,
                          value: '${_pendingParcels.length}',
                          label: 'Colis en attente',
                          tone: PcTone.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PcStatBox(
                          icon: Icons.local_shipping_rounded,
                          value:
                              '${_drivers.where((d) => d.driverStatus == DriverStatus.available).length}/${_drivers.length}',
                          label: 'Chauffeurs dispo.',
                          tone: PcTone.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Panneau « À assigner ».
                  PcCard(
                    padding: EdgeInsets.zero,
                    child: _pendingParcels.isEmpty
                        ? const PcEmptyState(
                            icon: Icons.check_circle_rounded,
                            tone: PcTone.green,
                            title: 'Rien à assigner',
                            message:
                                'Tous les colis de votre zone ont un chauffeur.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                child: Row(
                                  children: [
                                    Text('À assigner',
                                        style: AppFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary)),
                                    const SizedBox(width: 8),
                                    PcBadge('${_pendingParcels.length}',
                                        tone: PcTone.primary),
                                  ],
                                ),
                              ),
                              for (int i = 0;
                                  i < _pendingParcels.length;
                                  i++) ...[
                                if (i > 0) const PcDivider(),
                                _buildAssignRow(_pendingParcels[i]),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAssignRow(Parcel parcel) {
    final isAssigning = _assigningState[parcel.id] ?? false;
    final selectedId = _selectedDriver[parcel.id];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trajet + statut.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            parcel.departureGarageName.isEmpty
                                ? '—'
                                : parcel.departureGarageName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_right_alt_rounded,
                              size: 18, color: AppTheme.slate400),
                        ),
                        Flexible(
                          child: Text(
                            parcel.arrivalGarageName ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(parcel.trackingNumber,
                            style: AppTheme.mono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.slate500)),
                        if (parcel.price != null) ...[
                          Text(' · ',
                              style: TextStyle(color: AppTheme.slate400)),
                          Text('${parcel.price!.toStringAsFixed(0)} FCFA',
                              style: AppTheme.mono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.teal600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _statusBadge(parcel.status),
            ],
          ),
          const SizedBox(height: 12),
          if (parcel.driverId != null && parcel.driverId!.isNotEmpty)
            Row(
              children: [
                PcAvatar(parcel.driverName ?? 'Chauffeur',
                    size: 30, status: PcAvatarStatus.online),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    parcel.driverName ?? 'Assigné',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.green700),
                  ),
                ),
                const PcBadge('Assigné',
                    tone: PcTone.green, icon: Icons.check_rounded),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedId,
                    hint: Text(
                      _drivers.isEmpty
                          ? 'Aucun chauffeur'
                          : 'Choisir un chauffeur',
                      style: AppFonts.manrope(
                          fontSize: 13, color: AppTheme.slate400),
                    ),
                    icon: const Icon(Icons.expand_more_rounded,
                        color: AppTheme.slate400),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        borderSide: const BorderSide(color: AppTheme.slate200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        borderSide:
                            const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                    ),
                    items: _drivers.map((d) {
                      final st = d.driverStatus ?? DriverStatus.offline;
                      return DropdownMenuItem(
                        value: d.id,
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 7),
                              decoration: BoxDecoration(
                                color: _driverStatusColor(st),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                d.fullName,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.plusJakartaSans(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _driverStatusLabel(st),
                              style: AppFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _driverStatusColor(st)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() => _selectedDriver[parcel.id] = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PcButton(
                  'Assigner',
                  icon: Icons.how_to_reg_rounded,
                  size: PcButtonSize.sm,
                  loading: isAssigning,
                  onPressed: selectedId == null
                      ? null
                      : () => _assignDriver(parcel.id, selectedId),
                ),
              ],
            ),
          // Pièces jointes (photos / vidéos / notes vocales) — aligné Web.
          ..._buildParcelMedia(parcel),
        ],
      ),
    );
  }

  // ==================== MÉDIAS (PIÈCES JOINTES) ====================

  /// Résout une URL de média : les chemins relatifs `/uploads/...` sont
  /// préfixés avec le backend, comme dans le reste de l'application.
  String _mediaUrl(String url) => url.startsWith('http')
      ? url
      : ApiService.resolveMediaUrl(url);

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

  Future<void> _toggleAudio(String key, String url) async {
    try {
      if (_playingAudioKey == key) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playingAudioKey = null);
        return;
      }
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      if (mounted) setState(() => _playingAudioKey = key);
    } catch (_) {
      if (mounted) setState(() => _playingAudioKey = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Lecture audio impossible'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  List<Widget> _buildParcelMedia(Parcel parcel) {
    final photos = parcel.photoUrls;
    final videos = parcel.videoUrls;
    final audios = parcel.audioUrls;
    if (photos.isEmpty && videos.isEmpty && audios.isEmpty) {
      return const [];
    }

    return [
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.slate50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.slate100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photos.isNotEmpty) ...[
              _mediaLabel(Icons.photo_library_rounded, 'Photos'),
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final url = _mediaUrl(photos[i]);
                    return GestureDetector(
                      onTap: () => _openPhotoViewer(url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        child: Image.network(
                          url,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
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
              if (photos.isNotEmpty) const SizedBox(height: 12),
              _mediaLabel(Icons.videocam_rounded, 'Vidéos'),
              const SizedBox(height: 8),
              for (var i = 0; i < videos.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _mediaTile(
                  icon: Icons.play_circle_fill_rounded,
                  label: 'Vidéo ${i + 1}',
                  onTap: () => _openVideo(_mediaUrl(videos[i])),
                ),
              ],
            ],
            if (audios.isNotEmpty) ...[
              if (photos.isNotEmpty || videos.isNotEmpty)
                const SizedBox(height: 12),
              _mediaLabel(Icons.graphic_eq_rounded, 'Notes vocales'),
              const SizedBox(height: 8),
              for (var i = 0; i < audios.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                Builder(builder: (_) {
                  final key = '${parcel.id}:$i';
                  return _mediaTile(
                    icon: _playingAudioKey == key
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_fill_rounded,
                    label: 'Note vocale ${i + 1}',
                    onTap: () => _toggleAudio(key, _mediaUrl(audios[i])),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    ];
  }

  Widget _mediaLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _mediaTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.slate400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _driverStatusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.available:
        return AppTheme.green600;
      case DriverStatus.busy:
        return AppTheme.warningColor;
      case DriverStatus.offline:
        return AppTheme.slate400;
    }
  }

  String _driverStatusLabel(DriverStatus status) {
    switch (status) {
      case DriverStatus.available:
        return 'Disponible';
      case DriverStatus.busy:
        return 'Occupé';
      case DriverStatus.offline:
        return 'Hors ligne';
    }
  }

  Widget _statusBadge(ParcelStatus status) {
    final colors = AppTheme.statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: colors.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(status.label.toUpperCase(),
              style: AppFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: colors.foreground)),
        ],
      ),
    );
  }
}
