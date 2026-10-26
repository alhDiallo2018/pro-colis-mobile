import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/country_data.dart';
import '../theme/app_theme.dart';

/// Les numéros collés au format international gardent leur indicatif : on
/// n'ajoute celui du sélecteur qu'à une saisie nationale.
String internationalPhone(String value, String dialCode) {
  final trimmed = value.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (trimmed.startsWith('+')) return '+$digits';
  if (trimmed.startsWith('00')) return '+${digits.substring(2)}';
  return '$dialCode$digits';
}

class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField(
      {super.key,
      required this.controller,
      required this.country,
      required this.onCountryChanged,
      this.enabled = true});
  final TextEditingController controller;
  final CountryInfo country;
  final ValueChanged<CountryInfo> onCountryChanged;
  final bool enabled;

  Future<void> _chooseCountry(BuildContext context) async {
    final selection = await showModalBottomSheet<CountryInfo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CountryPicker(),
    );
    if (selection != null) onCountryChanged(selection);
  }

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Indicatif pays : ${country.name}',
            button: true,
            child: OutlinedButton(
              onPressed: enabled ? () => _chooseCountry(context) : null,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 58),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: BorderSide(color: AppTheme.slate200),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(country.flag, style: const TextStyle(fontSize: 20)),
                Text(country.dialCode, style: const TextStyle(fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: TextFormField(
            key: const ValueKey('phone-input'),
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'Numéro de téléphone', hintText: '77 123 45 67'),
            validator: (value) => RegExp(r'^\+[1-9]\d{7,14}$')
                    .hasMatch(internationalPhone(value ?? '', country.dialCode))
                ? null
                : 'Vérifiez le numéro de téléphone',
          )),
        ],
      );
}

class AuthPinField extends StatefulWidget {
  const AuthPinField(
      {super.key,
      required this.controller,
      this.label = 'Code PIN',
      this.enabled = true,
      this.onSubmitted,
      this.confirmation});
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final VoidCallback? onSubmitted;
  final TextEditingController? confirmation;
  @override
  State<AuthPinField> createState() => _AuthPinFieldState();
}

class _AuthPinFieldState extends State<AuthPinField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _obscure,
        keyboardType: TextInputType.number,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.password],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6)
        ],
        textInputAction: widget.onSubmitted == null
            ? TextInputAction.next
            : TextInputAction.done,
        onFieldSubmitted: (_) => widget.onSubmitted?.call(),
        decoration: InputDecoration(
            labelText: widget.label,
            hintText: '6 chiffres',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
                tooltip: _obscure ? 'Afficher le PIN' : 'Masquer le PIN',
                onPressed: widget.enabled
                    ? () => setState(() => _obscure = !_obscure)
                    : null,
                icon: Icon(_obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined))),
        validator: (value) {
          if (!RegExp(r'^\d{6}$').hasMatch(value ?? ''))
            return 'Saisissez les 6 chiffres du PIN';
          if (widget.confirmation != null && value != widget.confirmation!.text)
            return 'Les deux codes PIN sont différents';
          return null;
        },
      );
}

class _CountryPicker extends StatefulWidget {
  const _CountryPicker();
  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final countries = searchCountries(_query);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                    decoration: const InputDecoration(
                        labelText: 'Rechercher un pays',
                        prefixIcon: Icon(Icons.search)),
                    onChanged: (value) => setState(() => _query = value))),
            Expanded(
                child: ListView.builder(
                    itemCount: countries.length,
                    itemBuilder: (context, index) {
                      final country = countries[index];
                      return ListTile(
                          leading: Text(country.flag),
                          title: Text(country.name),
                          trailing: Text(country.dialCode),
                          onTap: () => Navigator.pop(context, country));
                    })),
          ])),
    );
  }
}
