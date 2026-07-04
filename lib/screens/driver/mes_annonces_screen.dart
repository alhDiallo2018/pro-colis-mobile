// mobile/lib/screens/driver/mes_annonces_screen.dart
// Liste et gestion des annonces du chauffeur - aligné Web

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'publish_trip_screen.dart';

class DriverMesAnnoncesScreen extends ConsumerStatefulWidget {
  const DriverMesAnnoncesScreen({super.key});

  @override
  ConsumerState<DriverMesAnnoncesScreen> createState() =>
      _DriverMesAnnoncesScreenState();
}

class _DriverMesAnnoncesScreenState
    extends ConsumerState<DriverMesAnnoncesScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _ads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    try {
      final ads = await _apiService.getMyAdvertisements();
      if (mounted) setState(() { _ads = ads; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _closeAd(String adId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Fermer l\'annonce ?'),
        content: const Text('L\'annonce ne sera plus visible pour les clients.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Fermer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _apiService.closeAdvertisement(adId);
      await _loadAds();
    }
  }

  Future<void> _viewOffers(String adId) async {
    final response = await _apiService.getAdvertisementDetail(adId);
    if (!mounted) return;
    final offers = response['offers'] as List<dynamic>? ?? [];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Offres reçues',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (offers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Aucune offre pour le moment')),
              )
            else
              ...offers.map((offer) {
                final o = offer as Map<String, dynamic>;
                final client = o['client'];
                final clientName = client?['fullName']?.toString() ?? 'Client';
                final price = (o['price'] ?? 0).toDouble();
                final status = o['status']?.toString() ?? 'pending';
                final oid = o['id']?.toString() ?? '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.teal50,
                    child: Text(clientName[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.teal600,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(clientName),
                  subtitle: Text('$price FCFA'),
                  trailing: status == 'pending'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle,
                                  color: AppTheme.green600),
                              onPressed: () async {
                                await _apiService
                                    .acceptAdvertisementOffer(adId, oid);
                                Navigator.pop(ctx);
                                await _loadAds();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel,
                                  color: AppTheme.red400),
                              onPressed: () async {
                                await _apiService
                                    .rejectAdvertisementOffer(adId, oid);
                                Navigator.pop(ctx);
                                await _loadAds();
                              },
                            ),
                          ],
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'accepted'
                                ? AppTheme.green50
                                : AppTheme.red50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status == 'accepted' ? 'Acceptée' : 'Refusée',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: status == 'accepted'
                                    ? AppTheme.green600
                                    : AppTheme.red400),
                          ),
                        ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Mes annonces',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PublishTripScreen()),
              );
              if (result == true) await _loadAds();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'new-ad',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PublishTripScreen()),
          );
          if (result == true) await _loadAds();
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAds,
              child: _ads.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Icon(Icons.campaign_outlined,
                            size: 64, color: AppTheme.slate300),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text('Aucune annonce publiée',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary)),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text('Publiez un trajet pour trouver des clients',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.slate400)),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _ads.length,
                      itemBuilder: (context, index) {
                        final ad = _ads[index];
                        final departure =
                            ad['departureCity']?.toString() ?? 'Départ';
                        final arrival =
                            ad['arrivalCity']?.toString() ?? 'Arrivée';
                        final price =
                            (ad['proposedPrice'] ?? 0).toDouble();
                        final weight =
                            ad['availableWeight']?.toString() ?? 'N/A';
                        final status =
                            ad['status']?.toString() ?? 'active';
                        final offers =
                            ad['offers'] as List<dynamic>? ?? [];
                        final adId = ad['id']?.toString() ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: AppTheme.slate200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.route_rounded,
                                        color: AppTheme.primary, size: 22),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$departure → $arrival',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppTheme.textPrimary),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: status == 'active'
                                            ? AppTheme.green50
                                            : AppTheme.slate100,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status == 'active'
                                            ? 'Active'
                                            : 'Fermée',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: status == 'active'
                                                ? AppTheme.green600
                                                : AppTheme.slate500),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _metaChip(
                                        Icons.monetization_on_outlined,
                                        '${price.toStringAsFixed(0)} FCFA'),
                                    const SizedBox(width: 8),
                                    _metaChip(
                                        Icons.inventory_2_outlined,
                                        '$weight kg'),
                                    const SizedBox(width: 8),
                                    _metaChip(
                                        Icons.local_offer_outlined,
                                        '${offers.length} offre(s)'),
                                  ],
                                ),
                                if (status == 'active') ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (offers.isNotEmpty)
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _viewOffers(adId),
                                            icon: const Icon(Icons.visibility,
                                                size: 16),
                                            label: Text(
                                                'Voir offres (${offers.length})'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.primary,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _closeAd(adId),
                                        icon: const Icon(Icons.close,
                                            size: 16),
                                        label: const Text('Fermer'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.error,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.slate500),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.slate600,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
