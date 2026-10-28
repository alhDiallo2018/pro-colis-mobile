// lib/screens/driver/historique_screen.dart
//
// Historique des courses du chauffeur (livrées / annulées).
// Équivalent mobile du HistoriqueScreen web.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/parcel.dart';
import '../../services/api_service.dart';
import '../../services/offline_access.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

class DriverHistoriqueScreen extends ConsumerStatefulWidget {
  const DriverHistoriqueScreen({super.key});

  @override
  ConsumerState<DriverHistoriqueScreen> createState() =>
      _DriverHistoriqueScreenState();
}

class _DriverHistoriqueScreenState
    extends ConsumerState<DriverHistoriqueScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Parcel> _history = [];
  String? _error;
  bool _wasOffline = OfflineAccess.instance.value.disconnected;

  @override
  void initState() {
    super.initState();
    OfflineAccess.instance.addListener(_onConnectionChanged);
    _load();
  }

  void _onConnectionChanged() {
    final offline = OfflineAccess.instance.value.disconnected;
    if (_wasOffline && !offline) _load();
    _wasOffline = offline;
  }

  @override
  void dispose() {
    OfflineAccess.instance.removeListener(_onConnectionChanged);
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final parcels = await _apiService.getDriverParcels();
      if (!mounted) return;
      setState(() {
        _history = parcels
            .where((p) =>
                p.status == ParcelStatus.delivered ||
                p.status == ParcelStatus.cancelled)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
        _error = null;
      });
    } catch (error, stack) {
      debugPrint('[Historique] Chargement impossible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      if (mounted)
        setState(() {
          _isLoading = false;
          _error =
              'Historique indisponible. Hors ligne, seules les courses déjà chargées sur cet appareil sont consultables.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Historique des courses'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _load,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 40),
                    Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!)),
                    TextButton(
                        onPressed: _load, child: const Text('Réessayer')),
                  ])
                : _history.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          PcEmptyState(
                            icon: Icons.history_rounded,
                            tone: PcTone.primary,
                            title: 'Aucune course terminée',
                            message:
                                'Vos livraisons terminées ou annulées apparaîtront ici.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: _history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _HistoryRow(parcel: _history[index]),
                      ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Parcel parcel;
  const _HistoryRow({required this.parcel});

  String _formatDate(DateTime d) {
    const months = [
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'juin',
      'juil',
      'août',
      'sep',
      'oct',
      'nov',
      'déc'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = AppTheme.statusColors(parcel.status);
    final from = parcel.departureCity?.isNotEmpty == true
        ? parcel.departureCity!
        : parcel.departureZoneName.isNotEmpty
            ? parcel.departureZoneName
            : '—';
    final to = parcel.arrivalCity?.isNotEmpty == true
        ? parcel.arrivalCity!
        : (parcel.arrivalZoneName?.isNotEmpty ?? false)
            ? parcel.arrivalZoneName!
            : '—';
    final date = parcel.deliveryDate ?? parcel.updatedAt ?? parcel.createdAt;

    return PcCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(from,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.plusJakartaSans(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_right_alt_rounded,
                          size: 16, color: AppTheme.slate400),
                    ),
                    Flexible(
                      child: Text(to,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.plusJakartaSans(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(parcel.trackingNumber,
                        style: AppTheme.mono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.slate500)),
                    Text('  ·  ${_formatDate(date)}',
                        style: AppFonts.manrope(
                            fontSize: 12, color: AppTheme.slate500)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (parcel.price != null)
                Text('${parcel.price!.toStringAsFixed(0)} FCFA',
                    style: AppTheme.mono(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.teal600)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(parcel.status.label.toUpperCase(),
                    style: AppFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: status.foreground)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
