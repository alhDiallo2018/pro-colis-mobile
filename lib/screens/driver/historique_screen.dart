// lib/screens/driver/historique_screen.dart
//
// Historique des courses du chauffeur (livrées / annulées).
// Équivalent mobile du HistoriqueScreen web.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/parcel.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
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
      'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
      'juil', 'août', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = AppTheme.statusColors(parcel.status);
    final from = parcel.departureGarageName.isNotEmpty
        ? parcel.departureGarageName
        : '—';
    final to = (parcel.arrivalGarageName?.isNotEmpty ?? false)
        ? parcel.arrivalGarageName!
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
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_right_alt_rounded,
                          size: 16, color: AppTheme.slate400),
                    ),
                    Flexible(
                      child: Text(to,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
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
                        style: GoogleFonts.manrope(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(parcel.status.label.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
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
