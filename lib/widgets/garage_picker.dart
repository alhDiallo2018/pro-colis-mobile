// mobile/lib/widgets/garage_picker.dart
// Sélecteur de zone recherchable — remplace le DropdownButtonFormField basique.
// Affiche une bottom sheet avec barre de recherche, groupement par ville,
// et retour visuel instantané du choix.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';

import '../models/garage.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

class GaragePickerSheet {
  static Future<Garage?> show({
    required BuildContext context,
    required List<Garage> garages,
    Garage? exclude,
    Garage? initial,
    String title = 'Choisir une zone',
  }) async {
    return showModalBottomSheet<Garage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GaragePickerSheetContent(
        garages: garages,
        exclude: exclude,
        initial: initial,
        title: title,
      ),
    );
  }
}

class _GaragePickerSheetContent extends StatefulWidget {
  final List<Garage> garages;
  final Garage? exclude;
  final Garage? initial;
  final String title;

  const _GaragePickerSheetContent({
    required this.garages,
    this.exclude,
    this.initial,
    required this.title,
  });

  @override
  State<_GaragePickerSheetContent> createState() =>
      _GaragePickerSheetContentState();
}

class _GaragePickerSheetContentState extends State<_GaragePickerSheetContent> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';
  Garage? _selected;
  bool _locating = false;

  List<Garage> get _filtered {
    var list = widget.garages;
    if (widget.exclude != null) {
      list = list.where((g) => g.id != widget.exclude!.id).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((g) =>
              g.city.toLowerCase().contains(q) ||
              g.name.toLowerCase().contains(q) ||
              (g.region).toLowerCase().contains(q))
          .toList();
    }
    list.sort((a, b) => a.city.compareTo(b.city));
    return list;
  }

  Map<String, List<Garage>> get _grouped {
    final map = <String, List<Garage>>{};
    for (final g in _filtered) {
      map.putIfAbsent(g.city, () => []).add(g);
    }
    return map;
  }

  void _confirm() {
    if (_selected != null) Navigator.pop(context, _selected);
  }

  Future<void> _findNearest() async {
    setState(() => _locating = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      Garage? nearest;
      double? nearestDist;

      for (final g in widget.garages) {
        if (widget.exclude != null && g.id == widget.exclude!.id) continue;
        if (g.latitude == null || g.longitude == null) continue;
        final dist = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          g.latitude!, g.longitude!,
        );
        if (nearestDist == null || dist < nearestDist) {
          nearestDist = dist;
          nearest = g;
        }
      }

      if (nearest != null) {
        setState(() => _selected = nearest);
        final controller = _searchCtrl;
        if (controller.text.isEmpty) {
          _confirm();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune zone avec coordonnées trouvée à proximité.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Géolocalisation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cities = _grouped.keys.toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 42, height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.slate300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(widget.title,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 18, fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary)),
                      ),
                      if (_locating)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      if (!_locating)
                        GestureDetector(
                          onTap: _findNearest,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.teal50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.my_location_rounded,
                                size: 18, color: AppTheme.primary),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (_selected != null)
                        PcButton('Valider',
                            icon: Icons.check_rounded,
                            size: PcButtonSize.sm,
                            onPressed: _confirm),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une ville, une zone...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppTheme.slate400),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () => _searchCtrl.clear(),
                              child: const Icon(Icons.close_rounded,
                                  color: AppTheme.slate400),
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.slate50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: PcEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'Aucun résultat',
                            message: 'Aucune zone ne correspond à "$_query".',
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          itemCount: cities.length,
                          itemBuilder: (_, ci) {
                            final city = cities[ci];
                            final list = _grouped[city]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (ci > 0)
                                  const Divider(indent: 8, endIndent: 8),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      14, ci > 0 ? 0 : 6, 14, 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28, height: 28,
                                        decoration: BoxDecoration(
                                          color: AppTheme.teal50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                            Icons.location_city_rounded,
                                            size: 16, color: AppTheme.primary),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(city,
                                          style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textPrimary)),
                                      const SizedBox(width: 8),
                                      PcBadge('${list.length}',
                                          tone: PcTone.primary),
                                    ],
                                  ),
                                ),
                                for (final g in list) _garageTile(g),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _garageTile(Garage g) {
    final isSelected = _selected?.id == g.id;
    return GestureDetector(
      onTap: () => setState(() => _selected = g),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.teal50 : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: isSelected
              ? Border.all(color: AppTheme.primary)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name,
                      style: GoogleFonts.manrope(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    [g.region.isNotEmpty ? g.region : null, g.address]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(' · '),
                    style: GoogleFonts.manrope(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primary, size: 22),
            if (g.driversCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('${g.driversCount} chauff.',
                    style: GoogleFonts.manrope(
                        fontSize: 11, color: AppTheme.slate500)),
              ),
          ],
        ),
      ),
    );
  }
}
