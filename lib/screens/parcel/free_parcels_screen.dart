// lib/screens/parcel/free_parcels_screen.dart
// ignore_for_file: prefer_const_constructors, unused_import, unused_element, prefer_const_literals_to_create_immutables, use_build_context_synchronously, unnecessary_string_interpolations

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../../models/parcel.dart';
import '../../models/user.dart';
import '../../models/voice_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_logo.dart';
import 'new_parcel_screen.dart';
import 'parcel_detail_screen.dart';

// ==================== ÉCRAN PRINCIPAL ====================
class FreeParcelsScreen extends ConsumerStatefulWidget {
  const FreeParcelsScreen({super.key});

  @override
  ConsumerState<FreeParcelsScreen> createState() => _FreeParcelsScreenState();
}

class _FreeParcelsScreenState extends ConsumerState<FreeParcelsScreen> {
  String _filter = 'all';
  String _sortBy = 'price_desc';

  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF0F4F8);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);

  @override
  void initState() {
    super.initState();
    _loadFreeParcels();
  }

  void _loadFreeParcels() {
    Future.microtask(() {
      ref.read(parcelProvider.notifier).loadFreeParcels();
    });
  }

  List<Parcel> _getFilteredAndSortedParcels(List<Parcel> parcels) {
    List<Parcel> filtered = [...parcels];
    
    switch (_filter) {
      case 'pending':
        filtered = filtered.where((p) => p.bids.isEmpty).toList();
        break;
      case 'accepted':
        filtered = filtered.where((p) => p.selectedBid != null).toList();
        break;
      case 'rejected':
        filtered = filtered.where((p) => p.bids.isNotEmpty && p.selectedBid == null).toList();
        break;
      default:
        break;
    }
    
    switch (_sortBy) {
      case 'price_desc':
        filtered.sort((a, b) => (b.proposedPrice ?? 0).compareTo(a.proposedPrice ?? 0));
        break;
      case 'price_asc':
        filtered.sort((a, b) => (a.proposedPrice ?? 0).compareTo(b.proposedPrice ?? 0));
        break;
      case 'date_desc':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'date_asc':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final parcelState = ref.watch(parcelProvider);
    final freeParcels = parcelState.freeParcels;
    final authState = ref.watch(authProvider);
    final isDriver = authState.user?.role == UserRole.driver;
    final filteredParcels = _getFilteredAndSortedParcels(freeParcels);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 24, isWhite: false),
            const SizedBox(width: 8),
            const Text(
              'PRO COLIS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0.5,
        shadowColor: Colors.grey.shade200,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: primaryBlue),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filter,
                        isExpanded: true,
                        icon: Icon(Icons.filter_list, size: 18, color: textSecondary),
                        style: TextStyle(fontSize: 13, color: textSecondary),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('📦 Tous')),
                          DropdownMenuItem(value: 'pending', child: Text('⏳ Sans offres')),
                          DropdownMenuItem(value: 'accepted', child: Text('✅ Acceptés')),
                          DropdownMenuItem(value: 'rejected', child: Text('❌ Sans réponse')),
                        ],
                        onChanged: (value) {
                          setState(() => _filter = value!);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        isExpanded: true,
                        icon: Icon(Icons.sort, size: 18, color: textSecondary),
                        style: TextStyle(fontSize: 13, color: textSecondary),
                        items: const [
                          DropdownMenuItem(value: 'price_desc', child: Text('💰 Prix décroissant')),
                          DropdownMenuItem(value: 'price_asc', child: Text('💰 Prix croissant')),
                          DropdownMenuItem(value: 'date_desc', child: Text('📅 Plus récent')),
                          DropdownMenuItem(value: 'date_asc', child: Text('📅 Plus ancien')),
                        ],
                        onChanged: (value) {
                          setState(() => _sortBy = value!);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadFreeParcels(),
              color: primaryBlue,
              backgroundColor: Colors.white,
              child: parcelState.isLoadingFreeParcels
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                      ),
                    )
                  : filteredParcels.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredParcels.length,
                          itemBuilder: (context, index) {
                            final parcel = filteredParcels[index];
                            return _FreeParcelCard(
                              parcel: parcel,
                              isDriver: isDriver,
                              currentDriverId: authState.user?.id,
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _filter != 'all' ? Icons.filter_alt : Icons.inbox,
                size: 48,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _filter != 'all' ? 'Aucun résultat' : 'Aucun colis en libre service',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filter != 'all' 
                  ? 'Essayez de modifier vos filtres'
                  : 'Les colis mis en libre service apparaîtront ici',
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info, color: primaryBlue),
            const SizedBox(width: 8),
            const Text('Comment ça marche ?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le libre service permet aux chauffeurs de :',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('1. Voir votre colis et son itinéraire'),
            _buildInfoRow('2. Voir les photos et vidéos du colis'),
            _buildInfoRow('3. Faire des offres de prix'),
            _buildInfoRow('4. Proposer leurs services'),
            const SizedBox(height: 12),
            const Text(
              'Vous pourrez :',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('• Comparer les offres des chauffeurs'),
            _buildInfoRow('• Voir les profils des chauffeurs'),
            _buildInfoRow('• Négocier les prix'),
            _buildInfoRow('• Choisir le chauffeur qui vous convient'),
            const SizedBox(height: 12),
            Text(
              'C\'est comme une enchère pour votre colis !',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: primaryBlue,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: primaryBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: TextStyle(color: textSecondary)),
    );
  }
}

