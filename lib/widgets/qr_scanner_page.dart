// lib/widgets/qr_scanner_page.dart
//
// Écran scanner QR réutilisable. Ouvre la caméra, détecte le premier code
// QR/data-matrix/code128, retourne la valeur brute via `Navigator.pop`.
//
// Usage :
//   final code = await Navigator.of(context).push<String>(
//     MaterialPageRoute(builder: (_) => const QrScannerPage()),
//   );

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  final String title;

  const QrScannerPage({super.key, this.title = 'Scanner un code'});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
    ],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (code.isEmpty) return;
    _handled = true;
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final icon = state.torchState == TorchState.on
                  ? Icons.flash_on
                  : Icons.flash_off;
              return IconButton(
                onPressed: () => _controller.toggleTorch(),
                icon: Icon(icon),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: _buildError,
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final msg = denied
        ? "Autorisez l'accès à la caméra dans les réglages pour scanner un QR."
        : "La caméra n'est pas disponible : ${error.errorDetails?.message ?? "erreur inconnue"}.";
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
