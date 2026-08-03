// lib/screens/parcel/edit_colis_sheet.dart
//
// Modification d'un colis déjà créé, par son expéditeur.
//
// Volontairement séparé de `create_colis_sheet.dart` : la feuille de création
// porte un assistant en trois étapes, un brouillon, des pièces jointes et le
// choix du mode de livraison. Or l'API n'autorise à la modification qu'un
// sous-ensemble de champs — ni le statut, ni le chauffeur, ni le régime
// d'enchères — et refuse toute modification dès qu'un chauffeur s'est engagé.
// Un formulaire à plat calqué sur cette liste blanche est plus lisible qu'un
// assistant dont la moitié des écrans serait désactivée.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/payment.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/payment_channel_selector.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/route_picker.dart';

/// Ouvre le formulaire de modification. Renvoie le colis à jour si l'API a
/// accepté la modification, `null` sinon — l'écran appelant peut ainsi
/// rafraîchir son affichage sans relire le détail.
Future<Parcel?> showEditColisSheet(BuildContext context, Parcel parcel) {
  return showModalBottomSheet<Parcel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditColisSheet(parcel: parcel),
  );
}

/// Vrai si le colis est encore dans un état où l'API accepte une modification.
/// Reproduit les gardes du contrôleur pour ne pas proposer une action qui
/// serait refusée ; c'est l'API qui tranche en dernier ressort.
bool canEditParcel(Parcel parcel) {
  if (parcel.hasDriver) return false;
  if (parcel.negotiatedPrice != null) return false;
  if (parcel.bids.any((bid) => bid.isAccepted)) return false;
  return parcel.isPending || parcel.isFree;
}

class _EditColisSheet extends ConsumerStatefulWidget {
  final Parcel parcel;

  const _EditColisSheet({required this.parcel});

  @override
  ConsumerState<_EditColisSheet> createState() => _EditColisSheetState();
}

class _EditColisSheetState extends ConsumerState<_EditColisSheet> {
  final ApiService _api = ApiService();

  bool _loadingZones = true;
  bool _submitting = false;
  String? _error;

  List<Garage> _zones = [];
  String? _departureZoneId;
  String? _arrivalZoneId;

  late final TextEditingController _receiverName;
  late final TextEditingController _receiverPhone;
  late final TextEditingController _receiverEmail;
  late final TextEditingController _receiverAddress;
  late final TextEditingController _description;
  late final TextEditingController _weight;
  late final TextEditingController _price;

  late ParcelType _type;
  late bool _insurance;
  late bool _urgent;
  late PaymentChannel _paymentChannel;
  late CashCollectionPoint _cashCollectionPoint;

  /// Valeurs de départ, pour n'envoyer que le delta. L'API traite un champ
  /// absent comme inchangé et refuse une charge utile vide.
  late final Map<String, String> _initial;

  @override
  void initState() {
    super.initState();
    final parcel = widget.parcel;

    _receiverName = TextEditingController(text: parcel.receiverName);
    _receiverPhone = TextEditingController(text: parcel.receiverPhone);
    _receiverEmail = TextEditingController(text: parcel.receiverEmail ?? '');
    _receiverAddress =
        TextEditingController(text: parcel.receiverAddress ?? '');
    _description = TextEditingController(text: parcel.description);
    _weight = TextEditingController(text: _numberText(parcel.weight));
    _price = TextEditingController(
        text: _numberText(parcel.proposedPrice ?? parcel.price));

    _type = parcel.type;
    _insurance = parcel.isInsured;
    _urgent = parcel.isUrgent;
    _paymentChannel = parcel.resolvedPaymentChannel;
    _cashCollectionPoint =
        parcel.cashCollectionPoint ?? CashCollectionPoint.receiverDelivery;
    _departureZoneId = parcel.departureZoneId;
    _arrivalZoneId = parcel.arrivalZoneId;

    _initial = _snapshot();
    _loadZones();
  }

  @override
  void dispose() {
    _receiverName.dispose();
    _receiverPhone.dispose();
    _receiverEmail.dispose();
    _receiverAddress.dispose();
    _description.dispose();
    _weight.dispose();
    _price.dispose();
    super.dispose();
  }

  /// Affiche un décimal sans zéros superflus, pour que le champ reste
  /// confortable au clavier numérique.
  static String _numberText(num? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }

  /// Photographie comparable de la saisie. Tout est ramené en texte : c'est
  /// suffisant pour détecter un changement et évite d'écrire un comparateur par
  /// type de champ.
  Map<String, String> _snapshot() => {
        'receiverName': _receiverName.text.trim(),
        'receiverPhone': _receiverPhone.text.trim(),
        'receiverEmail': _receiverEmail.text.trim(),
        'receiverAddress': _receiverAddress.text.trim(),
        'description': _description.text.trim(),
        'weight': _weight.text.trim(),
        'price': _price.text.trim(),
        'type': _type.value,
        'isInsured': _insurance.toString(),
        'isUrgent': _urgent.toString(),
        'paymentChannel': _paymentChannel.value,
        'cashCollectionPoint': _cashCollectionPoint.value,
        'departureZoneId': _departureZoneId ?? '',
        'arrivalZoneId': _arrivalZoneId ?? '',
      };

