// lib/screens/parcel/parcel_customs_screen.dart
//
// SCP-040 — Déclaration douanière structurée pour un colis international.
// Form de saisie + action sign (fige). Après signature, les champs sont en
// lecture seule et le bouton « Devis carriers » devient actif.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/customs_provider.dart';
import '../../services/api/customs_api.dart';
import '../../theme/app_theme.dart';

const _purposes = ['personal', 'gift', 'sample', 'commercial', 'return'];

class ParcelCustomsScreen extends ConsumerStatefulWidget {
  final String parcelId;

  const ParcelCustomsScreen({super.key, required this.parcelId});

  @override
  ConsumerState<ParcelCustomsScreen> createState() => _ParcelCustomsScreenState();
}

class _ParcelCustomsScreenState extends ConsumerState<ParcelCustomsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _hsCodeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'XOF');
  final _weightCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  String _purpose = 'personal';
  bool _isDangerous = false;
  bool _initialized = false;
  bool _existing = false;

  @override
  void dispose() {
    for (final c in [_originCtrl, _destCtrl, _descCtrl, _hsCodeCtrl, _valueCtrl, _currencyCtrl, _weightCtrl, _quantityCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(ParcelCustoms c) {
    _originCtrl.text = c.originCountry;
    _destCtrl.text = c.destinationCountry;
    _descCtrl.text = c.contentsDescription;
    _hsCodeCtrl.text = c.hsCode ?? '';
    _valueCtrl.text = c.declaredValue.toStringAsFixed(0);
    _currencyCtrl.text = c.declaredCurrency;
    _weightCtrl.text = c.weightKg?.toStringAsFixed(2) ?? '';
    _quantityCtrl.text = c.quantity.toString();
    _purpose = _purposes.contains(c.purpose) ? c.purpose : 'personal';
    _isDangerous = c.isDangerous;
    _existing = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final body = {
      'originCountry': _originCtrl.text.trim().toUpperCase(),
      'destinationCountry': _destCtrl.text.trim().toUpperCase(),
      'contentsDescription': _descCtrl.text.trim(),
      if (_hsCodeCtrl.text.trim().isNotEmpty) 'hsCode': _hsCodeCtrl.text.trim(),
      'declaredValue': num.tryParse(_valueCtrl.text.trim()) ?? 0,
      'declaredCurrency': _currencyCtrl.text.trim().toUpperCase(),
      if (_weightCtrl.text.trim().isNotEmpty)
        'weightKg': num.tryParse(_weightCtrl.text.trim()),
      'quantity': int.tryParse(_quantityCtrl.text.trim()) ?? 1,
      'purpose': _purpose,
      'isDangerous': _isDangerous,
    };
    final r = await ref.read(customsControllerProvider.notifier).save(
          widget.parcelId,
          body,
          existing: _existing,
        );
    if (!mounted) return;
    if (r == null) {
      final err = ref.read(customsControllerProvider).error ?? 'Erreur';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      setState(() => _existing = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Déclaration enregistrée')),
      );
    }
  }

  Future<void> _sign() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Signer la déclaration ?'),
        content: const Text(
          'Après signature, aucune modification ne sera possible. Vous pourrez ensuite consulter les devis des carriers internationaux.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Signer')),
        ],
      ),
    );
    if (confirm != true) return;
    final r = await ref.read(customsControllerProvider.notifier).sign(widget.parcelId);
    if (!mounted) return;
    if (r == null) {
      final err = ref.read(customsControllerProvider).error ?? 'Erreur';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Déclaration signée')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(parcelCustomsProvider(widget.parcelId));
    final mutation = ref.watch(customsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Déclaration douanière'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(parcelCustomsProvider(widget.parcelId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          // 404 = pas encore de déclaration → afficher le form vide.
          // On considère tout autre code comme erreur. L'API renvoie
          // néanmoins null pour 404 géré, donc cette branche est rare.
          return _buildForm(signed: false, mutation: mutation);
        },
        data: (c) {
          if (c != null && !_initialized) {
            _initialized = true;
            _prefill(c);
          }
          return _buildForm(signed: c?.isSigned ?? false, customs: c, mutation: mutation);
        },
      ),
    );
  }

  Widget _buildForm({
    required bool signed,
    ParcelCustoms? customs,
    required CustomsMutationState mutation,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (signed)
              Card(
                color: AppTheme.green50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: AppTheme.successColor),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Déclaration signée et verrouillée.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _originCtrl,
                    enabled: !signed,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Origine (ISO-2)',
                      helperText: 'ex. SN',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => RegExp(r'^[A-Za-z]{2}$').hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Code 2 lettres',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _destCtrl,
                    enabled: !signed,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Destination (ISO-2)',
                      helperText: 'ex. FR',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => RegExp(r'^[A-Za-z]{2}$').hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Code 2 lettres',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              enabled: !signed,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Contenu détaillé',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim().length ?? 0) < 2 ? 'Minimum 2 caractères' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _valueCtrl,
                    enabled: !signed,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valeur déclarée',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (num.tryParse(v?.trim() ?? '') ?? -1) >= 0
                        ? null
                        : 'Valeur ≥ 0 requise',
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _currencyCtrl,
                    enabled: !signed,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Devise',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    enabled: !signed,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Poids (kg)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _quantityCtrl,
                    enabled: !signed,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantité',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hsCodeCtrl,
              enabled: !signed,
              decoration: const InputDecoration(
                labelText: 'Code HS (optionnel)',
                helperText: '4 à 10 chiffres',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return null;
                return RegExp(r'^\d{4,10}$').hasMatch(s) ? null : 'Format invalide';
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _purpose,
              items: _purposes
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: signed ? null : (v) => setState(() => _purpose = v ?? 'personal'),
              decoration: const InputDecoration(
                labelText: 'Usage',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isDangerous,
              onChanged: signed ? null : (v) => setState(() => _isDangerous = v),
              title: const Text('Produit dangereux'),
            ),
            const SizedBox(height: 16),
            if (!signed)
              FilledButton.icon(
                onPressed: mutation.busy ? null : _submit,
                icon: mutation.busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_existing ? 'Mettre à jour' : 'Enregistrer'),
              ),
            if (_existing && !signed) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: mutation.busy ? null : _sign,
                icon: const Icon(Icons.verified_user),
                label: const Text('Signer la déclaration'),
              ),
            ],
            if (signed) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () =>
                    context.push('/parcels/${widget.parcelId}/international-offers'),
                icon: const Icon(Icons.local_shipping),
                label: const Text('Voir les devis carriers'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
