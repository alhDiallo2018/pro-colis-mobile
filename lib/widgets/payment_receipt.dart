// lib/widgets/payment_receipt.dart
//
// Carte « reçu de paiement » avec capture en image pour le partage. Rendue
// hors-écran pour la capture (RepaintBoundary + path_provider), le ratio
// pixelRatio=3 produit une image nette sur Instagram Stories / WhatsApp.
//
// Le partage texte reste accessible en fallback si la capture échoue
// (ancienne image/vieux device), et le texte est ajouté au `subject` du
// Share pour accompagner l'image.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api/experience_api.dart';
import '../theme/app_theme.dart';

/// Reçu de paiement SendProColis, modèle visuel unique partagé par le mobile
/// et l'export image. Affiché dans un BottomSheet puis capturé pour partage.
class PaymentReceiptCard extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final String trackingNumber;
  final String? senderName;
  final String? receiverName;

  const PaymentReceiptCard({
    super.key,
    required this.receipt,
    required this.trackingNumber,
    this.senderName,
    this.receiverName,
  });

  @override
  Widget build(BuildContext context) {
    final amount = receipt['amount'];
    final reference = receipt['reference']?.toString() ??
        receipt['id']?.toString() ??
        '—';
    final method = _formatMethod(receipt['method']?.toString());
    final createdAt = _formatDate(receipt['createdAt']?.toString());

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bandeau dégradé avec le montant
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.verified_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        const Text(
                          'SendProColis',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ]),
                      const Text(
                        'REÇU',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Montant confirmé',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    experienceMoney(amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _row(Icons.qr_code_2_rounded, 'Colis', trackingNumber),
            _row(Icons.confirmation_number_outlined, 'Référence', reference),
            if (senderName != null && senderName!.trim().isNotEmpty)
              _row(Icons.person_outline, 'Expéditeur', senderName!),
            if (receiverName != null && receiverName!.trim().isNotEmpty)
              _row(Icons.person_pin_circle_outlined, 'Destinataire',
                  receiverName!),
            _row(Icons.payments_outlined, 'Moyen', method),
            _row(Icons.event_rounded, 'Date', createdAt),
            const SizedBox(height: 18),
            // Perforation style ticket
            _Dashes(color: AppTheme.slate300),
            const SizedBox(height: 14),
            Text(
              'Document généré par SendProColis — conservez-le comme justificatif de paiement.',
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

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
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
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMethod(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    const labels = {
      'cash': 'Espèces',
      'paydunya': 'Paydunya',
      'orange_money': 'Orange Money',
      'wave': 'Wave',
      'free_money': 'Free Money',
      'wallet': 'Portefeuille',
      'card': 'Carte bancaire',
      'bank_transfer': 'Virement',
    };
    return labels[raw.toLowerCase()] ?? raw;
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return raw;
    try {
      return DateFormat('d MMM y · HH:mm', 'fr').format(d);
    } catch (_) {
      return d.toString();
    }
  }
}

class _Dashes extends StatelessWidget {
  final Color color;
  const _Dashes({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const dash = 6.0;
        const gap = 4.0;
        final count = (width / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dash,
              height: 1,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

/// Ouvre une feuille modale affichant le reçu et propose un bouton de
/// partage qui capture le widget en image PNG. Un bouton secondaire permet
/// toujours de partager le texte brut (fallback compatibilité).
Future<void> showPaymentReceiptSheet(
  BuildContext context, {
  required Map<String, dynamic> receipt,
  required String trackingNumber,
  String? senderName,
  String? receiverName,
}) {
  final captureKey = GlobalKey();
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
                    child: PaymentReceiptCard(
                      receipt: receipt,
                      trackingNumber: trackingNumber,
                      senderName: senderName,
                      receiverName: receiverName,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Share.share(
                              receiptText(receipt, trackingNumber),
                            );
                          },
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
                            receipt: receipt,
                            trackingNumber: trackingNumber,
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

Future<void> _shareCapture(
  BuildContext context,
  GlobalKey captureKey, {
  required Map<String, dynamic> receipt,
  required String trackingNumber,
}) async {
  try {
    final boundary = captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;
    // Attendre la frame suivante pour s'assurer que le layout est stable
    // (sinon toImage peut capturer un intermédiaire flouté).
    await WidgetsBinding.instance.endOfFrame;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('encode_failed');
    final bytes = byteData.buffer.asUint8List();
    final file = await _writeTempPng(bytes, trackingNumber);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: receiptText(receipt, trackingNumber),
      subject: 'Reçu SendProColis · $trackingNumber',
    );
  } catch (_) {
    if (!context.mounted) return;
    await Share.share(receiptText(receipt, trackingNumber));
  }
}

Future<File> _writeTempPng(Uint8List bytes, String tracking) async {
  final dir = await getTemporaryDirectory();
  final safeName = tracking.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final file = File(
    '${dir.path}/recu_sendprocolis_${safeName}_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  return file.writeAsBytes(bytes, flush: true);
}
