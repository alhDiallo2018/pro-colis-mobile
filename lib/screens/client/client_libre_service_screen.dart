import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../models/parcel.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/status_badge.dart';

class ClientLibreServiceScreen extends ConsumerStatefulWidget {
  const ClientLibreServiceScreen({super.key});

  @override
  ConsumerState<ClientLibreServiceScreen> createState() => _ClientLibreServiceScreenState();
}

class _ClientLibreServiceScreenState extends ConsumerState<ClientLibreServiceScreen> {
  final ApiService _api = ApiService();
  List<Parcel> _allParcels = [];
  bool _loading = true;
  String? _error;

  String _search = '';
  String _typeFilter = '';
  String _sort = 'recent';

  static const _typeFilters = [
    {'value': '', 'label': 'Tous les types'},
    {'value': 'document', 'label': 'Document'},
    {'value': 'package', 'label': 'Colis standard'},
    {'value': 'fragile', 'label': 'Fragile'},
    {'value': 'perishable', 'label': 'Alimentaire / Périssable'},
    {'value': 'valuable', 'label': 'Objet de valeur'},
  ];

  static const _sorts = [
    {'value': 'recent', 'label': 'Plus récentes'},
    {'value': 'old', 'label': 'Plus anciennes'},
    {'value': 'price_desc', 'label': 'Prix décroissant'},
    {'value': 'price_asc', 'label': 'Prix croissant'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final parcels = await _api.getMyParcels(status: 'free');
      setState(() { _allParcels = parcels; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Parcel> get _filteredParcels {
    final q = _search.trim().toLowerCase();
    var filtered = _allParcels.where((p) {
      if (_typeFilter.isNotEmpty && p.type.value != _typeFilter) return false;
      if (q.isEmpty) return true;
      return [
        p.trackingNumber,
        p.arrivalGarageName,
        p.departureGarageName,
        p.receiverName,
      ].any((v) => v != null && v.toLowerCase().contains(q));
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case 'old':
          return (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now());
        case 'price_desc':
          return ((b.price ?? 0) - (a.price ?? 0)).toInt();
        case 'price_asc':
          return ((a.price ?? 0) - (b.price ?? 0)).toInt();
        default:
          return (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now());
      }
    });

    return filtered;
  }

  String _fcfa(double? v) {
    if (v == null) return '—';
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf FCFA';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredParcels;
    final hasParcels = _allParcels.isNotEmpty;
    final filteredEmpty = hasParcels && filtered.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes annonces libres')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  tone: AppTheme.red400,
                  title: 'Erreur',
                  message: _error,
                  action: PcButton('Réessayer', onPressed: _load),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (hasParcels) ...[
                        _buildFilterBar(),
                        const SizedBox(height: 16),
                      ],
                      if (filtered.isEmpty)
                        EmptyState(
                          icon: filteredEmpty ? Icons.search_off : Icons.campaign,
                          title: filteredEmpty ? 'Aucun résultat' : 'Aucune annonce',
                          message: filteredEmpty
                              ? 'Aucune annonce ne correspond à votre recherche.'
                              : 'Publiez une annonce pour recevoir des offres de chauffeurs.',
                          action: filteredEmpty
                              ? PcButton('Réinitialiser les filtres', onPressed: () {
                                  setState(() { _search = ''; _typeFilter = ''; });
                                })
                              : PcButton('Créer une annonce', onPressed: () {
                                  Navigator.pop(context);
                                }),
                        )
                      else
                        ...filtered.map((p) => _buildParcelCard(p)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFilterBar() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher (suivi, ville, destinataire...)',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _search.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _search = ''))
                : null,
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _typeFilter.isEmpty ? '' : _typeFilter,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: const Icon(Icons.category, size: 18),
                ),
                isExpanded: true,
                items: _typeFilters.map((f) => DropdownMenuItem(value: f['value'], child: Text(f['label']!, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _typeFilter = v ?? ''),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _sort,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: const Icon(Icons.sort, size: 18),
                ),
                isExpanded: true,
                items: _sorts.map((f) => DropdownMenuItem(value: f['value'], child: Text(f['label']!, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _sort = v ?? 'recent'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParcelCard(Parcel p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PcCard(
        onTap: () => Navigator.pushNamed(context, '/parcel/${p.id}'),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.trackingNumber,
                      style: AppTheme.mono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                ),
                StatusBadge(status: p.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.departureGarageName} → ${p.arrivalGarageName ?? '—'}',
                          style: AppFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (p.type != null) ...[
                            _infoChip(p.type.label),
                            const SizedBox(width: 6),
                          ],
                          if (p.weight != null) ...[
                            _infoChip('${p.weight} kg'),
                            const SizedBox(width: 6),
                          ],
                          if (p.isUrgent) _infoChip('Express'),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_fcfa(p.price), style: AppTheme.mono(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(_formatDate(p.createdAt), style: AppFonts.manrope(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('Voir les offres reçues'),
                onPressed: () => Navigator.pushNamed(context, '/client/offres'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slate600)),
    );
  }
}
