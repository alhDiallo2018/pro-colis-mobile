// lib/widgets/declare_cash_payment_sheet.dart
//
// Déclaration d'encaissement en espèces par le chauffeur.
//
// Sur une course réglée en espèces, la plateforme n'encaisse rien : le chauffeur
// reçoit l'argent en main propre (de l'expéditeur au ramassage, ou du
// destinataire à la livraison). Il doit donc le signaler ici pour que la course
// soit réconciliée. La déclaration crée un paiement `cash` en `processing` —
// « encaissement déclaré » — qu'un admin valide ensuite.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:procolis/theme/fonts.dart';

import '../models/parcel.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

/// Ouvre la feuille de déclaration. Renvoie `true` si l'encaissement a été
/// déclaré, afin que l'appelant rafraîchisse le colis (et enchaîne, le cas
/// échéant, sur le règlement de la commission).
Future<bool?> showDeclareCashPaymentSheet(
  BuildContext context, {
  required Parcel parcel,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DeclareCashPaymentSheet(parcel: parcel),
  );
}

class DeclareCashPaymentSheet extends StatefulWidget {
  final Parcel parcel;

  const DeclareCashPaymentSheet({super.key, required this.parcel});

  @override
  State<DeclareCashPaymentSheet> createState() =>
      _DeclareCashPaymentSheetState();
}