// ==================== CARTE COLIS ====================
class _FreeParcelCard extends StatelessWidget {
  final Parcel parcel;
  final bool isDriver;
  final String? currentDriverId;

  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);

  const _FreeParcelCard({
    required this.parcel,
    this.isDriver = false,
    this.currentDriverId,
  });

  bool _hasDriverMadeBid() {
    if (!isDriver || currentDriverId == null || currentDriverId!.isEmpty) {
      return false;
    }
    final cleanCurrentId = currentDriverId!.trim().toLowerCase();
    return parcel.bids.any((bid) => bid.driverId.trim().toLowerCase() == cleanCurrentId);
  }

  Bid? _getDriverBid() {
    if (!isDriver || currentDriverId == null || currentDriverId!.isEmpty) {
      return null;
    }
    final cleanCurrentId = currentDriverId!.trim().toLowerCase();
    try {
      return parcel.bids.firstWhere(
        (bid) => bid.driverId.trim().toLowerCase() == cleanCurrentId,
      );
    } catch (e) {
      return null;
    }
  }

  void _showMakeBidWithAudioDialog(BuildContext context) {
    final priceController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _MakeBidWithAudioDialog(
        parcelId: parcel.id,
        priceController: priceController,
        messageController: messageController,
        onSuccess: () {
          final ref = ProviderScope.containerOf(context);
          ref.read(parcelProvider.notifier).loadFreeParcels();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = parcel.photoUrls.isNotEmpty;
    final hasVideos = parcel.videoUrls.isNotEmpty;
    final hasAudio = parcel.audioUrls.isNotEmpty;
    final hasMadeBid = _hasDriverMadeBid();
    final myBid = _getDriverBid();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FreeParcelDetailsScreen(parcel: parcel),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPhotos || hasVideos)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        image: hasPhotos
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(parcel.photoUrls.first),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: Colors.grey.shade200,
                      ),
                      child: Stack(
                        children: [
                          if (hasVideos)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${parcel.videoUrls.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (hasAudio)
                            Positioned(
                              bottom: 8,
                              right: hasVideos ? 60 : 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.mic, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${parcel.audioUrls.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (hasPhotos && parcel.photoUrls.length > 1)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_library, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${parcel.photoUrls.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (hasAudio && !hasVideos && !hasPhotos)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.mic, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Audio',
                                      style: TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.gavel, size: 12, color: Colors.purple[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'À marchander',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.purple[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (parcel.bids.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${parcel.bids.length} offre(s)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (isDriver && hasMadeBid)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Offre déjà envoyée - ${myBid?.formattedPrice ?? ""}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      Text(
                        parcel.trackingNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(Icons.circle, size: 10, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              parcel.departureGarageName,
                              style: TextStyle(fontSize: 13, color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Column(
                          children: [
                            Container(width: 2, height: 12, color: Colors.grey.shade300),
                            Icon(Icons.arrow_downward, size: 10, color: Colors.grey.shade400),
                            Container(width: 2, height: 12, color: Colors.grey.shade300),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 10, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              parcel.arrivalGarageName ?? "Non spécifié",
                              style: TextStyle(fontSize: 13, color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Icon(Icons.description, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              parcel.description,
                              style: TextStyle(fontSize: 13, color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.fitness_center, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            parcel.formattedWeight,
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (parcel.proposedPrice != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attach_money, size: 14, color: Colors.amber[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Prix suggéré: ${parcel.formattedProposedPrice}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isDriver)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: hasMadeBid
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.check_circle, color: Colors.orange[700], size: 18),
                        label: Text(
                          'Offre envoyée - ${myBid?.formattedPrice ?? ""}',
                          style: TextStyle(color: Colors.orange[700], fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.orange[300]!),
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _showMakeBidWithAudioDialog(context),
                        icon: const Icon(Icons.attach_money, size: 18),
                        label: const Text('Faire une offre'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== DIALOGUE OFFRE AVEC AUDIO ====================
class _MakeBidWithAudioDialog extends StatefulWidget {
  final String parcelId;
  final TextEditingController priceController;
  final TextEditingController messageController;
  final VoidCallback onSuccess;

  const _MakeBidWithAudioDialog({
    required this.parcelId,
    required this.priceController,
    required this.messageController,
    required this.onSuccess,
  });

  @override
  State<_MakeBidWithAudioDialog> createState() => _MakeBidWithAudioDialogState();
}

class _MakeBidWithAudioDialogState extends State<_MakeBidWithAudioDialog> {
  final _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ApiService _apiService = ApiService();
  final List<VoiceMessage> _voiceMessages = [];
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  String? _currentlyPlayingPath;
  bool _isProcessing = false;

  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFF1A2332);

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    for (final msg in _voiceMessages) {
      try {
        final file = File(msg.path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<String?> _getVoiceMessagePath() async {
    if (kIsWeb) return '';
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${directory.path}/voice_bid_$timestamp.m4a';
    } catch (e) {
      debugPrint('Erreur chemin audio: $e');
      return null;
    }
  }

  Future<void> _startRecording() async {
    try {
      final isRecording = await _audioRecorder.isRecording();
      if (isRecording) return;

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission microphone refusée'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final path = await _getVoiceMessagePath();
      if (path == null) {
        throw Exception('Impossible de créer le fichier audio');
      }

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });
        }
      });

      if (kIsWeb) {
        await _audioRecorder.start(
          path: '',
          encoder: AudioEncoder.aacLc,
          samplingRate: 44100,
        );
      } else {
        await _audioRecorder.start(
          path: path,
          encoder: AudioEncoder.aacLc,
          samplingRate: 44100,
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'enregistrement: $e');
      _recordingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final isRecording = await _audioRecorder.isRecording();
      if (isRecording) {
        _recordingTimer?.cancel();
        final path = await _audioRecorder.stop();

        if (path != null && mounted) {
          final voiceMessage = VoiceMessage(
            path: path,
            duration: _recordingDuration,
            createdAt: DateTime.now(),
          );
          setState(() {
            _voiceMessages.add(voiceMessage);
            _isRecording = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Message vocal enregistré (${_formatDuration(_recordingDuration)})',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          setState(() {
            _isRecording = false;
          });
        }
      } else {
        setState(() {
          _isRecording = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'arrêt: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _playVoiceMessage(String path) async {
    try {
      if (_currentlyPlayingPath == path) {
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingPath = null;
        });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() {
          _currentlyPlayingPath = path;
        });

        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _currentlyPlayingPath = null;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de la lecture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la lecture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeVoiceMessage(int index) {
    final voiceMessage = _voiceMessages[index];
    try {
      final file = File(voiceMessage.path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('Erreur suppression fichier audio: $e');
    }
    setState(() {
      _voiceMessages.removeAt(index);
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Faire une offre',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: widget.priceController,
              decoration: InputDecoration(
                labelText: '💰 Prix proposé (FCFA)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.messageController,
              decoration: InputDecoration(
                labelText: '✏️ Message (optionnel)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.mic, color: Colors.red.shade400),
                        const SizedBox(width: 8),
                        Text(
                          'Message vocal (optionnel)',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (_voiceMessages.isNotEmpty)
                          Text(
                            '${_voiceMessages.length} message(s)',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  if (_voiceMessages.isNotEmpty)
                    ..._voiceMessages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final voiceMsg = entry.value;
                      return _buildVoiceMessageTile(voiceMsg, index);
                    }),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _isRecording
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Enregistrement... ${_formatDuration(_recordingDuration)}',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(width: 12),
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: _startRecording,
                                  icon: const Icon(Icons.mic, size: 20),
                                  label: const Text('Enregistrer un message vocal'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade400,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                        ),
                        if (_isRecording) const SizedBox(width: 12),
                        if (_isRecording)
                          ElevatedButton(
                            onPressed: _stopRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Arrêter'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isRecording || _isProcessing ? null : () {
            for (final msg in _voiceMessages) {
              try {
                final file = File(msg.path);
                if (file.existsSync()) {
                  file.deleteSync();
                }
              } catch (_) {}
            }
            Navigator.pop(context);
          },
          child: Text('Annuler', style: TextStyle(color: primaryBlue)),
        ),
        Consumer(
          builder: (context, ref, child) {
            final authState = ref.watch(authProvider);
            final currentDriverId = authState.user?.id ?? '';
            final driverName = authState.user?.fullName ?? '';
            final driverPhone = authState.user?.phone ?? '';

            return ElevatedButton(
              onPressed: _isRecording || _isProcessing
                  ? null
                  : () async {
                      final price = double.tryParse(widget.priceController.text);
                      if (price == null || price <= 0) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Veuillez entrer un prix valide')),
                          );
                        }
                        return;
                      }

                      setState(() => _isProcessing = true);

                      final bidData = {
                        'price': price,
                        'message': widget.messageController.text,
                        'driverId': currentDriverId,
                        'driverName': driverName,
                        'driverPhone': driverPhone,
                      };

                      if (_voiceMessages.isNotEmpty && !kIsWeb) {
                        try {
                          final voiceMessage = _voiceMessages.last;
                          final audioFile = XFile(voiceMessage.path);
                          
                          final audioUrl = await _apiService.uploadAudio(audioFile, widget.parcelId);
                          
                          if (audioUrl != null && audioUrl.isNotEmpty) {
                            bidData['audioUrl'] = audioUrl;
                            bidData['audioDuration'] = voiceMessage.duration;
                            debugPrint('✅ Audio uploadé avec succès: $audioUrl');
                          }
                        } catch (e) {
                          debugPrint('❌ Erreur upload audio: $e');
                        }
                      }

                      final result = await ref
                          .read(parcelProvider.notifier)
                          .makeBid(widget.parcelId, bidData);

                      setState(() => _isProcessing = false);

                      if (mounted) {
                        if (result['success'] == true) {
                          for (final msg in _voiceMessages) {
                            try {
                              final file = File(msg.path);
                              if (file.existsSync()) {
                                file.deleteSync();
                              }
                            } catch (_) {}
                          }
                          Navigator.pop(context);
                          widget.onSuccess();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Offre envoyée avec succès ! 🎉'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ??
                                  "Erreur lors de l'envoi de l'offre"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Envoyer l\'offre'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVoiceMessageTile(VoiceMessage message, int index) {
    final isPlaying = _currentlyPlayingPath == message.path;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.stop : Icons.play_arrow,
              color: primaryBlue,
            ),
            onPressed: () => _playVoiceMessage(message.path),
            iconSize: 20,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message vocal ${_formatDuration(message.duration)}',
                  style: TextStyle(fontSize: 12, color: textPrimary),
                ),
                Text(
                  '${_formatDateTime(message.createdAt)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _removeVoiceMessage(index),
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }
}

// ==================== DÉTAILS COLIS ====================
class FreeParcelDetailsScreen extends ConsumerStatefulWidget {
  final Parcel parcel;

  const FreeParcelDetailsScreen({super.key, required this.parcel});

  @override
  ConsumerState<FreeParcelDetailsScreen> createState() =>
      _FreeParcelDetailsScreenState();
}

class _FreeParcelDetailsScreenState
    extends ConsumerState<FreeParcelDetailsScreen> {
  bool _isProcessing = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingAudioUrl;
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, bool> _videoInitialized = {};
  final Map<String, bool> _audioPlaying = {};

  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    for (int i = 0; i < widget.parcel.videoUrls.length; i++) {
      final url = widget.parcel.videoUrls[i];
      _initializeVideoController(url, 'video_$i');
    }
  }

  @override
  void dispose() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  void _initializeVideoController(String url, String id) async {
    if (kIsWeb) {
      setState(() {
        _videoInitialized[id] = true;
      });
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (mounted) {
        setState(() {
          _videoControllers[id] = controller;
          _videoInitialized[id] = true;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement vidéo: $e');
      setState(() {
        _videoInitialized[id] = true;
      });
    }
  }

  Future<void> _playAudio(String audioUrl) async {
    try {
      if (_currentlyPlayingAudioUrl == audioUrl) {
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingAudioUrl = null;
          _audioPlaying[audioUrl] = false;
        });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() {
          _currentlyPlayingAudioUrl = audioUrl;
          _audioPlaying[audioUrl] = true;
        });

        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _currentlyPlayingAudioUrl = null;
              _audioPlaying[audioUrl] = false;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur lecture audio: $e');
    }
  }

  Future<void> _acceptBid(Bid bid) async {
    setState(() => _isProcessing = true);
    final success = await ref.read(parcelProvider.notifier).acceptBid(
          widget.parcel.id,
          bid.id,
        );
    setState(() => _isProcessing = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Offre de ${bid.driverName} acceptée'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      await ref.read(parcelProvider.notifier).loadFreeParcels();
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erreur lors de l\'acceptation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectBid(Bid bid) async {
    setState(() => _isProcessing = true);
    final success = await ref.read(parcelProvider.notifier).rejectBid(
          widget.parcel.id,
          bid.id,
        );
    setState(() => _isProcessing = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Offre de ${bid.driverName} refusée'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      await ref.read(parcelProvider.notifier).loadFreeParcels();
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    final authState = ref.watch(authProvider);
    final currentDriverId = authState.user?.id;
    final isDriver = authState.user?.role == UserRole.driver;

    return Scaffold(
      backgroundColor: Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 24, isWhite: false),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                parcel.trackingNumber,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0.5,
        shadowColor: Colors.grey.shade200,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isProcessing
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMediaSection(parcel),
                  const SizedBox(height: 16),
                  _buildMainCard(parcel),
                  const SizedBox(height: 16),
                  _buildInfoCard(parcel),
                  const SizedBox(height: 16),
                  _buildReceiverCard(parcel),
                  const SizedBox(height: 16),
                  _buildSenderCard(parcel),
                  const SizedBox(height: 16),
                  if (parcel.proposedPrice != null)
                    _buildSuggestedPriceCard(parcel),
                  const SizedBox(height: 16),
                  _buildBidsSection(parcel, isDriver, currentDriverId),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  // ... Le reste du code reste identique mais avec les couleurs bleues
  // Je continue avec les widgets principaux modifiés

  Widget _buildMediaSection(Parcel parcel) {
    final hasPhotos = parcel.photoUrls.isNotEmpty;
    final hasVideos = parcel.videoUrls.isNotEmpty;
    final hasAudio = parcel.audioUrls.isNotEmpty;

    if (!hasPhotos && !hasVideos && !hasAudio) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(
              'Aucun média disponible',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📎 Médias',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 12),
          if (hasPhotos) ...[
            const Text(
              '📸 Photos',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: parcel.photoUrls.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(parcel.photoUrls[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (hasVideos) ...[
            const Text(
              '🎬 Vidéos',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: parcel.videoUrls.length,
                itemBuilder: (context, index) {
                  final id = 'video_$index';
                  final isInitialized = _videoInitialized[id] ?? false;
                  final controller = _videoControllers[id];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          if (!kIsWeb && isInitialized && controller != null)
                            VideoPlayer(controller)
                          else
                            const Center(
                              child: Icon(Icons.videocam, size: 40, color: Colors.white54),
                            ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: IconButton(
                              icon: Icon(
                                controller != null && controller.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 30,
                              ),
                              onPressed: () {
                                if (controller != null) {
                                  if (controller.value.isPlaying) {
                                    controller.pause();
                                  } else {
                                    controller.play();
                                  }
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (hasAudio) ...[
            const Text(
              '🎤 Messages audio',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 8),
            ...parcel.audioUrls.asMap().entries.map((entry) {
              final index = entry.key;
              final audioUrl = entry.value;
              final isPlaying = _currentlyPlayingAudioUrl == audioUrl;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPlaying ? Colors.purple.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPlaying ? Colors.purple : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.stop : Icons.play_arrow,
                        color: Colors.purple[700],
                        size: 28,
                      ),
                      onPressed: () => _playAudio(audioUrl),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Message audio ${index + 1}',
                            style: TextStyle(
                              fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                              color: textPrimary,
                            ),
                          ),
                          if (isPlaying)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              height: 2,
                              width: double.infinity,
                              color: Colors.purple,
                            ),
                        ],
                      ),
                    ),
                    if (isPlaying)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.purple),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMainCard(Parcel parcel) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [parcel.status.color, parcel.status.color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: parcel.status.color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(parcel.statusIcon, style: const TextStyle(fontSize: 32)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parcel.status.label,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusDescription(parcel.status),
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusDescription(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.free:
        return 'En attente d\'offres';
      default:
        return status.label;
    }
  }

  Widget _buildInfoCard(Parcel parcel) {
    return _buildCard(
      title: 'Informations détaillées',
      icon: Icons.info_outline,
      child: Column(
        children: [
          _buildInfoRow(Icons.description, 'Description', parcel.description),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.fitness_center, 'Poids', parcel.formattedWeight),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.category, 'Type', parcel.type.label),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.payment, 'Paiement', parcel.paymentMethod?.label ?? 'Non spécifié'),
          if (parcel.paymentPhoneNumber != null && parcel.paymentPhoneNumber!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone, 'Tél. paiement', parcel.paymentPhoneNumber!),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(Icons.departure_board, 'Départ', parcel.departureGarageName),
          if (parcel.arrivalGarageName != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'Arrivée', parcel.arrivalGarageName!),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(Icons.calendar_today, 'Création', parcel.formattedDateTime),
          if (parcel.notes != null && parcel.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.note, 'Notes', parcel.notes!, isLongText: true),
          ],
          if (parcel.isUrgent) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.flash_on, 'Urgent', 'Oui', isHighlighted: true),
          ],
          if (parcel.isInsured) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.shield, 'Assuré', 'Oui', isHighlighted: true),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestedPriceCard(Parcel parcel) {
    return _buildCard(
      title: '💰 Prix suggéré',
      icon: Icons.attach_money,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade50, Colors.amber.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_money, size: 32, color: Colors.amber[700]),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${parcel.proposedPrice?.toStringAsFixed(0)} FCFA',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
                Text(
                  'Prix suggéré par l\'expéditeur',
                  style: TextStyle(fontSize: 12, color: Colors.amber[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiverCard(Parcel parcel) {
    return _buildCard(
      title: '👤 Destinataire',
      icon: Icons.person,
      child: Column(
        children: [
          _buildInfoRow(Icons.person, 'Nom', parcel.receiverName),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone, 'Téléphone', parcel.receiverPhone),
          if (parcel.receiverEmail != null && parcel.receiverEmail!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.email, 'Email', parcel.receiverEmail!),
          ],
          if (parcel.receiverAddress != null && parcel.receiverAddress!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'Adresse', parcel.receiverAddress!),
          ],
        ],
      ),
    );
  }

  Widget _buildSenderCard(Parcel parcel) {
    return _buildCard(
      title: '📦 Expéditeur',
      icon: Icons.person_outline,
      child: Column(
        children: [
          _buildInfoRow(Icons.person, 'Nom', parcel.senderName),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone, 'Téléphone', parcel.senderPhone),
          if (parcel.senderEmail != null && parcel.senderEmail!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.email, 'Email', parcel.senderEmail!),
          ],
        ],
      ),
    );
  }

  Widget _buildBidsSection(Parcel parcel, bool isDriver, String? currentDriverId) {
    List<Bid> filteredBids = [];
    
    if (isDriver) {
      if (currentDriverId != null && currentDriverId.isNotEmpty) {
        try {
          filteredBids = [parcel.bids.firstWhere((bid) => bid.driverId == currentDriverId)];
        } catch (e) {
          filteredBids = [];
        }
      }
    } else {
      filteredBids = parcel.bids;
    }
    
    return _buildCard(
      title: isDriver ? 'Votre offre' : 'Offres des chauffeurs',
      icon: Icons.gavel,
      child: Column(
        children: [
          if (isDriver && parcel.bids.every((bid) => bid.driverId != currentDriverId))
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final priceController = TextEditingController();
                  final messageController = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (dialogContext) => _MakeBidWithAudioDialog(
                      parcelId: parcel.id,
                      priceController: priceController,
                      messageController: messageController,
                      onSuccess: () {
                        ref.read(parcelProvider.notifier).loadFreeParcels();
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.attach_money),
                label: const Text('Faire une offre'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (filteredBids.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.hourglass_empty, size: 48, color: Colors.orange[300]),
                  const SizedBox(height: 12),
                  Text(
                    isDriver ? 'Vous n\'avez pas encore fait d\'offre' : 'Aucune offre pour le moment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDriver ? 'Faites une offre pour être mis en relation' : 'Soyez patient, des offres arrivent',
                    style: TextStyle(color: textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...filteredBids.map((bid) => _BidCard(
              bid: bid,
              onAccept: () => _acceptBid(bid),
              onReject: () => _rejectBid(bid),
              isProcessing: _isProcessing,
              isDriverBid: isDriver && bid.driverId == currentDriverId,
              onPlayAudio: bid.audioUrl != null && bid.audioUrl!.isNotEmpty
                  ? () => _playAudio(bid.audioUrl!)
                  : null,
              isAudioPlaying: bid.audioUrl != null && _currentlyPlayingAudioUrl == bid.audioUrl,
            )),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: primaryBlue),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isHighlighted = false, bool isLongText = false}) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: primaryBlue),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 13, color: textSecondary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
              color: isHighlighted ? primaryBlue : textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== CARTE OFFRE AVEC AUDIO ====================
class _BidCard extends StatelessWidget {
  final Bid bid;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isProcessing;
  final bool isDriverBid;
  final VoidCallback? onPlayAudio;
  final bool isAudioPlaying;

  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFF1A2332);

  const _BidCard({
    required this.bid,
    required this.onAccept,
    required this.onReject,
    this.isProcessing = false,
    this.isDriverBid = false,
    this.onPlayAudio,
    this.isAudioPlaying = false,
  });

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} à ${date.hour}h${date.minute}';
  }

  @override
  Widget build(BuildContext context) {
    final isAccepted = bid.status == BidStatus.accepted;
    final isRejected = bid.status == BidStatus.rejected;
    final isPending = bid.status == BidStatus.pending;
    final hasAudio = bid.audioUrl != null && bid.audioUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDriverBid
            ? Colors.green.withValues(alpha: 0.1)
            : isAccepted
                ? Colors.green.withValues(alpha: 0.1)
                : isRejected
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: isDriverBid
            ? Border.all(color: Colors.green, width: 2)
            : isAccepted
                ? Border.all(color: Colors.green, width: 1)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDriverBid
                    ? Colors.green
                    : (isAccepted ? Colors.green : primaryBlue),
                child: Icon(
                  isDriverBid ? Icons.star : (isAccepted ? Icons.check : Icons.person),
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          bid.driverName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDriverBid ? Colors.green[700] : textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDriverBid
                                ? Colors.green
                                : (isAccepted ? Colors.green : (isRejected ? Colors.red : Colors.orange)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isDriverBid ? 'VOTRE OFFRE' : bid.status.label,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Text(bid.driverPhone, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(_formatDate(bid.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  bid.formattedPrice,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          if (bid.message != null && bid.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(bid.message!, style: TextStyle(color: Colors.grey[700])),
            ),
          ],
          if (hasAudio && onPlayAudio != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isAudioPlaying ? Colors.purple.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isAudioPlaying ? Colors.purple : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isAudioPlaying ? Icons.stop : Icons.play_arrow,
                      color: Colors.purple[700],
                      size: 24,
                    ),
                    onPressed: onPlayAudio,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎤 Message vocal du chauffeur',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isAudioPlaying ? FontWeight.bold : FontWeight.w500,
                            color: Colors.purple[700],
                          ),
                        ),
                        if (isAudioPlaying)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            height: 2,
                            width: 60,
                            color: Colors.purple,
                          ),
                      ],
                    ),
                  ),
                  if (isAudioPlaying)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.purple),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (!isAccepted && !isRejected && !isProcessing && !isDriverBid) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Refuser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accepter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (isDriverBid && isPending)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_empty, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'En attente de réponse du client',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            ),
          if (isDriverBid && isAccepted)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offre acceptée ! Le colis vous sera assigné',
                      style: TextStyle(fontSize: 12, color: Colors.green[700]),
                    ),
                  ),
                ],
              ),
            ),
          if (isDriverBid && isRejected)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.cancel, size: 16, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offre refusée',
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
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