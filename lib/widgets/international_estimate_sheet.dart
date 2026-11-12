// lib/widgets/international_estimate_sheet.dart
//
// Simulateur d'envoi international (CEDEAO + Mauritanie). Pré-devis avant
// création : le client saisit pays d'origine, destination, poids et devise
// d'affichage, le serveur retourne prix XOF + prix converti + supplément
// douane + SLA + documents requis.
//
// Les listes de pays et devises sont alignées sur `international-pricing.js`
// : toute évolution serveur doit être répercutée ici.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:procolis/theme/fonts.dart';

import '../services/api/client.dart';
import '../services/api/international_carriers_api.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

class _Country {
  final String code;
  final String label;
  const _Country(this.code, this.label);
}

// Pays effectivement présents dans `countryPairs` du serveur. Ajouter un
// couple côté serveur ⇒ ajouter le pays ici.
const _supportedCountries = <_Country>[
  _Country('SN', 'Sénégal'),
  _Country('ML', 'Mali'),
  _Country('GN', 'Guinée'),
  _Country('MR', 'Mauritanie'),
  _Country('GM', 'Gambie'),
  _Country('CI', 'Côte d\'Ivoire'),
  _Country('BF', 'Burkina Faso'),
];

const _supportedCurrencies = <String>[
  'XOF',
  'GHS',
  'NGN',
  'MRU',
  'GMD',
  'EUR',
  'USD'
];

class InternationalEstimateSheet extends StatefulWidget {
  const InternationalEstimateSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InternationalEstimateSheet(),
    );
  }

  @override
  State<InternationalEstimateSheet> createState() =>
      _InternationalEstimateSheetState();
}

class _InternationalEstimateSheetState
    extends State<InternationalEstimateSheet> {
  late final InternationalCarriersApi _api =
      InternationalCarriersApi(ApiClient());
  final TextEditingController _weightCtrl = TextEditingController();

  String _origin = 'SN';
  String _destination = 'ML';
  String _currency = 'XOF';
  bool _declareValue = false;

  bool _loading = false;
  InternationalEstimate? _estimate;
  String? _error;

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  double get _weight =>
      double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _fetch() async {
    final w = _weight;
    if (w <= 0) {
      setState(() {
        _estimate = null;
        _error = 'Saisissez un poids valide (en kg).';
      });
      return;
    }
    if (_origin == _destination) {
      setState(() {
        _estimate = null;
        _error = 'Choisissez deux pays différents pour un envoi international.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.estimate(
      originCountry: _origin,
      destinationCountry: _destination,
      weightKg: w,
      displayCurrency: _currency,
      declareValue: _declareValue,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _estimate = result;
      if (!result.ok) {
        _error = _reasonLabel(result);
      }
    });
  }

  String _reasonLabel(InternationalEstimate q) {
    switch (q.reason) {
      case 'disabled':
        return 'Les devis internationaux sont momentanément désactivés.';
      case 'invalid_country':
        return 'Pays invalide.';
      case 'invalid_weight':
        return 'Poids invalide.';
      case 'overweight':
        return 'Poids maximum dépassé (${q.maxWeightKg ?? '?'} kg).';
      case 'country_pair_not_served':
        return 'Ce couple de pays n\'est pas encore desservi.';
      case 'network':
        return 'Devis indisponible : vérifiez votre connexion.';
      default:
        return q.reason == null
            ? 'Devis indisponible.'
            : 'Devis refusé (${q.reason}).';
    }
  }

  String _formatNumber(num v) {
    final s = v.toInt().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  String _docLabel(String code) {
    switch (code) {
      case 'invoice':
        return 'Facture commerciale';
      case 'cn22_or_cn23':
        return 'Déclaration douanière CN22/CN23';
      case 'sender_id':
        return 'Pièce d\'identité expéditeur';
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: SingleChildScrollView(
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
                'Simuler un envoi international',
                style: AppFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Zone CEDEAO + Mauritanie. Les tarifs sont indicatifs et '
                'servent à préparer votre envoi.',
                style: AppFonts.manrope(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _dropdown<String>(
                      label: 'Origine',
                      value: _origin,
                      items: _supportedCountries
                          .map((c) => DropdownMenuItem(
                              value: c.code, child: Text(c.label)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _origin = v ?? _origin;
                        _estimate = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dropdown<String>(
                      label: 'Destination',
                      value: _destination,
                      items: _supportedCountries
                          .map((c) => DropdownMenuItem(
                              value: c.code, child: Text(c.label)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _destination = v ?? _destination;
                        _estimate = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Poids (kg)',
                        hintText: 'ex. 3,5',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) {
                        if (_estimate != null) {
                          setState(() => _estimate = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 120,
                    child: _dropdown<String>(
                      label: 'Devise',
                      value: _currency,
                      items: _supportedCurrencies
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _currency = v ?? _currency;
                        _estimate = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _declareValue,
                onChanged: (v) => setState(() {
                  _declareValue = v ?? false;
                  _estimate = null;
                }),
                title: Text(
                  'Déclaration de valeur (CN22/CN23 requis)',
                  style: AppFonts.manrope(fontSize: 13),
                ),
              ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.red50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: AppFonts.manrope(
                      fontSize: 12.5,
                      color: AppTheme.red500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_estimate != null && _estimate!.ok) _buildQuoteCard(),
              PcButton(
                'Obtenir le devis',
                onPressed: _loading ? null : _fetch,
                loading: _loading,
                icon: Icons.calculate_rounded,
                size: PcButtonSize.lg,
                block: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildQuoteCard() {
    final q = _estimate!;
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
              Icon(Icons.flight_takeoff_rounded,
                  color: AppTheme.teal600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Devis indicatif',
                style: AppFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.teal600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _row(
            'Prix estimé',
            '${_formatNumber(q.priceDisplay)} ${q.displayCurrency}',
            highlight: true,
          ),
          if (q.displayCurrency != 'XOF')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '(${_formatNumber(q.priceXof)} FCFA)',
                style: AppFonts.manrope(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 4),
          if (q.customsSurchargeXof > 0)
            _row('Dont douane',
                '${_formatNumber(q.customsSurchargeXof)} FCFA'),
          _row('Délai estimé',
              '${q.slaDays} jour${q.slaDays > 1 ? 's' : ''}'),
          if (q.requiredDocuments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Documents requis',
              style: AppFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            ...q.requiredDocuments.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _docLabel(d),
                          style: AppFonts.manrope(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )),
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
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: AppFonts.plusJakartaSans(
                fontSize: highlight ? 15 : 13,
                fontWeight: FontWeight.w800,
                color: highlight ? AppTheme.teal600 : AppTheme.textPrimary,
              )),
        ),
      ],
    );
  }
}
