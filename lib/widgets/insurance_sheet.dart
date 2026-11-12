// lib/widgets/insurance_sheet.dart
//
// Feuille de souscription d'assurance colis. Enchaîne la saisie de la valeur
// déclarée → devis serveur → souscription idempotente.
//
// Le serveur recalcule la prime à chaque appel : la valeur affichée au
// moment du "Confirmer" est donc toujours la valeur réellement débitée.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:procolis/theme/fonts.dart';

import '../models/parcel.dart';
import '../services/api/insurance_api.dart';
import '../services/api/client.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

class InsuranceSheet extends StatefulWidget {
  final Parcel parcel;

  const InsuranceSheet({super.key, required this.parcel});

  static Future<InsuranceSubscription?> show(
    BuildContext context, {
    required Parcel parcel,
  }) {
    return showModalBottomSheet<InsuranceSubscription?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InsuranceSheet(parcel: parcel),
    );
  }

  @override
  State<InsuranceSheet> createState() => _InsuranceSheetState();
}

class _InsuranceSheetState extends State<InsuranceSheet> {
  late final InsuranceApi _api = InsuranceApi(ApiClient());
  final TextEditingController _valueCtrl = TextEditingController();

  bool _crossBorder = false;
  bool _loadingQuote = false;
  bool _subscribing = false;
  InsuranceQuote? _quote;
  String? _lastError;

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  int get _declaredValue =>
      int.tryParse(_valueCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _fetchQuote() async {
    final value = _declaredValue;
    if (value <= 0) {
      setState(() {
        _quote = null;
        _lastError = 'Saisissez une valeur déclarée (XOF).';
      });
      return;
    }
    setState(() {
      _loadingQuote = true;
      _lastError = null;
    });
    final quote = await _api.quote(
      declaredValueXof: value,
      parcelType: widget.parcel.type.value,
      crossBorder: _crossBorder,
    );
    if (!mounted) return;
    setState(() {
      _loadingQuote = false;
      _quote = quote;
      if (!quote.ok) {
        _lastError = _reasonLabel(quote.reason);
      }
    });
  }

  Future<void> _subscribe() async {
    final quote = _quote;
    if (quote == null || !quote.ok || _subscribing) return;
    setState(() => _subscribing = true);
    final result = await _api.subscribe(
      parcelId: widget.parcel.id,
      declaredValueXof: _declaredValue,
      parcelType: widget.parcel.type.value,
      crossBorder: _crossBorder,
    );
    if (!mounted) return;
    setState(() => _subscribing = false);
    if (!result.ok) {
      setState(() => _lastError = _reasonLabel(result.reason));
      return;
    }
    Navigator.of(context).pop(result.subscription);
  }

  String _reasonLabel(String? reason) {
    switch (reason) {
      case 'disabled':
        return 'L\'assurance est momentanément désactivée.';
      case 'invalid_value':
        return 'Valeur déclarée invalide.';
      case 'type_not_insurable':
        return 'Ce type de colis (${widget.parcel.type.label}) n\'est pas assurable.';
      case 'unknown_parcel_type':
      case 'invalid_type':
        return 'Type de colis non reconnu.';
      case 'already_subscribed':
      case 'duplicate':
        return 'Ce colis est déjà couvert par une assurance.';
      case 'network':
        return 'Devis indisponible : vérifiez votre connexion.';
      default:
        return reason == null
            ? 'Impossible de récupérer le devis.'
            : 'Souscription refusée ($reason).';
    }
  }

  String _fcfa(num v) {
    final s = v.toInt().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return '$b FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Protéger ce colis',
              style: AppFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Déclarez la valeur du contenu pour obtenir un devis d\'assurance '
              'instantané.',
              style: AppFonts.manrope(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _valueCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Valeur déclarée (FCFA)',
                hintText: 'ex. 150 000',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) {
                if (_quote != null) {
                  setState(() {
                    _quote = null;
                    _lastError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _crossBorder,
                  onChanged: (v) {
                    setState(() {
                      _crossBorder = v ?? false;
                      _quote = null;
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    'Envoi transfrontalier (+15% de prime)',
                    style: AppFonts.manrope(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_lastError != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.red50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _lastError!,
                  style: AppFonts.manrope(
                    fontSize: 12.5,
                    color: AppTheme.red500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (quote != null && quote.ok) _buildQuoteCard(quote),
            PcButton(
              quote == null || !quote.ok ? 'Obtenir le devis' : 'Confirmer',
              onPressed: _loadingQuote || _subscribing
                  ? null
                  : (quote == null || !quote.ok ? _fetchQuote : _subscribe),
              loading: _loadingQuote || _subscribing,
              icon: quote == null || !quote.ok
                  ? Icons.calculate_rounded
                  : Icons.verified_rounded,
              size: PcButtonSize.lg,
              block: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard(InsuranceQuote quote) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.teal50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.teal500.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  color: AppTheme.teal600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Devis instantané',
                style: AppFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.teal600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _row('Prime à payer', _fcfa(quote.premiumXof), highlight: true),
          const SizedBox(height: 4),
          _row('Plafond d\'indemnisation', _fcfa(quote.coverageXof)),
          if (quote.exclusions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Exclusions standard : ${quote.exclusions.join(', ')}',
              style: AppFonts.manrope(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppFonts.manrope(
                fontSize: 13, color: AppTheme.slate600)),
        Text(value,
            style: AppFonts.plusJakartaSans(
              fontSize: highlight ? 15 : 13,
              fontWeight: FontWeight.w800,
              color: highlight ? AppTheme.teal600 : AppTheme.textPrimary,
            )),
      ],
    );
  }
}
