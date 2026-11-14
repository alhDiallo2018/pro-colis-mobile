// lib/widgets/delivery_receipt_card.dart
//
// Reçu de livraison moderne, remplace l'ancien layout plat « emoji + texte »
// par un design brandé : bandeau dégradé, QR centré, lignes propres avec
// icônes, pied de page support. Capturé en PNG 3x pour le partage image.
//
// Trois points d'entrée mobile :
//   - parcel_detail_screen (sheet « Reçu de livraison »)
//   - track_parcel_screen  (même sheet)
// Les deux appelants passent un `Parcel` + URL de suivi ; le widget est
// responsable du rendu, le reste reste côté écran.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../models/parcel.dart';
import '../theme/app_theme.dart';

class DeliveryReceiptCard extends StatelessWidget {
  final Parcel parcel;
  final String trackingUrl;
  final String? supportPhone;
  final String? supportEmail;

  const DeliveryReceiptCard({
    super.key,
    required this.parcel,
    required this.trackingUrl,
    this.supportPhone,
    this.supportEmail,
  });

  @override
  Widget build(BuildContext context) {
    final isDelivered = parcel.status.value == 'delivered';
    final statusTone =
        isDelivered ? AppTheme.green600 : AppTheme.amber500;
    final statusBg = isDelivered
        ? AppTheme.green50
        : AppTheme.amber50;

    return RepaintBoundary(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.softShadow(alpha: 0.12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bandeau dégradé : brand + statut
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 16),
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
                    'REÇU DE LIVRAISON',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Pastille de statut
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDelivered
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        color: statusTone,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        parcel.status.label,
                        style: TextStyle(
                          color: statusTone,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // QR bien centré, fond blanc fixe pour rester scannable
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: QrImageView(
                  data: trackingUrl,
                  version: QrVersions.auto,
                  size: 150,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
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
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                parcel.trackingNumber,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Divider(),
            const SizedBox(height: 10),
            _row(Icons.event_rounded, 'Date',
                formatDate(parcel.createdAt)),
            _row(Icons.person_outline, 'Expéditeur', parcel.senderName),
            _row(Icons.person_pin_circle_outlined, 'Destinataire',
                parcel.receiverName),
            _row(Icons.place_outlined, 'Départ', parcel.departureZoneName),
            if (parcel.arrivalZoneName != null)
              _row(Icons.flag_outlined, 'Arrivée', parcel.arrivalZoneName!),
            _row(Icons.scale_outlined, 'Poids', parcel.formattedWeight),
            _row(Icons.payments_outlined, 'Montant',
                parcel.formattedAgreedPrice, isBold: true),
            if (isDelivered && parcel.deliveryDate != null)
              _row(Icons.task_alt_rounded, 'Livré le',
                  formatDate(parcel.deliveryDate!),
                  tone: AppTheme.green600),
            const SizedBox(height: 14),
            _Divider(),
            const SizedBox(height: 10),
            Text(
              'SendProColis — Transport national & international',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if ((supportPhone?.isNotEmpty ?? false) ||
                (supportEmail?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (supportPhone?.isNotEmpty ?? false) '☎ $supportPhone',
                  if (supportEmail?.isNotEmpty ?? false) '✉ $supportEmail',
                ].join('   ·   '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value,
      {bool isBold = false, Color? tone}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tone ?? AppTheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
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
                color: tone ?? AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static String formatDate(DateTime d) {
    try {
      return DateFormat('d MMM y · HH:mm', 'fr').format(d.toLocal());
    } catch (_) {
      return d.toLocal().toString();
    }
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      const dash = 6.0;
      const gap = 4.0;
      final count = (width / (dash + gap)).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          count,
          (_) => Container(width: dash, height: 1, color: AppTheme.slate300),
        ),
      );
    });
  }
}

/// Ouvre la feuille modale « Reçu de livraison » : aperçu + deux boutons
/// (texte / image). La capture utilise une clé interne : l'appelant n'a
/// rien à gérer.
Future<void> showDeliveryReceiptSheet(
  BuildContext context, {
  required Parcel parcel,
  String? supportPhone,
  String? supportEmail,
}) {
  final captureKey = GlobalKey();
  final trackingUrl = AppConfig.trackingUrl(parcel.trackingNumber);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
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
                    child: DeliveryReceiptCard(
                      parcel: parcel,
                      trackingUrl: trackingUrl,
                      supportPhone: supportPhone,
                      supportEmail: supportEmail,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Share.share(
                            _receiptText(parcel, trackingUrl),
                            subject:
                                'Reçu SendProColis · ${parcel.trackingNumber}',
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
                            parcel: parcel,
                            trackingUrl: trackingUrl,
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
        ),
      );
    },
  );
}

String _receiptText(Parcel parcel, String trackingUrl) {
  final b = StringBuffer();
  b.writeln('📦 Reçu de livraison SendProColis');
  b.writeln();
  b.writeln('N° de suivi : ${parcel.trackingNumber}');
  b.writeln('Statut       : ${parcel.status.label}');
  b.writeln('Expéditeur   : ${parcel.senderName}');
  b.writeln('Destinataire : ${parcel.receiverName}');
  if (parcel.arrivalZoneName != null) {
    b.writeln(
        'Trajet       : ${parcel.departureZoneName} → ${parcel.arrivalZoneName}');
  } else {
    b.writeln('Départ       : ${parcel.departureZoneName}');
  }
  b.writeln('Poids        : ${parcel.formattedWeight}');
  b.writeln('Montant      : ${parcel.formattedAgreedPrice}');
  if (parcel.deliveryDate != null) {
    b.writeln(
        'Livré le     : ${DeliveryReceiptCard.formatDate(parcel.deliveryDate!)}');
  }
  b.writeln();
  b.writeln('🔗 Suivre en ligne : $trackingUrl');
  return b.toString();
}

Future<void> _shareCapture(
  BuildContext context,
  GlobalKey captureKey, {
  required Parcel parcel,
  required String trackingUrl,
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
    final safe =
        parcel.trackingNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File(
      '${dir.path}/recu_livraison_${safe}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: _receiptText(parcel, trackingUrl),
      subject: 'Reçu de livraison · ${parcel.trackingNumber}',
    );
  } catch (_) {
    if (!context.mounted) return;
    await Share.share(_receiptText(parcel, trackingUrl));
  }
}