  Set<String> get _changedKeys {
    final current = _snapshot();
    return current.keys.where((key) => current[key] != _initial[key]).toSet();
  }

  bool get _hasChanges => _changedKeys.isNotEmpty;

  Future<void> _loadZones() async {
    try {
      final zones = await _api.getAllZones();
      if (mounted) {
        setState(() {
          _zones = zones;
          _loadingZones = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingZones = false);
    }
  }

  Garage? _zoneById(String? id) {
    if (id == null) return null;
    for (final zone in _zones) {
      if (zone.id == id) return zone;
    }
    return null;
  }

  String? _validate() {
    if (_receiverName.text.trim().isEmpty) {
      return 'Le nom du destinataire est requis.';
    }
    if (_receiverPhone.text.trim().isEmpty) {
      return 'Le téléphone du destinataire est requis.';
    }
    if (_description.text.trim().isEmpty) {
      return 'La description du colis est requise.';
    }
    final weight = double.tryParse(_weight.text.trim());
    if (weight == null || weight <= 0) {
      return 'Indiquez un poids supérieur à zéro.';
    }
    if (_departureZoneId == null) {
      return 'La zone de départ est requise.';
    }
    if (_departureZoneId != null && _departureZoneId == _arrivalZoneId) {
      return 'Le départ et l’arrivée doivent être différents.';
    }
    return null;
  }

  /// Ne transmet que les champs touchés. Les couples liés partent ensemble :
  /// changer une zone sans son libellé de ville laisserait un trajet incohérent,
  /// et changer le prix sans `proposedPrice` laisserait le montant total figé sur
  /// l'ancienne valeur.
  Map<String, dynamic> _payload() {
    final changed = _changedKeys;
    final data = <String, dynamic>{};

    String? orNull(String value) => value.isEmpty ? null : value;

    if (changed.contains('receiverName')) {
      data['receiverName'] = _receiverName.text.trim();
    }
    if (changed.contains('receiverPhone')) {
      data['receiverPhone'] = _receiverPhone.text.trim();
    }
    if (changed.contains('receiverEmail')) {
      data['receiverEmail'] = orNull(_receiverEmail.text.trim());
    }
    if (changed.contains('receiverAddress')) {
      data['receiverAddress'] = orNull(_receiverAddress.text.trim());
    }
    if (changed.contains('description')) {
      data['description'] = _description.text.trim();
    }
    if (changed.contains('weight')) {
      data['weight'] = double.tryParse(_weight.text.trim());
    }
    if (changed.contains('type')) data['type'] = _type.value;
    if (changed.contains('isInsured')) data['isInsured'] = _insurance;
    if (changed.contains('isUrgent')) data['isUrgent'] = _urgent;

    if (changed.contains('price')) {
      final price = double.tryParse(_price.text.trim());
      data['price'] = price;
      data['proposedPrice'] = price;
    }

    if (changed.contains('paymentChannel')) {
      data['paymentChannel'] = _paymentChannel.value;
      data['paymentMethod'] = _paymentChannel.defaultMethod.value;
    }
    // Le point de remise n'a de sens qu'en espèces ; on l'efface en repassant
    // sur un règlement en ligne pour ne pas laisser une consigne orpheline.
    if (changed.contains('cashCollectionPoint') ||
        changed.contains('paymentChannel')) {
      data['cashCollectionPoint'] =
          _paymentChannel.isCash ? _cashCollectionPoint.value : null;
    }

    if (changed.contains('departureZoneId')) {
      data['departureZoneId'] = _departureZoneId;
    }
    if (changed.contains('arrivalZoneId')) {
      data['arrivalZoneId'] = _arrivalZoneId;
    }

    return data;
  }

  Future<void> _handleClose() async {
    if (_submitting) return;
    if (!_hasChanges) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final abandon = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Abandonner les modifications ?'),
        content: const Text('Vos changements ne seront pas enregistrés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuer')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child:
                const Text('Abandonner', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (abandon == true && mounted) Navigator.pop(context);
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(parcelProvider.notifier)
        .updateParcel(widget.parcel.id, _payload());

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] != true) {
      setState(() => _error =
          result['message']?.toString() ?? 'Modification impossible.');
      return;
    }

    // L'API renvoie le colis à jour : on le remonte pour éviter une relecture.
    final updated = result['parcel'];
    Navigator.pop(
      context,
      updated is Map<String, dynamic> ? Parcel.fromJson(updated) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  _handle(),
                  _header(),
                  Expanded(
                    child: _loadingZones
                        ? Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primary))
                        : SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: _form(),
                          ),
                  ),
                  _footer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _handle() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.slate300,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.teal50,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(Icons.edit_rounded, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modifier le colis',
                    style: AppFonts.plusJakartaSans(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                Text(widget.parcel.trackingNumber,
                    style: AppTheme.mono(
                        fontSize: 12.5, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            onPressed: _handleClose,
            icon: Icon(Icons.close_rounded, color: AppTheme.slate500),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rappel du cadre : la modification se ferme dès qu'un chauffeur
        // s'engage, ce que l'utilisateur ne peut pas deviner.
        PcCard(
          color: AppTheme.amber50,
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: AppTheme.amber600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Modifiable tant qu’aucun chauffeur n’a pris le colis en '
                  'charge. Les chauffeurs ayant déjà fait une offre seront '
                  'prévenus du changement.',
                  style: AppFonts.manrope(
                      fontSize: 12.5, color: AppTheme.amber600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        _sectionTitle('Trajet'),
        RoutePicker(
          garages: _zones,
          initialDeparture: _zoneById(_departureZoneId),
          initialArrival: _zoneById(_arrivalZoneId),
          onDepartureChanged: (zone) =>
              setState(() => _departureZoneId = zone?.id),
          onArrivalChanged: (zone) => setState(() => _arrivalZoneId = zone?.id),
          onZoneAdded: (zone) => setState(() {
            _zones = [..._zones.where((z) => z.id != zone.id), zone];
          }),
        ),
        const SizedBox(height: 22),

        _sectionTitle('Destinataire'),
        _fieldLabel('Nom'),
        _textField(_receiverName, 'Nom complet', Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _fieldLabel('Téléphone'),
        _textField(_receiverPhone, '77 000 00 00', Icons.phone_outlined,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        _fieldLabel('E-mail (optionnel)'),
        _textField(_receiverEmail, 'nom@exemple.sn', Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _fieldLabel('Adresse de livraison (optionnel)'),
        _textField(_receiverAddress, 'Quartier, rue, repère',
            Icons.location_on_outlined),
        const SizedBox(height: 22),

        _sectionTitle('Colis'),
        _fieldLabel('Description'),
        TextField(
          controller: _description,
          maxLines: 3,
          maxLength: 200,
          style: AppFonts.manrope(fontSize: 14),
          decoration:
              _inputDecoration('Ex : deux cartons de vêtements.', null),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Poids (kg)'),
                  _textField(_weight, 'Ex : 12', Icons.scale_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Prix proposé (FCFA)'),
                  _textField(_price, 'Ex : 12500', Icons.payments_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _fieldLabel('Nature du contenu'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ParcelType.values.map((type) {
            final selected = type == _type;
            return ChoiceChip(
              label: Text(type.label),
              avatar: Icon(type.icon,
                  size: 16,
                  color: selected ? Colors.white : AppTheme.slate500),
              selected: selected,
              selectedColor: AppTheme.primary,
              labelStyle: AppFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
              onSelected: (_) => setState(() => _type = type),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _insurance,
          activeThumbColor: AppTheme.primary,
          title: Text('Assurer le colis',
              style: AppFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          onChanged: (value) => setState(() => _insurance = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _urgent,
          activeThumbColor: AppTheme.primary,
          title: Text('Envoi urgent',
              style: AppFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          onChanged: (value) => setState(() => _urgent = value),
        ),
        const SizedBox(height: 16),

        _sectionTitle('Règlement'),
        PaymentChannelField(
          value: _paymentChannel,
          onChanged: (channel) => setState(() => _paymentChannel = channel),
        ),
        if (_paymentChannel.isCash) ...[
          const SizedBox(height: 14),
          CashCollectionPointField(
            value: _cashCollectionPoint,
            onChanged: (point) =>
                setState(() => _cashCollectionPoint = point),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.red50,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 18, color: AppTheme.red400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: AppFonts.manrope(
                          fontSize: 13, color: AppTheme.red400)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _footer() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: PcButton(
              'Annuler',
              variant: PcButtonVariant.secondary,
              size: PcButtonSize.lg,
              block: true,
              onPressed: _handleClose,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: PcButton(
              'Enregistrer',
              icon: Icons.check_rounded,
              size: PcButtonSize.lg,
              block: true,
              loading: _submitting,
              // Désactivé tant que rien n'a bougé : l'API refuserait une charge
              // utile vide, autant ne pas la lui envoyer.
              onPressed: _hasChanges ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: AppFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: AppFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate700)),
      );

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppFonts.manrope(fontSize: 14, color: AppTheme.slate400),
      prefixIcon:
          icon != null ? Icon(icon, size: 20, color: AppTheme.slate400) : null,
      filled: true,
      fillColor: AppTheme.cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: BorderSide(color: AppTheme.slate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: BorderSide(color: AppTheme.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      counterText: '',
    );
  }

  Widget _textField(
    TextEditingController controller,
    String hint,
    IconData? icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppFonts.manrope(fontSize: 14),
      decoration: _inputDecoration(hint, icon),
      // Le bouton « Enregistrer » dépend de `_hasChanges` : sans ce rebuild il
      // resterait grisé pendant la frappe.
      onChanged: (_) => setState(() {}),
    );
  }
}
