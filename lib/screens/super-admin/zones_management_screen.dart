import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/zone.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/pc_components.dart';

String _flagOfCountry(String? country) {
  if (country == null) return '🌍';
  const flags = <String, String>{
    'Sénégal': '🇸🇳', 'Mali': '🇲🇱', "Côte d'Ivoire": '🇨🇮',
    'Guinée': '🇬🇳', 'Burkina Faso': '🇧🇫', 'Bénin': '🇧🇯',
    'Togo': '🇹🇬', 'Niger': '🇳🇪', 'Gambie': '🇬🇲',
    'France': '🇫🇷', 'Mauritanie': '🇲🇷',
  };
  return flags[country] ?? '🌍';
}

class ZonesManagementScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const ZonesManagementScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ZonesManagementScreen> createState() => _ZonesManagementScreenState();
}

class _ZonesManagementScreenState extends ConsumerState<ZonesManagementScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Zone> _zones = [];
  String _searchQuery = '';
  String _countryFilter = '';
  String _typeFilter = '';
  String _statusFilter = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _countries {
    final set = <String>{};
    for (final z in _zones) {
      if (z.country != null && z.country!.trim().isNotEmpty) set.add(z.country!);
    }
    final list = set.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  List<Zone> get _filteredZones {
    final q = _searchQuery.trim().toLowerCase();
    return _zones.where((z) {
      if (_countryFilter.isNotEmpty && z.country != _countryFilter) return false;
      if (_typeFilter.isNotEmpty && z.type != _typeFilter) return false;
      if (_statusFilter == 'active' && !z.isActive) return false;
      if (_statusFilter == 'inactive' && z.isActive) return false;
      if (q.isEmpty) return true;
      return z.name.toLowerCase().contains(q) ||
          (z.displayName ?? '').toLowerCase().contains(q) ||
          (z.city ?? '').toLowerCase().contains(q) ||
          (z.country ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<MapEntry<String, List<Zone>>> get _groupedZones {
    final map = <String, List<Zone>>{};
    for (final z in _filteredZones) {
      final key = (z.country?.trim().isNotEmpty ?? false) ? z.country! : 'Autre';
      map.putIfAbsent(key, () => []).add(z);
    }
    final entries = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  Future<void> _loadZones() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _apiService.getAllZones();
      setState(() {
        _zones = data.map((e) => Zone.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _toggleZone(Zone zone) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.updateZone(zone.id, {'isActive': !zone.isActive});
      await _loadZones();
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du changement de statut')),
        );
      }
    }
  }

  Future<void> _deleteZone(Zone zone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la zone'),
        content: Text('Voulez-vous supprimer la zone "${zone.name}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: AppTheme.red500))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _apiService.deleteZone(zone.id);
      await _loadZones();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la suppression')),
        );
      }
    }
  }

  void _showCreateDialog({Zone? zone}) {
    final nameCtrl = TextEditingController(text: zone?.name ?? '');
    final latCtrl = TextEditingController(text: zone != null ? zone.latitude.toString() : '');
    final lngCtrl = TextEditingController(text: zone != null ? zone.longitude.toString() : '');
    final radiusCtrl = TextEditingController(text: zone != null ? zone.radius.toString() : '5000');
    final cityCtrl = TextEditingController(text: zone?.city ?? '');
    final countryCtrl = TextEditingController(text: zone?.country ?? '');
    String type = zone?.type ?? 'CIRCLE';
    bool isActive = zone?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(zone != null ? 'Modifier la zone' : 'Nouvelle zone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(controller: nameCtrl, label: 'Nom'),
                const SizedBox(height: 10),
                CustomTextField(controller: cityCtrl, label: 'Ville'),
                const SizedBox(height: 10),
                CustomTextField(controller: countryCtrl, label: 'Pays'),
                const SizedBox(height: 10),
                CustomTextField(controller: latCtrl, label: 'Latitude', keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                CustomTextField(controller: lngCtrl, label: 'Longitude', keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                CustomTextField(controller: radiusCtrl, label: 'Rayon (m)', keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Type : '),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('Cercle'), selected: type == 'CIRCLE', onSelected: (_) => setDlg(() => type = 'CIRCLE')),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('Polygone'), selected: type == 'POLYGON', onSelected: (_) => setDlg(() => type = 'POLYGON')),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setDlg(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final lat = double.tryParse(latCtrl.text);
                final lng = double.tryParse(lngCtrl.text);
                final r = int.tryParse(radiusCtrl.text);
                if (nameCtrl.text.isEmpty || lat == null || lng == null) return;
                final payload = {
                  'name': nameCtrl.text.trim(),
                  'latitude': lat,
                  'longitude': lng,
                  'radius': r ?? 5000,
                  'type': type,
                  'isActive': isActive,
                  'city': cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : null,
                  'country': countryCtrl.text.trim().isNotEmpty ? countryCtrl.text.trim() : null,
                  'displayName': nameCtrl.text.trim(),
                };
                Navigator.pop(ctx);
                try {
                  if (zone != null) {
                    await _apiService.updateZone(zone.id, payload);
                  } else {
                    await _apiService.createZone(payload);
                  }
                  await _loadZones();
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erreur lors de l\'enregistrement')),
                    );
                  }
                }
              },
              child: Text(zone != null ? 'Enregistrer' : 'Creer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zones geographiques${widget.embedded ? '' : ' · ${_filteredZones.length}'}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Column(
              children: [
                CustomTextField(
                  controller: _searchController,
                  label: 'Rechercher',
                  hint: 'Rechercher une zone...',
                  prefixIcon: Icons.search,
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('Pays', _countryFilter, _countries.map((c) => '${_flagOfCountry(c)} $c').toList(), (v) {
                        setState(() => _countryFilter = v.split(' ').skip(1).join(' '));
                      }),
                      const SizedBox(width: 6),
                      _filterChip('Type', _typeFilter, ['CIRCLE', 'POLYGON'], (v) {
                        setState(() => _typeFilter = v);
                      }),
                      const SizedBox(width: 6),
                      _filterChip('Statut', _statusFilter, ['active', 'inactive'], (v) {
                        setState(() => _statusFilter = v);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Erreur: $_error', style: const TextStyle(color: AppTheme.red500)),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: _loadZones, child: const Text('Reessayer')),
                  ],
                ))
              : _filteredZones.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined, size: 48, color: AppTheme.slate400),
                          const SizedBox(height: 12),
                          Text(_zones.isEmpty ? 'Aucune zone' : 'Aucun resultat',
                              style: const TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadZones,
                      child: ListView.builder(
                        itemCount: _groupedZones.length,
                        itemBuilder: (ctx, gi) {
                          final entry = _groupedZones[gi];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: AppTheme.slate50,
                                child: Row(
                                  children: [
                                    Text(_flagOfCountry(entry.key), style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 8),
                                    Text(entry.key, style: AppTheme.mono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                                    const SizedBox(width: 8),
                                    Text('· ${entry.value.length}', style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.slate400)),
                                  ],
                                ),
                              ),
                              ...entry.value.map((z) => _buildZoneTile(z)),
                            ],
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(),
        child: const Icon(Icons.add_location_alt_rounded),
      ),
      bottomNavigationBar: widget.embedded ? null : const AppBottomNav(),
    );
  }

  Widget _filterChip(String label, String current, List<String> options, ValueChanged<String> onSelected) {
    return PopupMenuButton<String>(
      onSelected: (v) => onSelected(v == '__all__' ? '' : v),
      itemBuilder: (_) => [
        PopupMenuItem(value: '__all__', child: Text('Tous · $label', style: TextStyle(fontWeight: current.isEmpty ? FontWeight.bold : FontWeight.normal))),
        ...options.map((o) => PopupMenuItem(value: o, child: Text(o, style: TextStyle(fontWeight: current == o ? FontWeight.bold : FontWeight.normal)))),
      ],
      child: Chip(
        label: Text('$label${current.isNotEmpty ? ': $current' : ''}', style: const TextStyle(fontSize: 12)),
        backgroundColor: current.isNotEmpty ? AppTheme.teal50 : AppTheme.slate100,
      ),
    );
  }

  Widget _buildZoneTile(Zone z) {
    return ListTile(
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: z.type == 'POLYGON' ? AppTheme.slate50 : AppTheme.teal50,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Icon(z.type == 'POLYGON' ? Icons.draw_rounded : Icons.circle_outlined,
            color: z.type == 'POLYGON' ? AppTheme.slate500 : AppTheme.teal500, size: 22),
      ),
      title: Text(z.displayName ?? z.name, style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w700)),
      subtitle: Text([
        if (z.city != null) z.city,
        if (z.type == 'CIRCLE') 'Rayon ${(z.radius / 1000).toStringAsFixed(1)} km',
        '${z.driversCount} chauffeur(s)',
      ].join(' · '), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PcBadge(
            z.type == 'CIRCLE' ? 'Cercle' : 'Polygone',
            tone: z.type == 'CIRCLE' ? PcTone.primary : PcTone.neutral,
            variant: PcBadgeVariant.soft,
          ),
          const SizedBox(width: 6),
          PcBadge(
            z.isActive ? 'Actif' : 'Inactif',
            tone: z.isActive ? PcTone.green : PcTone.neutral,
            variant: PcBadgeVariant.solid,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _showCreateDialog(zone: z);
              if (v == 'toggle') _toggleZone(z);
              if (v == 'delete') _deleteZone(z);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'toggle', child: Text(z.isActive ? 'Desactiver' : 'Activer')),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: AppTheme.red500))),
            ],
          ),
        ],
      ),
    );
  }
}
