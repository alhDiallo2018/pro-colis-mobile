// lib/widgets/referral_invite_card.dart
//
// Carte d'invitation brandée pour le partage. Capturée en PNG via
// RepaintBoundary pour offrir une image Instagram/WhatsApp au lieu
// d'un texte brut. Tombe sur texte seul si la capture échoue.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';

class ReferralInviteCard extends StatelessWidget {
  final String code;
  const ReferralInviteCard({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.card_giftcard_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 6),
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
                  'INVITATION',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Rejoignez-moi\nsur SendProColis',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Expédiez partout au Sénégal\nen quelques tap.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text(
                    'MON CODE',
                    style: TextStyle(
                      // Fond blanc toujours : couleur fixe grise foncée
                      // pour garantir le contraste quel que soit le mode.
                      color: Color(0xFF677474),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      // Teinte brand, fixe en light mode (teal500) pour
                      // contraster avec le fond blanc. En dark mode, le QR
                      // bg reste blanc donc idem.
                      color: const Color(0xFF018982),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.redeem_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Bonus à votre première livraison',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> shareReferralCode(BuildContext context, String code) async {
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
                  child: ReferralInviteCard(code: code),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Share.share(_inviteText(code)),
                        icon: const Icon(Icons.text_snippet_outlined),
                        label: const Text('Texte seul'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _shareInviteCapture(ctx, captureKey, code),
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

String _inviteText(String code) =>
    "Rejoignez-moi sur SendProColis avec mon code $code "
    "— vous bénéficierez d'un bonus à votre première livraison.";

Future<void> _shareInviteCapture(
    BuildContext context, GlobalKey captureKey, String code) async {
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
    final file = File(
      '${dir.path}/invite_sendprocolis_${code}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: _inviteText(code),
      subject: 'Rejoignez-moi sur SendProColis',
    );
  } catch (_) {
    if (!context.mounted) return;
    await Share.share(_inviteText(code));
  }
}
