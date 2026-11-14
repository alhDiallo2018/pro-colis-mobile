// lib/widgets/parcel_tracking_share_card.dart
//
// Carte de suivi partageable (QR + numéro + statut) capturée en PNG. Même
// principe que PaymentReceiptCard : un bottom-sheet avec aperçu, deux
// boutons (texte / image). Fallback texte si capture échoue.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';

class ParcelTrackingShareCard extends StatelessWidget {
  final String trackingNumber;
  final String? statusLabel;
  final String? senderName;
  final String? receiverName;
  final String trackingUrl;

  const ParcelTrackingShareCard({
    super.key,
    required this.trackingNumber,
    required this.trackingUrl,
    this.statusLabel,
    this.senderName,
    this.receiverName,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.softShadow(alpha: 0.12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.local_shipping_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'SendProColis',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ]),
                  const Text(
                    'SUIVI',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: QrImageView(
                data: trackingUrl,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
                // Foreground forcé noir : un QR en mode sombre reste
                // scannable si l'image est reçue dans une app aux thèmes
                // variables.
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              trackingNumber,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppTheme.textPrimary,
              ),
            ),
            if (statusLabel != null && statusLabel!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.teal50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel!,
                  style: TextStyle(
                    color: AppTheme.teal700,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (senderName != null && senderName!.trim().isNotEmpty)
              _line(Icons.person_outline, 'Expéditeur', senderName!),
            if (receiverName != null && receiverName!.trim().isNotEmpty)
              _line(
                  Icons.person_pin_circle_outlined, 'Destinataire', receiverName!),
            const SizedBox(height: 10),
            Text(
              'Scannez le QR ou visitez le lien pour suivre le colis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

String buildTrackingShareText({
  required String trackingNumber,
  required String trackingUrl,
  String? statusLabel,
  String? senderName,
  String? receiverName,
}) {
  return '📦 Suivi de colis SendProColis\n\n'
      '🔹 N° de suivi : $trackingNumber\n'
      '${statusLabel == null || statusLabel.isEmpty ? '' : '🔹 Statut : $statusLabel\n'}'
      '${senderName == null || senderName.isEmpty ? '' : '🔹 Expéditeur : $senderName\n'}'
      '${receiverName == null || receiverName.isEmpty ? '' : '🔹 Destinataire : $receiverName\n'}'
      '\n🔗 Suivez votre colis : $trackingUrl';
}

Future<void> shareParcelTracking(
  BuildContext context, {
  required String trackingNumber,
  required String trackingUrl,
  String? statusLabel,
  String? senderName,
  String? receiverName,
  Rect? sharePositionOrigin,
}) async {
  final captureKey = GlobalKey();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.slate300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                RepaintBoundary(
                  key: captureKey,
                  child: ParcelTrackingShareCard(
                    trackingNumber: trackingNumber,
                    trackingUrl: trackingUrl,
                    statusLabel: statusLabel,
                    senderName: senderName,
                    receiverName: receiverName,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Share.share(
                          buildTrackingShareText(
                            trackingNumber: trackingNumber,
                            trackingUrl: trackingUrl,
                            statusLabel: statusLabel,
                            senderName: senderName,
                            receiverName: receiverName,
                          ),
                          subject: 'Suivi SendProColis · $trackingNumber',
                          sharePositionOrigin: sharePositionOrigin,
                        ),
                        icon: const Icon(Icons.text_snippet_outlined),
                        label: const Text('Texte seul'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _shareCapture(
                          ctx,
                          captureKey,
                          trackingNumber: trackingNumber,
                          trackingUrl: trackingUrl,
                          statusLabel: statusLabel,
                          senderName: senderName,
                          receiverName: receiverName,
                          sharePositionOrigin: sharePositionOrigin,
                        ),
                        icon: const Icon(Icons.image_rounded),
                        label: const Text('Partager en image'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _shareCapture(
  BuildContext context,
  GlobalKey captureKey, {
  required String trackingNumber,
  required String trackingUrl,
  String? statusLabel,
  String? senderName,
  String? receiverName,
  Rect? sharePositionOrigin,
}) async {
  try {
    final boundary = captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('no_boundary');
    await WidgetsBinding.instance.endOfFrame;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('encode_failed');
    final bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final safe = trackingNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File(
      '${dir.path}/suivi_sendprocolis_${safe}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: buildTrackingShareText(
        trackingNumber: trackingNumber,
        trackingUrl: trackingUrl,
        statusLabel: statusLabel,
        senderName: senderName,
        receiverName: receiverName,
      ),
      subject: 'Suivi SendProColis · $trackingNumber',
      sharePositionOrigin: sharePositionOrigin,
    );
  } catch (_) {
    if (!context.mounted) return;
    await Share.share(
      buildTrackingShareText(
        trackingNumber: trackingNumber,
        trackingUrl: trackingUrl,
        statusLabel: statusLabel,
        senderName: senderName,
        receiverName: receiverName,
      ),
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
