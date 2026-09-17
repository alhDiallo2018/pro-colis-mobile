// mobile/lib/screens/parcel/driver_profile_screen.dart
// Fiche publique d'un chauffeur, consultée par le client avant de le choisir.
// N'affiche que les informations utiles à la mise en relation : identité,
// localité, disponibilité, expérience, véhicule et avis — rien d'autre.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class DriverProfileScreen extends StatefulWidget {
  final String driverId;

  /// Chauffeur déjà connu (venant de la liste de choix) : évite un rechargement
  /// et sert de repli si l'endpoint de détail échoue.
  final User? initial;

  const DriverProfileScreen({super.key, required this.driverId, this.initial});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final ApiService _api = ApiService();

  User? _driver;
  List<Map<String, dynamic>> _ratings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _driver = widget.initial;
    _load();
  }

  Future<void> _load() async {
    final detail = await _api.getPublicDriver(widget.driverId);
    if (!mounted) return;
    setState(() {
      if (detail != null) _driver = detail;
      _loading = false;
    });
    final ratings = await _api.getDriverRatings(widget.driverId);
    if (!mounted) return;
    setState(() => _ratings = ratings);
  }

  bool get _selectable =>
      _driver?.driverStatus != DriverStatus.offline;

  void _choose() {
    final driver = _driver;
    if (driver == null || !_selectable) return;
    // Ouverte depuis le formulaire : on renvoie le chauffeur à l'appelant.
    if (Navigator.of(context).canPop()) {
      context.pop(driver);
      return;
    }
    // Ouverte en accès direct (deep link) : on ouvre le formulaire de création
    // avec le chauffeur pré-sélectionné.
    context.go('/parcel/new?driver=${driver.id}');
  }

  @override
  Widget build(BuildContext context) {
    final driver = _driver;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Fiche chauffeur'),
        backgroundColor: AppTheme.cardColor,
      ),
      body: _loading && driver == null
          ? const Center(child: CircularProgressIndicator())
          : driver == null
              ? const Center(child: Text('Chauffeur introuvable'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _header(driver),
                    const SizedBox(height: 16),
                    _stats(driver),
                    const SizedBox(height: 16),
                    _chooseButton(driver),
                    const SizedBox(height: 16),
                    _avis(driver),
                  ],
                ),
    );
  }

  Widget _header(User driver) {
    final status = driver.driverStatus ?? DriverStatus.offline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowSm(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(driver),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.fullName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [driver.city, driver.region]
                          .where((e) => e != null && e.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    _statusChip(status),
                  ],
                ),
              ),
            ],
          ),
          if (driver.phone.isNotEmpty) ...[
            const Divider(height: 24),
            _infoRow(Icons.call_rounded, 'Contact', driver.formattedPhone),
          ],
          if (driver.vehicleInfo.isNotEmpty)
            _infoRow(
                Icons.local_shipping_rounded, 'Véhicule', driver.vehicleInfo),
        ],
      ),
    );
  }

  Widget _avatar(User driver) {
    final photo = driver.profilePhoto;
    final initials = driver.initials;
    return ClipOval(
      child: SizedBox(
        width: 64,
        height: 64,
        child: photo != null && photo.isNotEmpty
            ? Image.network(
                ApiService.resolveMediaUrl(photo),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initials(initials),
              )
            : _initials(initials),
      ),
    );
  }

  Widget _initials(String initials) {
    return Container(
      color: AppTheme.primaryLight,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _statusChip(DriverStatus status) {
    final (label, color, bg, icon) = switch (status) {
      DriverStatus.available => (
          'Disponible',
          AppTheme.green700,
          AppTheme.green50,
          Icons.check_circle_rounded,
        ),
      DriverStatus.busy => (
          'Occupé',
          AppTheme.amber700,
          AppTheme.amber50,
          Icons.local_shipping_rounded,
        ),
      DriverStatus.offline => (
          'Hors ligne',
          AppTheme.slate500,
          AppTheme.slate100,
          Icons.circle_outlined,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.slate400),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _stats(User driver) {
    final rating = driver.rating ?? 0;
    final deliveries = driver.completedDeliveries ?? 0;
    final total = driver.totalDeliveries ?? 0;
    return Row(
      children: [
        _stat('Note', rating > 0 ? rating.toStringAsFixed(1) : '—'),
        _stat('Livraisons', '$deliveries'),
        _stat('Total courses', '$total'),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _chooseButton(User driver) {
    final selectable = _selectable;
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: selectable ? _choose : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.slate200,
            disabledForegroundColor: AppTheme.slate500,
            minimumSize: const Size.fromHeight(50),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
          icon: const Icon(Icons.local_shipping_rounded),
          label: Text(selectable ? 'Choisir ce chauffeur' : 'Chauffeur hors ligne'),
        ),
        if (!selectable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Ce chauffeur est hors ligne : vous ne pouvez pas lui envoyer '
              'de demande pour le moment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _avis(User driver) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowSm(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: AppTheme.amber500, size:20),
              const SizedBox(width: 8),
              Text('Avis clients',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          if (_ratings.isEmpty)
            Text('Aucun avis pour le moment.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))
          else
            ..._ratings.map((r) {
              final rating = (r['rating'] as num?)?.toInt() ?? 0;
              final comment = r['comment']?.toString() ?? '';
              final authorRaw = r['author'];
              final author = authorRaw is Map
                  ? (authorRaw['fullName']?.toString() ?? 'Client')
                  : 'Client';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.slate50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 15,
                            color: i < rating
                                ? AppTheme.amber500
                                : AppTheme.slate300,
                          );
                        }),
                        const Spacer(),
                        Text(author,
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(comment,
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textPrimary)),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