class _DeclareCashPaymentSheetState extends State<DeclareCashPaymentSheet> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();

  XFile? _proof;
  bool _submitting = false;
  String? _error;

  /// Montant attendu au titre de la course.
  double get _expected => widget.parcel.payableAmount;

  CashCollectionPoint get _point => widget.parcel.resolvedCashCollectionPoint;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _expected > 0 ? _expected.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _declaredAmount =>
      double.tryParse(_amountController.text.trim().replaceAll(' ', '')) ?? 0;

  /// Un écart avec le montant convenu n'interdit pas la déclaration (l'argent a
  /// pu être remis partiellement) mais doit être signalé au chauffeur.
  bool get _hasGap =>
      _expected > 0 && _declaredAmount > 0 && _declaredAmount != _expected;

  bool get _canSubmit => _declaredAmount > 0 && !_submitting;

  Future<void> _pickProof(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 80);
      if (file == null || !mounted) return;
      setState(() => _proof = file);
    } catch (error) {
      debugPrint('Erreur sélection preuve encaissement: $error');
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      // La preuve est facultative : si le téléversement échoue, on déclare
      // quand même l'encaissement plutôt que de bloquer le chauffeur.
      String? proofUrl;
      if (_proof != null) {
        proofUrl = await _api.uploadFile(
          file: _proof!,
          mediaType: 'photo',
          parcelId: widget.parcel.id,
        );
      }

      final note = _noteController.text.trim();
      final result = await _api.declareCashCollection(
        widget.parcel.id,
        amount: _declaredAmount,
        collectionPoint: _point.value,
        note: note.isEmpty ? null : note,
        proofUrl: proofUrl,
      );

      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _error = result['message']?.toString() ??
            'Déclaration impossible. Réessayez.';
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur lors de la déclaration : $error';
        _submitting = false;
      });
    }
  }

  String _fcfa(double value) {
    final digits = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return '$buffer FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.slate300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _header(),
                const SizedBox(height: 16),
                _contextCard(),
                const SizedBox(height: 16),
                _amountField(),
                if (_hasGap) ...[
                  const SizedBox(height: 8),
                  _gapWarning(),
                ],
                const SizedBox(height: 16),
                _noteField(),
                const SizedBox(height: 16),
                _proofPicker(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _errorBox(_error!),
                ],
                const SizedBox(height: 18),
                PcButton(
                  'Confirmer l’encaissement',
                  icon: Icons.verified_rounded,
                  size: PcButtonSize.lg,
                  block: true,
                  loading: _submitting,
                  onPressed: _canSubmit ? _submit : null,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Un administrateur validera cet encaissement.',
                    style: AppFonts.manrope(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.amber50,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: const Icon(Icons.payments_rounded,
              color: AppTheme.amber600, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Encaissement en espèces',
                style: AppFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                widget.parcel.trackingNumber,
                style: AppTheme.mono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed:
              _submitting ? null : () => Navigator.pop(context, false),
          icon: const Icon(Icons.close_rounded, color: AppTheme.slate500),
        ),
      ],
    );
  }

  Widget _contextCard() {
    return PcCard(
      color: AppTheme.amber50,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_point.icon, size: 17, color: AppTheme.amber700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _point.label,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.amber700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _point.isAtPickup
                ? 'Confirmez le montant reçu de ${_payerName()} en récupérant le colis.'
                : 'Confirmez le montant reçu de ${_payerName()} à la remise du colis.',
            style: AppFonts.manrope(
              fontSize: 12.5,
              height: 1.4,
              color: AppTheme.amber700,
            ),
          ),
          if (_expected > 0) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: AppTheme.amber200),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Montant convenu',
                  style: AppFonts.manrope(
                    fontSize: 12.5,
                    color: AppTheme.amber700,
                  ),
                ),
                Text(
                  _fcfa(_expected),
                  style: AppTheme.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.amber700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Qui remet l'argent, nommément quand on le connaît.
  String _payerName() {
    if (_point.isAtPickup) {
      final name = widget.parcel.senderName.trim();
      return name.isEmpty ? 'l’expéditeur' : name;
    }
    final name = widget.parcel.receiverName.trim();
    return name.isEmpty ? 'du destinataire' : name;
  }

  Widget _amountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Montant encaissé (FCFA)',
          style: AppFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: AppTheme.mono(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.teal700,
          ),
          decoration: _decoration(
            _expected > 0 ? _expected.toStringAsFixed(0) : 'Ex : 12000',
            Icons.payments_rounded,
          ),
        ),
      ],
    );
  }

  Widget _gapWarning() {
    final diff = _declaredAmount - _expected;
    final short = diff < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.amber50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 17, color: AppTheme.amber600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              short
                  ? 'Il manque ${_fcfa(diff.abs())} par rapport au montant convenu. '
                      'Précisez pourquoi dans la note.'
                  : 'Vous déclarez ${_fcfa(diff)} de plus que le montant convenu. '
                      'Précisez pourquoi dans la note.',
              style: AppFonts.manrope(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppTheme.amber700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note (optionnel)',
          style: AppFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _noteController,
          maxLines: 3,
          maxLength: 200,
          style: AppFonts.manrope(fontSize: 14),
          decoration: _decoration(
            'Ex : payé en billets, remis au garage d’arrivée.',
            null,
          ),
        ),
      ],
    );
  }

  Widget _proofPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preuve (optionnel)',
          style: AppFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (_proof != null)
              Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 10),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: kIsWeb
                    ? Image.network(_proof!.path, fit: BoxFit.cover)
                    : Image.file(File(_proof!.path), fit: BoxFit.cover),
              ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: PcButton(
                      _proof == null ? 'Photo' : 'Remplacer',
                      icon: Icons.photo_camera_rounded,
                      variant: PcButtonVariant.secondary,
                      block: true,
                      onPressed: _submitting
                          ? null
                          : () => _pickProof(ImageSource.camera),
                    ),
                  ),
                  if (_proof != null) ...[
                    const SizedBox(width: 8),
                    PcIconButton(
                      Icons.delete_outline_rounded,
                      variant: PcIconButtonVariant.danger,
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _proof = null),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.red50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_rounded, size: 17, color: AppTheme.red400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.red500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppFonts.manrope(fontSize: 14, color: AppTheme.slate400),
      prefixIcon:
          icon != null ? Icon(icon, size: 20, color: AppTheme.slate400) : null,
      filled: true,
      fillColor: AppTheme.cardColor,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.slate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
    );
  }
}
