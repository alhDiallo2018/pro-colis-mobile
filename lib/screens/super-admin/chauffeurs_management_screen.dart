import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

/// Liste globale des chauffeurs (super-admin), alignée sur ChauffeursPage.tsx.
/// Avatar + nom + ville/téléphone + note/livraisons + badge de statut.
class ChauffeursManagementScreen extends ConsumerStatefulWidget {
  const ChauffeursManagementScreen({super.key});

  @override
  ConsumerState<ChauffeursManagementScreen> createState() =>
      _ChauffeursManagementScreenState();
}

class _ChauffeursManagementScreenState
    extends ConsumerState<ChauffeursManagementScreen> {
  final ApiService _apiService = ApiService();
  List<User> _drivers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    try {
      final drivers = await _apiService.getAllDriversSuperAdmin();
      if (mounted) {
        setState(() {
          _drivers = drivers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // Correspondance statut chauffeur -> design system (aligné web).
  ({PcAvatarStatus avatar, PcTone tone, String label}) _statusMeta(User d) {
    switch (d.driverStatus) {
      case DriverStatus.available:
        return (
          avatar: PcAvatarStatus.online,
          tone: PcTone.green,
          label: 'Disponible'
        );
      case DriverStatus.busy:
        return (
          avatar: PcAvatarStatus.busy,
          tone: PcTone.amber,
          label: 'Occupé'
        );
      case DriverStatus.offline:
      case null:
        return (
          avatar: PcAvatarStatus.offline,
          tone: PcTone.neutral,
          label: 'Hors ligne'
        );
    }
  }

  List<User> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _drivers;
    return _drivers.where((d) {
      return d.fullName.toLowerCase().contains(q) ||
          d.phone.toLowerCase().contains(q) ||
          (d.city ?? '').toLowerCase().contains(q) ||
          (d.garageName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final total = _drivers.length;
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: Text(
          'Chauffeurs${total > 0 ? ' · $total' : ''}',
          style: AppFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: PcIconButton(
                Icons.refresh_rounded,
                variant: PcIconButtonVariant.soft,
                size: PcButtonSize.sm,
                tooltip: 'Rafraîchir',
                onPressed: _loadDrivers,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Recherche.
          Container(
            color: AppTheme.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un chauffeur...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppTheme.slate50,
              ),
              style: AppFonts.manrope(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const PcDivider(),

          // Liste.
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? PcEmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: 'Aucun chauffeur',
                        message:
                            'Aucun chauffeur ne correspond à votre recherche.',
                        action: PcButton(
                          'Actualiser',
                          icon: Icons.refresh_rounded,
                          variant: PcButtonVariant.secondary,
                          size: PcButtonSize.sm,
                          onPressed: _loadDrivers,
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: _loadDrivers,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            PcSectionHeader('Chauffeurs · ${filtered.length}'),
                            PcCard(
                              padding: EdgeInsets.zero,
                              shadow: AppTheme.shadowXs(),
                              child: Column(
                                children: [
                                  for (var i = 0; i < filtered.length; i++) ...[
                                    if (i > 0) const PcDivider(),
                                    _buildDriverRow(filtered[i]),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverRow(User driver) {
    final meta = _statusMeta(driver);
    final location = (driver.city != null && driver.city!.isNotEmpty)
        ? driver.city!
        : (driver.garageName != null && driver.garageName!.isNotEmpty)
            ? driver.garageName!
            : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          PcAvatar(driver.fullName, status: meta.avatar),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  driver.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (location != null) ...[
                      Flexible(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ),
                      Text(
                        '  ·  ',
                        style: AppFonts.manrope(
                          fontSize: 12.5,
                          color: AppTheme.slate400,
                        ),
                      ),
                    ],
                    Text(
                      driver.formattedPhone,
                      style: AppTheme.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${driver.rating != null ? driver.rating!.toStringAsFixed(1) : '—'} ★',
                style: AppTheme.mono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${driver.completedDeliveries ?? 0} livraisons',
                style: AppFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.slate500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          PcBadge(meta.label, tone: meta.tone),
        ],
      ),
    );
  }
}
