// lib/screens/parcel/handover_confirm_screen.dart
//
// Phase 2 — Écran du driver entrant pour confirmer une correspondance.
// Flux :
//   1. Saisie du handover ID + PIN + QR token (QR scanner à brancher plus
//      tard — ici champ texte).
//   2. Envoi `POST /parcels/:id/handovers/:id/confirm`.
//   3. Confirmation visuelle, le colis est désormais assigné au driver entrant.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers/handover_provider.dart';
import '../../widgets/qr_scanner_page.dart';

class HandoverConfirmScreen extends ConsumerStatefulWidget {
  final String parcelId;

  const HandoverConfirmScreen({super.key, required this.parcelId});

  @override
  ConsumerState<HandoverConfirmScreen> createState() =>
      _HandoverConfirmScreenState();
}

class _HandoverConfirmScreenState extends ConsumerState<HandoverConfirmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _handoverIdCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _handoverIdCtrl.dispose();
    _pinCtrl.dispose();
    _qrCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final h = await ref.read(handoverControllerProvider.notifier).confirm(
          parcelId: widget.parcelId,
          handoverId: _handoverIdCtrl.text.trim(),
          pin: _pinCtrl.text.trim(),
          qrToken: _qrCtrl.text.trim(),
        );
    if (!mounted) return;
    if (h != null) {
      setState(() => _done = true);
    } else {
      final err = ref.read(handoverControllerProvider).error ?? 'Erreur';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(handoverControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).handoverConfirmTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _done ? _buildSuccess() : _buildForm(state.busy),
      ),
    );
  }

  Widget _buildForm(bool busy) {
    final l = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.handoverConfirmExplain),
          const SizedBox(height: 16),
          TextFormField(
            controller: _handoverIdCtrl,
            decoration: InputDecoration(
              labelText: l.handoverConfirmIdLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Champ requis' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l.handoverConfirmPinLabel,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty) return 'Champ requis';
              if (!RegExp(r'^\d{6}$').hasMatch(s)) {
                return 'Six chiffres requis';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _qrCtrl,
                  decoration: InputDecoration(
                    labelText: l.handoverConfirmQrLabel,
                    border: const OutlineInputBorder(),
                    helperText: l.handoverConfirmQrHelper,
                  ),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Champ requis' : null,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconButton.filledTonal(
                  tooltip: l.handoverConfirmScanTooltip,
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final code = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                          builder: (_) => QrScannerPage(
                              title: l.handoverConfirmScanTooltip)),
                    );
                    if (!mounted || code == null || code.isEmpty) return;
                    setState(() => _qrCtrl.text = code);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : _submit,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user),
            label: Text(busy ? 'Vérification...' : l.handoverConfirmSubmit),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        const SizedBox(height: 24),
        Icon(Icons.check_circle, size: 72, color: Colors.green.shade600),
        const SizedBox(height: 16),
        Text(
          l.handoverConfirmSuccess,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          l.handoverConfirmSuccessBody,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Retour'),
        ),
      ],
    );
  }
}
