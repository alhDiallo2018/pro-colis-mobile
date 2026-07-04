// mobile/lib/screens/driver/garage_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/garage.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/procolis_design_system.dart';

class DriverGarageScreen extends ConsumerStatefulWidget {
  const DriverGarageScreen({super.key});

  @override
  ConsumerState<DriverGarageScreen> createState() =>
      _DriverGarageScreenState();
}

class _DriverGarageScreenState extends ConsumerState<DriverGarageScreen> {
  final ApiService _apiService = ApiService();
  Garage? _garage;
  List<User> _colleagues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authProvider).user;
      final garageId = user?.garageId;

      if (garageId == null || garageId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final results = await Future.wait([
        _apiService.getAllGarages(),
        _apiService.getGarageColleagues(garageId),
      ]);

      final garages = results[0] as List<Garage>;
      final allColleagues = results[1] as List<User>;

      final foundGarage = garages.cast<Garage?>().firstWhere(
            (g) => g!.id == garageId,
            orElse: () => null,
          );

      final colleagues =
          allColleagues.where((c) => c.id != user!.id).toList();

      if (mounted) {
        setState(() {
          _garage = foundGarage;
          _colleagues = colleagues;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Color _statusColor(DriverStatus? status) {
    switch (status) {
      case DriverStatus.available:
        return AppTheme.successColor;
      case DriverStatus.busy:
        return AppTheme.amber500;
      case DriverStatus.offline:
        return AppTheme.slate400;
      default:
        return AppTheme.slate400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Mon Garage'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(user),
    );
  }

  Widget _buildContent(User? user) {
    if (user?.garageId == null || user!.garageId!.isEmpty) {
      return _buildNoGarage();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGarageCard(user),
          const SizedBox(height: 24),
          _buildColleaguesSection(),
        ],
      ),
    );
  }

  Widget _buildNoGarage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: const Icon(
                Icons.garage_rounded,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun garage rattaché',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              "Vous n'êtes rattaché à aucun garage. Contactez un administrateur pour en rejoindre un.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.slate500),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                final uri = Uri(
                  scheme: 'mailto',
                  path: 'support@procolis.com',
                  query: 'subject=Aide - Rattachement à un garage',
                );
                launchUrl(uri);
              },
              icon: const Icon(Icons.mail_outline),
              label: const Text('Contacter le support'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGarageCard(User? user) {
    final name = _garage?.name ?? user?.garageName ?? 'Mon garage';
    final city = _garage?.city;
    final region = _garage?.region;
    final phone = _garage?.phone;
    final locationText =
        [city, region].where((e) => e != null && e.isNotEmpty).join(', ');

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.brandShadow(),
      ),
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity( 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.garage_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                if (locationText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    locationText,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity( 0.75),
                    ),
                  ),
                ],
                if (phone != null && phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _callPhone(phone),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call_rounded,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          phone,
                          style: AppTheme.mono(
                              fontSize: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColleaguesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Collègues',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            if (_colleagues.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_colleagues.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_colleagues.isEmpty)
          ProcolisCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(Icons.people_outline_rounded,
                    size: 48, color: AppTheme.slate300),
                const SizedBox(height: 10),
                const Text(
                  'Aucun collègue',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Vous êtes le seul chauffeur de ce garage pour le moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(_colleagues.length, (index) {
            final colleague = _colleagues[index];

            return ProcolisCard(
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryLight,
                              child: Text(
                                colleague.initials,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color:
                                      _statusColor(colleague.driverStatus),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.cardColor, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                colleague.fullName,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.star_rounded,
                                      size: 14,
                                      color: AppTheme.amber400),
                                  const SizedBox(width: 3),
                                  Text(
                                    colleague.formattedRating,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.slate600,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(Icons.inventory_2_outlined,
                                      size: 13, color: AppTheme.slate400),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${colleague.totalDeliveries ?? 0} livraisons',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppTheme.slate300),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
