import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/address.dart';
import '../../models/garage.dart';
import '../../providers/addresses_provider.dart';
import '../../services/places_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../widgets/garage_picker.dart';
import '../../widgets/location_autocomplete.dart';
import '../../widgets/pc_components.dart';

class AddressBookCard extends ConsumerStatefulWidget {
  const AddressBookCard({super.key});

  @override
  ConsumerState<AddressBookCard> createState() => _AddressBookCardState();
}

class _AddressBookCardState extends ConsumerState<AddressBookCard> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _labelController.clear();
    _addressController.clear();
    _cityController.clear();
    _regionController.clear();
    _latitude = null;
    _longitude = null;
    setState(() => _editing = false);
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  Future<void> _save(List<Address> current) async {
    final value = _addressController.text.trim();
    if (value.length < 3 || _saving) return;
    setState(() => _saving = true);
    try {
      final address = Address(
        id: '',
        label: _labelController.text,
        address: value,
        city: _cityController.text,
        region: _regionController.text,
        latitude: _latitude,
        longitude: _longitude,
        isDefault: current.isEmpty,
      );
      await ref.read(addressesApiProvider).createAddress(address);
      await refreshAddresses(ref);
      if (mounted) _resetForm();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setDefault(String addressId) async {
    try {
      await ref.read(addressesApiProvider).setDefaultAddress(addressId);
      await refreshAddresses(ref);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette adresse ?'),
        content: Text(address.address),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(addressesApiProvider).deleteAddress(address.id);
      await refreshAddresses(ref);
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addressesProvider);
    final addresses = state.valueOrNull ?? const <Address>[];

    return PcCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Mes adresses',
            subtitle: 'Accélérez la création de vos prochains colis.',
            actionLabel: _editing ? 'Annuler' : 'Ajouter',
            actionIcon: _editing ? Icons.close : Icons.add,
            onAction: () =>
                _editing ? _resetForm() : setState(() => _editing = true),
          ),
          if (_editing) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Libellé',
                hintText: 'Domicile, bureau…',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),
            LocationAutocomplete(
              controller: _addressController,
              label: 'Adresse',
              placeholder: 'Rechercher une adresse…',
              googleApiKey: PlacesService.googleApiKey,
              onCoordinates: (lat, lng) {
                _latitude = lat;
                _longitude = lng;
              },
              onPlaceDetails: (lat, lng, details) {
                _latitude = lat;
                _longitude = lng;
                if (details.city?.isNotEmpty == true) {
                  _cityController.text = details.city!;
                }
                if (details.region?.isNotEmpty == true) {
                  _regionController.text = details.region!;
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'Ville'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _regionController,
                    decoration: const InputDecoration(labelText: 'Région'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PcButton(
              'Enregistrer l’adresse',
              icon: Icons.save_outlined,
              loading: _saving,
              onPressed: () => _save(addresses),
            ),
          ],
          const SizedBox(height: 12),
          state.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Text(
              'Carnet d’adresses indisponible.',
              style: TextStyle(color: AppTheme.slate400),
            ),
            data: (items) => items.isEmpty
                ? Text(
                    'Aucune adresse enregistrée.',
                    style: TextStyle(color: AppTheme.slate500),
                  )
                : Column(
                    children: [
                      for (final address in items)
                        _AddressRow(
                          address: address,
                          onDefault: address.isDefault
                              ? null
                              : () => _setDefault(address.id),
                          onDelete: () => _delete(address),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class FavoriteGaragesCard extends ConsumerWidget {
  const FavoriteGaragesCard({super.key});

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    List<Garage> favorites,
  ) async {
    try {
      final garages = await ref.read(availableZonesProvider.future);
      if (!context.mounted) return;
      final selected = await GaragePickerSheet.show(
        context: context,
        garages: garages,
        title: 'Ajouter un garage favori',
        allowAddZone: false,
      );
      if (selected == null || !context.mounted) return;
      if (favorites.any((garage) => garage.id == selected.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce garage est déjà dans vos favoris.')),
        );
        return;
      }
      await ref.read(addressesApiProvider).addFavoriteZone(selected.id);
      await refreshFavoriteZones(ref);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    String zoneId,
  ) async {
    try {
      await ref.read(addressesApiProvider).removeFavoriteZone(zoneId);
      await refreshFavoriteZones(ref);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoriteZonesProvider);
    final favorites = state.valueOrNull ?? const <Garage>[];

    return PcCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Garages favoris',
            subtitle: 'Retrouvez rapidement vos zones habituelles.',
            actionLabel: 'Ajouter',
            actionIcon: Icons.star_outline,
            onAction: () => _add(context, ref, favorites),
          ),
          const SizedBox(height: 12),
          state.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Text(
              'Garages favoris indisponibles.',
              style: TextStyle(color: AppTheme.slate400),
            ),
            data: (items) => items.isEmpty
                ? Text(
                    'Aucun garage favori.',
                    style: TextStyle(color: AppTheme.slate500),
                  )
                : Column(
                    children: [
                      for (final garage in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.star_rounded,
                            color: AppTheme.amber500,
                          ),
                          title: Text(garage.name),
                          subtitle: Text(
                            [garage.city, garage.region]
                                .where((part) => part.isNotEmpty)
                                .join(' · '),
                          ),
                          trailing: IconButton(
                            tooltip: 'Retirer des favoris',
                            icon: const Icon(Icons.close),
                            onPressed: () => _remove(context, ref, garage.id),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _CardHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppFonts.manrope(
                  fontSize: 12.5,
                  color: AppTheme.slate500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        PcButton(
          actionLabel,
          icon: actionIcon,
          size: PcButtonSize.sm,
          variant: PcButtonVariant.secondary,
          onPressed: onAction,
        ),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  final Address address;
  final VoidCallback? onDefault;
  final VoidCallback onDelete;

  const _AddressRow({
    required this.address,
    required this.onDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        address.isDefault ? Icons.home_rounded : Icons.location_on_outlined,
        color: address.isDefault ? AppTheme.primary : AppTheme.slate400,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              address.label?.trim().isNotEmpty == true
                  ? address.label!
                  : 'Adresse',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (address.isDefault) ...[
            const SizedBox(width: 8),
            const PcBadge('Par défaut', tone: PcTone.green),
          ],
        ],
      ),
      subtitle: Text(
        [address.address, address.city]
            .where((part) => part?.trim().isNotEmpty == true)
            .join(' · '),
      ),
      trailing: Wrap(
        spacing: 0,
        children: [
          if (onDefault != null)
            IconButton(
              tooltip: 'Définir par défaut',
              icon: const Icon(Icons.star_outline),
              onPressed: onDefault,
            ),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
