import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../models/parcel.dart';
import '../../providers/parcel_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

class OfferDialog extends ConsumerStatefulWidget {
  final Parcel parcel;
  final VoidCallback onClose;
  final VoidCallback? onSuccess;

  const OfferDialog({
    super.key,
    required this.parcel,
    required this.onClose,
    this.onSuccess,
  });

  @override
  ConsumerState<OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends ConsumerState<OfferDialog> {
  final _priceCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final priceText = _priceCtrl.text.trim();
    if (priceText.isEmpty) {
      setState(() => _error = 'Veuillez saisir un prix.');
      return;
    }
    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      setState(() => _error = 'Prix invalide.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final notifier = ref.read(parcelProvider.notifier);
      await notifier.createBid({
        'parcelId': widget.parcel.id,
        'price': price,
        if (_messageCtrl.text.trim().isNotEmpty) 'message': _messageCtrl.text.trim(),
      });
      widget.onSuccess?.call();
      widget.onClose();
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.teal50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.gavel, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Faire une offre',
                    style: AppFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                ),
                IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Colis ${parcel.trackingNumber} · ${parcel.departureGarageName} → ${parcel.arrivalGarageName ?? '—'}',
              style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary),
            ),
            if (parcel.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(parcel.description, style: AppFonts.manrope(fontSize: 12, color: AppTheme.slate400, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prix proposé (FCFA)',
                hintText: 'Ex: 5000',
                prefixIcon: Icon(Icons.payments),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _messageCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message (optionnel)',
                hintText: 'Bonjour, je suis disponible pour...',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.slate400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Votre offre sera visible par le client. Vous pourrez négocier après acceptation.',
                      style: AppFonts.manrope(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppFonts.manrope(fontSize: 13, color: AppTheme.red500)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: PcButton('Annuler', variant: PcButtonVariant.secondary, onPressed: widget.onClose)),
                const SizedBox(width: 12),
                Expanded(
                  child: PcButton(
                    'Envoyer l\'offre',
                    icon: Icons.send,
                    variant: PcButtonVariant.primary,
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
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
