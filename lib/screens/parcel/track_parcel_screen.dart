// ignore_for_file: unused_import, unused_element, prefer_const_constructors

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:procolis/screens/parcel/parcel_detail_screen.dart';
import 'package:procolis/widgets/app_logo.dart';
import 'package:procolis/widgets/procolis_design_system.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/parcel.dart';
import '../../providers/parcel_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class TrackParcelScreen extends ConsumerStatefulWidget {
  final bool embedded;
  final String? trackingNumber;

  const TrackParcelScreen({super.key, this.embedded = false, this.trackingNumber});

  @override
  ConsumerState<TrackParcelScreen> createState() => _TrackParcelScreenState();
}

class _TrackParcelScreenState extends ConsumerState<TrackParcelScreen> {
  final TextEditingController _trackingController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSearching = false;
  Parcel? _trackedParcel;
  List<String> _recentSearches = [];
  String? _currentlyPlayingAudioUrl;

  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _setupAudioListeners();
    if (widget.trackingNumber != null && widget.trackingNumber!.isNotEmpty) {
      _trackingController.text = widget.trackingNumber!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trackParcel(trackingNumber: widget.trackingNumber);
      });
    }
  }

  @override
  void dispose() {
    _trackingController.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _currentlyPlayingAudioUrl = null;
        });
      }
    });
  }

  void _loadRecentSearches() {
    _recentSearches = [
      'COL-20260526-ADE4B8',
      'COL-20260525-933934',
      'COL-20260524-7D6FDD',
    ];
    setState(() {});
  }

  List<String> _generateSuggestions(String query) {
    final suggestions = <String>{};

    if (query.startsWith('COL') || query.startsWith('col')) {
      suggestions.add('COL-${_getCurrentDate()}-XXXXXX');
      suggestions.add('COL-${_getYesterdayDate()}-XXXXXX');
    }

    for (var search in _recentSearches) {
      if (search.toUpperCase().contains(query.toUpperCase())) {
        suggestions.add(search);
      }
    }

    if (query.length >= 4 && query.length <= 8) {
      suggestions.add('COL-${_getCurrentDate()}-$query');
      suggestions.add('COL-${_getYesterdayDate()}-$query');
    }

    return suggestions.take(5).toList();
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  String _getYesterdayDate() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}${yesterday.month.toString().padLeft(2, '0')}${yesterday.day.toString().padLeft(2, '0')}';
  }

  Future<void> _trackParcel({String? trackingNumber}) async {
    final trackingNumberToUse =
        trackingNumber ?? _trackingController.text.trim();
    if (trackingNumberToUse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un numéro de suivi')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final parcel = await ref
          .read(parcelProvider.notifier)
          .trackParcel(trackingNumberToUse);
      setState(() {
        _isSearching = false;
        _trackedParcel = parcel;
      });

      if (parcel != null) {
        _saveToRecentSearches(trackingNumberToUse);
        _focusNode.unfocus();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Colis ${parcel.trackingNumber} trouvé'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Colis non trouvé'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _saveToRecentSearches(String trackingNumber) {
    if (!_recentSearches.contains(trackingNumber)) {
      _recentSearches.insert(0, trackingNumber);
      if (_recentSearches.length > 5) {
        _recentSearches.removeLast();
      }
      setState(() {});
    }
  }

  void _clearSearch() {
    _trackingController.clear();
    setState(() {
      _trackedParcel = null;
    });
    _focusNode.requestFocus();
  }

  void _removeRecentSearch(String search) {
    setState(() {
      _recentSearches.remove(search);
    });
  }

  bool _isStepCompleted(Parcel parcel, String stepStatus) {
    final statusOrder = [
      'pending',
      'confirmed',
      'picked_up',
      'in_transit',
      'arrived',
      'out_for_delivery',
      'delivered'
    ];

    final currentIndex = statusOrder.indexOf(parcel.status.value);
    final stepIndex = statusOrder.indexOf(stepStatus);

    return currentIndex >= stepIndex;
  }

  // ==================== QR CODE ET RECU ====================

  String _generateReceiptQRData() {
    final parcel = _trackedParcel!;

    // Générer l'URL publique de suivi
    return 'https://procolis.sn/track/${parcel.trackingNumber}';
  }

  void _showReceiptDialog() {
    if (_trackedParcel == null) return;

    final GlobalKey receiptKey = GlobalKey();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
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
                            icon: Icon(Icons.share, color: primaryBlue),
                            onPressed: () => _shareReceipt(context, receiptKey),
                            tooltip: 'Partager',
                          ),
                          IconButton(
                            icon: Icon(Icons.download, color: primaryBlue),
                            onPressed: () => _downloadReceiptImage(receiptKey),
                            tooltip: 'Télécharger',
                          ),
                          IconButton(
                            icon: Icon(Icons.link, color: primaryBlue),
                            onPressed: () => _shareTrackingLink(),
                            tooltip: 'Partager le lien',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
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

  Widget _buildReceiptWidget() {
    final parcel = _trackedParcel!;
    final isDelivered = parcel.status.value == 'delivered';
    final trackingUrl = 'https://procolis.sn/track/${parcel.trackingNumber}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.04),
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
                  gradient: LinearGradient(
                    colors: [primaryBlue, secondaryBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                      color: primaryBlue.withOpacity( 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: primaryBlue.withOpacity( 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new, size: 16, color: primaryBlue),
                        const SizedBox(width: 8),
                        Text(
                          'Voir en ligne',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryBlue,
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
          _buildReceiptInfoRow('📅 Date', _formatDate(parcel.createdAt)),
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
                '✅ Livré le', _formatDate(parcel.deliveryDate!)),
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
                  '📞 +221 33 123 45 67 | 📧 contact@procolis.sn',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 8),
                Text(
                  '📱 www.procolis.sn',
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
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== PARTAGE ET TELECHARGEMENT ====================

  Future<void> _shareReceipt(BuildContext context, GlobalKey receiptKey) async {
    try {
      final RenderRepaintBoundary? boundary = receiptKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Impossible de capturer le reçu'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Erreur lors de la capture'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/receipt_${_trackedParcel!.trackingNumber}.png');
      await file.writeAsBytes(pngBytes);

      final trackingUrl =
          'https://procolis.sn/track/${_trackedParcel!.trackingNumber}';

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📦 Suivi de colis PRO COLIS\n\n'
            '🔹 N° de suivi: ${_trackedParcel!.trackingNumber}\n'
            '🔹 Statut: ${_trackedParcel!.status.label}\n'
            '🔹 Expéditeur: ${_trackedParcel!.senderName}\n'
            '🔹 Destinataire: ${_trackedParcel!.receiverName}\n'
            '🔹 Montant: ${_trackedParcel!.formattedPrice}\n\n'
            '🔗 Suivez votre colis en ligne: $trackingUrl',
        subject: 'Reçu de livraison PRO COLIS',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du partage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadReceiptImage(GlobalKey receiptKey) async {
    try {
      final RenderRepaintBoundary? boundary = receiptKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Impossible de capturer le reçu'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Erreur lors de la capture'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/receipt_${_trackedParcel!.trackingNumber}.png');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Reçu téléchargé: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareTrackingLink() async {
    if (_trackedParcel == null) return;

    final trackingUrl =
        'https://procolis.sn/track/${_trackedParcel!.trackingNumber}';

    await Share.share(
      '📦 Suivi de colis PRO COLIS\n\n'
      '🔹 N° de suivi: ${_trackedParcel!.trackingNumber}\n'
      '🔹 Statut: ${_trackedParcel!.status.label}\n'
      '🔹 Expéditeur: ${_trackedParcel!.senderName}\n'
      '🔹 Destinataire: ${_trackedParcel!.receiverName}\n\n'
      '🔗 Suivez votre colis en ligne: $trackingUrl',
      subject: 'Suivi de colis PRO COLIS',
    );
  }

  Future<void> _openTrackingUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Impossible d\'ouvrir le lien'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur ouverture lien: $e');
    }
  }

  // ==================== SCAN QR CODE ====================

  void _showScannerDialog() {
    Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
    ).then((scannedData) {
      if (scannedData != null && scannedData.trim().isNotEmpty) {
        _handleScannedData(scannedData);
      }
    });
  }

  Widget _buildWebOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryBlue),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrer le numéro de suivi'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ex: COL-20260526-ADE4B8',
            prefixIcon: Icon(Icons.search),
          ),
          style: const TextStyle(fontFamily: 'monospace'),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context);
              _handleScannedData(value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: primaryBlue)),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                _handleScannedData(code);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Suivre'),
          ),
        ],
      ),
    );
  }

  void _showPasteDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Collez le numéro dans le champ de recherche'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _handleScannedData(String data) {
    debugPrint('📱 Données scannées: $data');

    try {
      final directTrackingNumber = _extractTrackingNumber(data);
      if (directTrackingNumber != null) {
        _trackingController.text = directTrackingNumber;
        _trackParcel();
        return;
      }

      // Certains QR codes peuvent embarquer un petit JSON.
      // On lit les clés usuelles avant de basculer vers l'affichage brut.
      try {
        final jsonData = jsonDecode(data.trim()) as Map<String, dynamic>;
        final rawTracking = jsonData['t'] ??
            jsonData['tracking'] ??
            jsonData['trackingNumber'] ??
            jsonData['tracking_number'];
        final trackingNumber = _extractTrackingNumber(rawTracking.toString());

        if (trackingNumber != null) {
          _trackingController.text = trackingNumber;
          _trackParcel();
          return;
        }
      } catch (e) {
        debugPrint('❌ Erreur parsing JSON: $e');
      }
      _showScannedTextDialog(data);
    } catch (e) {
      debugPrint('❌ Erreur lors du traitement: $e');
      _showScannedTextDialog(data);
    }
  }

  String? _extractTrackingNumber(String value) {
    final normalized = value.trim().toUpperCase();

    final patterns = [
      RegExp(r'COL-\d{8}-[A-Z0-9]{4,8}'),
      RegExp(r'PC-[A-Z0-9]{2,6}-[A-Z0-9]{3,6}'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) return match.group(0);
    }

    return null;
  }

  void _showScannedTextDialog(String data) {
    final trackingNumber = _extractTrackingNumber(data);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.qr_code_scanner, color: primaryBlue),
            const SizedBox(width: 8),
            const Text('Données scannées'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                data,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            if (trackingNumber != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Numéro de suivi détecté',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            trackingNumber,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: primaryBlue)),
          ),
          if (trackingNumber != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _trackingController.text = trackingNumber;
                _trackParcel();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Suivre'),
            ),
        ],
      ),
    );
  }

  void _shareTrackingNumber() {
    if (_trackedParcel != null) {
      final trackingUrl =
          'https://procolis.sn/track/${_trackedParcel!.trackingNumber}';
      Share.share(
        '📦 Suivi de colis PRO COLIS\n\n'
        '🔹 N° de suivi: ${_trackedParcel!.trackingNumber}\n'
        '🔹 Statut: ${_trackedParcel!.status.label}\n'
        '🔹 Expéditeur: ${_trackedParcel!.senderName}\n'
        '🔹 Destinataire: ${_trackedParcel!.receiverName}\n\n'
        '🔗 Suivez votre colis: $trackingUrl',
        subject: 'Suivi de colis PRO COLIS',
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _playAudio(String audioUrl) async {
    try {
      if (_currentlyPlayingAudioUrl == audioUrl) {
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingAudioUrl = null;
        });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() {
          _currentlyPlayingAudioUrl = audioUrl;
        });
      }
    } catch (e) {
      debugPrint('Erreur lecture audio: $e');
    }
  }

  void _viewFullDetails() {
    if (_trackedParcel != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ParcelDetailScreen(parcel: _trackedParcel!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildDesignAppBar(),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () async {
                if (_trackingController.text.trim().isNotEmpty) {
                  await _trackParcel();
                }
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildDesignSearchCard(),
                  if (_trackedParcel != null) ...[
                    const SizedBox(height: 16),
                    _buildDesignTrackingHero(_trackedParcel!),
                    const SizedBox(height: 16),
                    _buildDesignDriverCard(_trackedParcel!),
                    const SizedBox(height: 16),
                    _buildDesignInfoCard(_trackedParcel!),
                    const SizedBox(height: 16),
                    ProcolisSectionHeader(title: 'Suivi'),
                    _buildDesignTimeline(_trackedParcel!),
                    const SizedBox(height: 16),
                    _buildDesignActions(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignAppBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 10,
        12,
        12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      child: Row(
        children: [
          if (!widget.embedded)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppTheme.textPrimary,
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Suivi colis',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                height: 1,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: _showScannerDialog,
            tooltip: 'Scanner',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.slate100,
              foregroundColor: AppTheme.primary,
            ),
          ),
          if (_trackedParcel != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: _clearSearch,
              tooltip: 'Nouvelle recherche',
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.slate100,
                foregroundColor: AppTheme.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesignSearchCard() {
    final suggestions = _generateSuggestions(_trackingController.text);

    return ProcolisCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rechercher un colis',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Entrez un numéro ou scannez un QR code',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _trackingController,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            style: GoogleFonts.robotoMono(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'PC-7F3K-2291',
              prefixIcon: const Icon(Icons.qr_code_2_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_trackingController.text.isNotEmpty)
                    IconButton(
                      onPressed: _trackingController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  IconButton(
                    onPressed: _showScannerDialog,
                    tooltip: 'Scanner',
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => _trackParcel(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSearching ? null : () => _trackParcel(),
                  icon: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search_rounded),
                  label: Text(_isSearching ? 'Recherche...' : 'Rechercher'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _showScannerDialog,
                tooltip: 'Scanner',
                icon: const Icon(Icons.qr_code_scanner_rounded),
                style: IconButton.styleFrom(
                  minimumSize: const Size(50, 50),
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: AppTheme.primary,
                ),
              ),
            ],
          ),
          if (_trackingController.text.isNotEmpty && suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map(_buildDesignTrackingChip).toList(),
              ),
            ),
          if (_recentSearches.isNotEmpty &&
              _trackedParcel == null &&
              !_isSearching &&
              _trackingController.text.isEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppTheme.slate200),
            const SizedBox(height: 12),
            const Text(
              'Recherches récentes',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map(_buildDesignTrackingChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesignTrackingChip(String tracking) {
    return ActionChip(
      avatar: const Icon(Icons.history_rounded, size: 16),
      label: Text(
        tracking,
        style:
            GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      onPressed: () => _trackParcel(trackingNumber: tracking),
      side: const BorderSide(color: AppTheme.slate200),
      backgroundColor: AppTheme.slate50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildDesignTrackingHero(Parcel parcel) {
    final price = parcel.negotiatedPrice ?? parcel.price;

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
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parcel.trackingNumber,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _DesignStatusBadge(status: parcel.status),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DesignRouteEnd(
                  label: 'Départ',
                  city: parcel.departureGarageName,
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 2,
                      color: Colors.white.withOpacity( 0.42),
                    ),
                    const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _DesignRouteEnd(
                  label: 'Arrivée',
                  city: parcel.arrivalGarageName ?? 'Destination',
                  alignRight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _DesignHeroMeta(
                  label: 'Distance', value: _estimateDistance(parcel)),
              const SizedBox(width: 16),
              _DesignHeroMeta(
                  label: 'Reste', value: _estimateRemaining(parcel)),
              const SizedBox(width: 16),
              _DesignHeroMeta(
                label: 'Prix',
                value: price == null ? '-- FCFA' : _formatMoney(price),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesignDriverCard(Parcel parcel) {
    if (!parcel.hasDriver) {
      return ProcolisCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _DesignSoftIcon(icon: Icons.person_search_rounded),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Chauffeur en attente d\'assignation',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ProcolisCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _DesignAvatar(name: parcel.driverName ?? 'Chauffeur'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parcel.driverName ?? 'Chauffeur',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Garage partenaire · 4,8 ★ · Camion',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _callDriver(parcel.driverPhone ?? ''),
            icon: const Icon(Icons.call_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              foregroundColor: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _viewFullDetails,
            icon: const Icon(Icons.chat_bubble_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              foregroundColor: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignInfoCard(Parcel parcel) {
    return ProcolisCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _DesignInfoRow(
            icon: Icons.category_rounded,
            label: 'Type',
            value: parcel.type.label,
          ),
          const Divider(height: 1, color: AppTheme.slate200),
          _DesignInfoRow(
            icon: Icons.scale_rounded,
            label: 'Poids',
            value: parcel.formattedWeight,
            mono: true,
          ),
          const Divider(height: 1, color: AppTheme.slate200),
          _DesignInfoRow(
            icon: Icons.person_pin_rounded,
            label: 'Destinataire',
            value: parcel.receiverName,
          ),
          const Divider(height: 1, color: AppTheme.slate200),
          _DesignInfoRow(
            icon: Icons.call_rounded,
            label: 'Téléphone',
            value: parcel.receiverPhone,
            mono: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDesignTimeline(Parcel parcel) {
    final steps = [
      const _TrackingStep('Créé', 'pending', Icons.inventory_2_rounded),
      const _TrackingStep('Confirmé', 'confirmed', Icons.task_alt_rounded),
      const _TrackingStep('Pris en charge', 'picked_up', Icons.local_shipping_rounded),
      const _TrackingStep('En transit', 'in_transit', Icons.route_rounded),
      const _TrackingStep('Arrivé', 'arrived', Icons.flag_rounded),
      const _TrackingStep('Livraison', 'out_for_delivery', Icons.delivery_dining_rounded),
      const _TrackingStep('Livré', 'delivered', Icons.verified_rounded),
    ];

    return ProcolisCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _DesignTimelineItem(
              title: steps[i].label,
              icon: steps[i].icon,
              completed: _isStepCompleted(parcel, steps[i].status),
              last: i == steps.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildDesignActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showReceiptDialog,
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Voir le reçu'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _viewFullDetails,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Détail'),
          ),
        ),
      ],
    );
  }

  String _formatMoney(num value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      final reverseIndex = rounded.length - i;
      buffer.write(rounded[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write(' ');
    }
    return '$buffer FCFA';
  }

  String _estimateDistance(Parcel parcel) {
    if (parcel.departureGarageName.isEmpty ||
        (parcel.arrivalGarageName ?? '').isEmpty) {
      return '-- km';
    }
    return '240 km';
  }

  String _estimateRemaining(Parcel parcel) {
    final eta = parcel.estimatedDeliveryDate;
    if (eta == null) return '~2 h';
    final hours = eta.difference(DateTime.now()).inHours.abs();
    return '~${hours.clamp(1, 96)} h';
  }

  Future<void> _callDriver(String phone) async {
    if (phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildSearchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.search_rounded,
                size: 32,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Suivez votre colis en temps réel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Entrez votre numéro de suivi ou scannez le QR code',
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _trackingController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Ex: COL-20260526-ADE4B8',
                prefixIcon: Icon(Icons.search, color: primaryBlue),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_trackingController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _trackingController.clear(),
                      ),
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner, color: primaryBlue),
                      onPressed: _showScannerDialog,
                      tooltip: 'Scanner un QR code',
                    ),
                  ],
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryBlue, width: 1.5),
                ),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              onSubmitted: (_) => _trackParcel(),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Suivre mon colis',
              onPressed: () => _trackParcel(),
              isLoading: _isSearching,
            ),
            if (_trackingController.text.isNotEmpty &&
                _generateSuggestions(_trackingController.text).isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Suggestions:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ..._generateSuggestions(_trackingController.text).map(
                      (suggestion) => ListTile(
                        dense: true,
                        leading:
                            Icon(Icons.history, size: 18, color: primaryBlue),
                        title: Text(
                          suggestion,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                        ),
                        trailing: const Icon(Icons.arrow_forward, size: 18),
                        onTap: () {
                          _trackingController.text = suggestion;
                          _trackParcel();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            if (_recentSearches.isNotEmpty &&
                _trackedParcel == null &&
                !_isSearching &&
                _trackingController.text.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recherches récentes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _recentSearches.clear();
                          });
                        },
                        child: const Text(
                          'Effacer tout',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _recentSearches.map((search) {
                      return GestureDetector(
                        onTap: () => _trackParcel(trackingNumber: search),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                search,
                                style: const TextStyle(
                                    fontSize: 12, fontFamily: 'monospace'),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _removeRecentSearch(search),
                                child: const Icon(Icons.close,
                                    size: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParcelResultCard() {
    final parcel = _trackedParcel!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.04),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: parcel.status.color.withOpacity( 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        parcel.status.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: parcel.status.color),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      parcel.trackingNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                if (parcel.price != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity( 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('Total',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          parcel.formattedPrice,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            _buildStatusTimeline(parcel),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            _buildInfoRow(
                Icons.person_outline, 'Expéditeur', parcel.senderName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Destinataire', parcel.receiverName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.description, 'Description', parcel.description),
            const SizedBox(height: 12),
            _buildInfoRow(
                Icons.fitness_center, 'Poids', parcel.formattedWeight),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.category, 'Type', parcel.type.label),
            const SizedBox(height: 12),
            _buildInfoRow(
                Icons.departure_board, 'Départ', parcel.departureGarageName),
            if (parcel.arrivalGarageName != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                  Icons.location_on, 'Arrivée', parcel.arrivalGarageName!),
            ],
            if (parcel.hasDriver) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.delivery_dining, 'Chauffeur',
                  parcel.driverName ?? 'Non assigné'),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOptionChip('Urgent', parcel.isUrgent, Colors.red),
                _buildOptionChip('Assuré', parcel.isInsured, Colors.blue),
                _buildOptionChip('Payé', parcel.isPaid, Colors.green),
                _buildOptionChip('Chauffeur', parcel.hasDriver, Colors.orange),
                _buildOptionChip(
                    'En cours', parcel.isInProgress, Colors.purple),
                _buildOptionChip('Terminé', parcel.isFinished, Colors.teal),
              ],
            ),
            if (parcel.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Photos',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: parcel.photoUrls.length,
                  itemBuilder: (context, index) {
                    return _buildPhotoThumbnail(parcel.photoUrls[index]);
                  },
                ),
              ),
            ],
            if (parcel.audioUrls.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Messages vocaux',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: parcel.audioUrls.map((audioUrl) {
                  final isPlaying = _currentlyPlayingAudioUrl == audioUrl;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.stop : Icons.play_arrow,
                            size: 18,
                            color: primaryBlue,
                          ),
                          onPressed: () => _playAudio(audioUrl),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        const Text('Message vocal',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _viewFullDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Voir tous les détails',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _shareTrackingNumber,
            icon: Icon(Icons.share, size: 18, color: primaryBlue),
            label: const Text('Partager'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryBlue,
              side: BorderSide(color: primaryBlue),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showReceiptDialog,
            icon: Icon(Icons.receipt_long, size: 18, color: primaryBlue),
            label: const Text('Reçu'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryBlue,
              side: BorderSide(color: primaryBlue),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity( 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: primaryBlue),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTimeline(Parcel parcel) {
    const steps = [
      {'status': 'pending', 'label': 'Création', 'icon': Icons.create},
      {'status': 'confirmed', 'label': 'Confirmé', 'icon': Icons.check_circle},
      {'status': 'picked_up', 'label': 'Ramassé', 'icon': Icons.local_shipping},
      {
        'status': 'in_transit',
        'label': 'En transit',
        'icon': Icons.transfer_within_a_station
      },
      {'status': 'arrived', 'label': 'Arrivé', 'icon': Icons.location_on},
      {
        'status': 'out_for_delivery',
        'label': 'En livraison',
        'icon': Icons.delivery_dining
      },
      {'status': 'delivered', 'label': 'Livré', 'icon': Icons.check_circle},
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = _isStepCompleted(parcel, step['status'] as String);
        final isLast = index == steps.length - 1;
        final isCurrent = parcel.status.value == step['status'];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? primaryBlue : Colors.grey.shade300,
                  ),
                  child: Icon(step['icon'] as IconData,
                      color: Colors.white, size: 20),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    color: isCompleted ? primaryBlue : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step['label'] as String,
                      style: TextStyle(
                        fontWeight:
                            isCompleted ? FontWeight.bold : FontWeight.normal,
                        color: isCompleted ? primaryBlue : Colors.grey,
                      ),
                    ),
                    if (isCurrent)
                      const Text(
                        'En cours',
                        style: TextStyle(fontSize: 12, color: primaryBlue),
                      ),
                    if (step['status'] == 'delivered' &&
                        parcel.deliveryDate != null)
                      Text(
                        _formatDate(parcel.deliveryDate!),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPhotoThumbnail(String url) {
    final fullUrl = url.startsWith('http')
        ? url
        : 'https://procolis-backend.onrender.com$url';
    return GestureDetector(
      onTap: () => _showPhotoDialog(fullUrl),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade200,
          image: DecorationImage(
            image: NetworkImage(fullUrl),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) =>
                debugPrint('Erreur chargement image: $exception'),
          ),
        ),
      ),
    );
  }

  void _showPhotoDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildOptionChip(String label, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? color.withOpacity( 0.15)
            : Colors.grey.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? color : Colors.grey.shade300,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.circle_outlined,
            size: 12,
            color: isActive ? color : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isActive ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignStatusBadge extends StatelessWidget {
  final ParcelStatus status;

  const _DesignStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.statusColors(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity( 0.94),
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
          Text(
            status.label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: colors.foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignRouteEnd extends StatelessWidget {
  final String label;
  final String city;
  final bool alignRight;

  const _DesignRouteEnd({
    required this.label,
    required this.city,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          city.isEmpty ? 'Ville' : city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DesignHeroMeta extends StatelessWidget {
  final String label;
  final String value;

  const _DesignHeroMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignSoftIcon extends StatelessWidget {
  final IconData icon;

  const _DesignSoftIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Icon(icon, color: AppTheme.primary),
    );
  }
}

class _DesignAvatar extends StatelessWidget {
  final String name;

  const _DesignAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: AppTheme.teal50,
          child: Text(
            initials.isEmpty ? 'CH' : initials,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.teal700,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 13,
            height: 13,
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

class _DesignInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _DesignInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (mono ? GoogleFonts.robotoMono() : GoogleFonts.manrope())
                  .copyWith(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignTimelineItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool completed;
  final bool last;

  const _DesignTimelineItem({
    required this.title,
    required this.icon,
    required this.completed,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppTheme.primary : AppTheme.slate300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: completed ? AppTheme.primaryLight : AppTheme.slate100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            if (!last)
              Container(
                width: 2,
                height: 30,
                color: completed ? AppTheme.primaryLight : AppTheme.slate200,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color:
                    completed ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: completed ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
        if (completed)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.check_rounded, color: AppTheme.primary, size: 18),
          ),
      ],
    );
  }
}

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(color: Colors.black),
          const _ScannerOverlay(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filled(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity( 0.45),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton.filled(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.content_paste_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity( 0.45),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity( 0.55),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Scanner un colis',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Collez le contenu du QR code ou entrez le numéro de suivi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _controller,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            hintText: 'PC-7F3K-2291 ou URL QR',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity( 0.12),
                            prefixIcon: const Icon(
                              Icons.qr_code_2_rounded,
                              color: Colors.white70,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pasteFromClipboard,
                                icon: const Icon(Icons.content_paste_rounded),
                                label: const Text('Coller'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white30),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _submit,
                                icon: const Icon(Icons.search_rounded),
                                label: const Text('Rechercher'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF018982),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _controller.text = text;
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Stack(
            children: const [
              _ScannerCorner(alignment: Alignment.topLeft),
              _ScannerCorner(alignment: Alignment.topRight),
              _ScannerCorner(alignment: Alignment.bottomLeft),
              _ScannerCorner(alignment: Alignment.bottomRight),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerCorner extends StatelessWidget {
  final Alignment alignment;

  const _ScannerCorner({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 42,
        height: 42,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0
                ? const BorderSide(color: Color(0xFF018982), width: 5)
                : BorderSide.none,
            bottom: alignment.y > 0
                ? const BorderSide(color: Color(0xFF018982), width: 5)
                : BorderSide.none,
            left: alignment.x < 0
                ? const BorderSide(color: Color(0xFF018982), width: 5)
                : BorderSide.none,
            right: alignment.x > 0
                ? const BorderSide(color: Color(0xFF018982), width: 5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _TrackingStep {
  final String label;
  final String status;
  final IconData icon;
  const _TrackingStep(this.label, this.status, this.icon);
}
