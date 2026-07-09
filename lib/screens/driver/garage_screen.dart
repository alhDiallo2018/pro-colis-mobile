// mobile/lib/screens/driver/garage_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/garage.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

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
    final uri =
        Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  PcAvatarStatus _avatarStatus(DriverStatus? status) {
    switch (status) {
      case DriverStatus.available:
        return PcAvatarStatus.online;
      case DriverStatus.busy:
        return PcAvatarStatus.busy;
      case DriverStatus.offline:
        return PcAvatarStatus.offline;
      default:
        return PcAvatarStatus.offline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Ma Zone')),
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
          const SizedBox(height: 20),
          _buildColleaguesSection(),
        ],
      ),
    );
  }

  Widget _buildNoGarage() {
    return PcEmptyState(
      icon: Icons.garage_rounded,
      tone: PcTone.primary,
      title: 'Aucune zone rattachée',
      message:
          "Vous n'êtes rattaché à aucune zone. Contactez un administrateur pour en rejoindre une.",
      action: PcButton(
        'Contacter le support',
        variant: PcButtonVariant.secondary,
        icon: Icons.mail_outline_rounded,
        onPressed: () {
          final uri = Uri(
            scheme: 'mailto',
            path: 'support@procolis.com',
            query: 'subject=Aide - Rattachement à une zone',
          );
          launchUrl(uri);
        },
      ),
    );
  }

  Widget _buildGarageCard(User? user) {
    final name = _garage?.name ?? user?.garageName ?? 'Ma zone';
    final city = _garage?.city;
    final region = _garage?.region;
    final phone = _garage?.phone;

    final parts = [city, region]
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .toList();
    var locationText = parts.isEmpty ? '—' : parts.join(', ');
    if (phone != null && phone.isNotEmpty) {
      locationText = '$locationText · $phone';
    }

    return PcCard(
      padding: const EdgeInsets.all(20),
      shadow: AppTheme.shadowXs(),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.teal50,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.garage_rounded,
              size: 30,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  locationText,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ),
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(width: 12),
            PcIconButton(
              Icons.call_rounded,
              variant: PcIconButtonVariant.soft,
              onPressed: () => _callPhone(phone),
              tooltip: 'Appeler la zone',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColleaguesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PcSectionHeader('Chauffeurs de la zone · ${_colleagues.length}'),
        if (_colleagues.isEmpty)
          const PcCard(
            child: PcEmptyState(
              icon: Icons.people_outline_rounded,
              title: 'Aucun collègue',
              message:
                  'Vous êtes le seul chauffeur rattaché à cette zone pour le moment.',
            ),
          )
        else
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _colleagues.length; i++) ...[
                  if (i > 0) const PcDivider(),
                  _buildColleagueRow(_colleagues[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildColleagueRow(User colleague) {
    return PcListRow(
      leading: PcAvatar(
        colleague.fullName,
        size: 44,
        status: _avatarStatus(colleague.driverStatus),
      ),
      title: colleague.fullName,
      subtitle:
          '${colleague.formattedRating} ★ · ${colleague.totalDeliveries ?? 0} livraisons',
    );
  }
}
