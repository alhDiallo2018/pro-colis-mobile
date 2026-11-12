// lib/screens/parcel/handover_initiate_screen.dart
//
// Phase 2 — Écran du driver sortant pour initier une correspondance.
// Flux :
//   1. Saisie de l'ID driver entrant (scannable via QR du driver cible dans
//      une version future — ici champ texte simple).
//   2. Envoi `POST /parcels/:id/handovers`.
//   3. Affichage grand format du PIN (6 chiffres) et d'un QR code encodant
//      le token. Ces secrets ne sont jamais ré-exposés : l'écran rappelle
//      au driver de les communiquer tout de suite au driver entrant.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers/handover_provider.dart';
import '../../services/api/handover_api.dart';

class HandoverInitiateScreen extends ConsumerStatefulWidget {
  final String parcelId;

  const HandoverInitiateScreen({super.key, required this.parcelId});

  @override
  ConsumerState<HandoverInitiateScreen> createState() =>
      _HandoverInitiateScreenState();
}

class _HandoverInitiateScreenState
    extends ConsumerState<HandoverInitiateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _toDriverIdController = TextEditingController();
  ParcelHandover? _issued;

  @override
  void dispose() {
    _toDriverIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final handover = await ref.read(handoverControllerProvider.notifier).initiate(
          parcelId: widget.parcelId,
          toDriverId: _toDriverIdController.text.trim(),
        );
    if (!mounted) return;
    if (handover != null) {
      setState(() => _issued = handover);
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
      appBar: AppBar(title: Text(AppLocalizations.of(context).handoverInitiateTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _issued == null
            ? _buildForm(state.busy)
            : _buildSecrets(_issued!),
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
          Text(l.handoverInitiateExplain),
          const SizedBox(height: 16),
          TextFormField(
            controller: _toDriverIdController,
            decoration: InputDecoration(
              labelText: l.handoverInitiateDriverFieldLabel,
              helperText: l.handoverInitiateDriverFieldHelper,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty) return 'Champ requis';
              final uuidRe = RegExp(
                  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                  caseSensitive: false);
              if (!uuidRe.hasMatch(s)) return 'Identifiant invalide';
              return null;
            },
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
                : const Icon(Icons.send),
            label: Text(busy ? 'Envoi...' : l.handoverInitiateSubmit),
          ),
        ],
      ),
    );
  }

  Widget _buildSecrets(ParcelHandover h) {
    final l = AppLocalizations.of(context);
    final pin = h.pickupPin ?? '';
    final qr = h.pickupQrToken ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.amber.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.warning_amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.handoverInitiateWarning,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  l.handoverPinLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  pin,
                  style: const TextStyle(
                    fontSize: 42,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pin));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN copié')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(l.handoverCopy),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.handoverQrLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  qr,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: qr));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Jeton QR copié')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(l.handoverCopy),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.check),
          label: Text(l.handoverDone),
        ),
      ],
    );
  }
}
