// mobile/lib/screens/parcel/parcel_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/parcel.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/procolis_design_system.dart';
import 'confirm_delivery_screen.dart';

class ParcelDetailScreen extends ConsumerStatefulWidget {
  final Parcel parcel;

  const ParcelDetailScreen({super.key, required this.parcel});

  @override
  ConsumerState<ParcelDetailScreen> createState() => _ParcelDetailScreenState();
}

class _ParcelDetailScreenState extends ConsumerState<ParcelDetailScreen> {
  final ApiService _apiService = ApiService();
  late Parcel _parcel;
  List<ParcelEvent> _events = [];
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _parcel = widget.parcel;
    _loadDetailData();
  }

  Future<void> _loadDetailData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getParcelById(_parcel.id),
        _apiService.getParcelEvents(_parcel.id),
      ]);

      if (!mounted) return;
      setState(() {
        final updatedParcel = results[0] as Parcel?;
        _parcel = updatedParcel ?? _parcel;
        _events = results[1] as List<ParcelEvent>;
      });
    } catch (error) {
      debugPrint('Erreur chargement détail colis: $error');
      if (mounted) {
        _showSnack('Impossible de charger les dernières informations');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelParcel() async {
    if (_parcel.isFinished || _isUpdating) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le colis ?'),
        content: const Text(
          'Cette action marquera le colis comme annulé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red500),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);
    try {
      final ok = await ref
          .read(parcelProvider.notifier)
          .cancelParcel(_parcel.id, reason: 'Annulation depuis le détail');
      if (ok && mounted) {
        setState(
            () => _parcel = _parcel.copyWith(status: ParcelStatus.cancelled));
        _showSnack('Colis annulé');
      }
    } catch (error) {
      debugPrint('Erreur annulation colis: $error');
      if (mounted) {
        _showSnack('Annulation impossible');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _callDriver() async {
    final phone = _parcel.driverPhone;
    if (phone == null || phone.isEmpty) {
      _showSnack('Téléphone chauffeur indisponible');
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      _showSnack('Appel impossible');
    }
  }

  void _shareTracking() {
    Clipboard.setData(
      ClipboardData(text: 'Suivi Procolis ${_parcel.trackingNumber}'),
    );
    _showSnack('Numéro de suivi copié');
  }

  void _showReceipt() {
    _showSnack('Reçu bientôt disponible');
  }

  Future<void> _openConfirmDelivery() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmDeliveryScreen(parcel: _parcel),
      ),
    );

    if (updated == true) {
      await _loadDetailData();
    }
  }

  Future<void> _openDeliveryProof() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryProofScreen(parcel: _parcel),
      ),
    );

    if (updated == true) {
      _showSnack('Preuve de livraison enregistrée');
      await _loadDetailData();
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParcelChatScreen(
          parcel: _parcel,
          driverName: _driverName,
          driverPhone: _driverPhone,
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _arrival => _parcel.arrivalGarageName?.isNotEmpty == true
      ? _parcel.arrivalGarageName!
      : 'Arrivée';

  String get _price {
    final amount = _parcel.negotiatedPrice ??
        _parcel.price ??
        _parcel.proposedPrice ??
        _parcel.totalAmount ??
        0;
    return '${_formatNumber(amount)} FCFA';
  }

  String get _driverName {
    if (_parcel.driverName?.isNotEmpty == true) return _parcel.driverName!;
    if (_parcel.bestBid != null) return _parcel.bestBid!.driverName;
    return 'Chauffeur non assigné';
  }

  String get _driverPhone {
    if (_parcel.driverPhone?.isNotEmpty == true) return _parcel.driverPhone!;
    if (_parcel.bestBid != null) return _parcel.bestBid!.driverPhone;
    return '';
  }

  String get _eta {
    final target = _parcel.estimatedDeliveryDate ?? _parcel.deliveryDate;
    if (target == null) return '~4 h';
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return 'Arrivé';
    if (diff.inDays > 0) return '${diff.inDays} j';
    if (diff.inHours > 0) return '~${diff.inHours} h';
    return '${diff.inMinutes.clamp(1, 59)} min';
  }

  bool get _canConfirmDelivery =>
      !_parcel.isDelivered &&
      !_parcel.isCancelled &&
      (_parcel.status == ParcelStatus.outForDelivery ||
          _parcel.status == ParcelStatus.arrived ||
          _parcel.status == ParcelStatus.inTransit);

  String _formatNumber(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match[1]} ',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Détail du colis'),
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
        actions: [
          IconButton(
            onPressed: _shareTracking,
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Partager',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadDetailData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          children: [
            if (_isLoading)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            const SizedBox(height: 10),
            _TrackingHero(
              parcel: _parcel,
              arrival: _arrival,
              eta: _eta,
              price: _price,
            ),
            if (_parcel.isUrgent) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: _ExpressTag(),
              ),
            ],
            const SizedBox(height: 16),
            _DriverCard(
              name: _driverName,
              phone: _driverPhone,
              garage: _parcel.departureGarageName,
              onCall: _callDriver,
              onChat: _openChat,
            ),
            const SizedBox(height: 16),
            ProcolisCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.category_rounded,
                    label: 'Type',
                    value: _parcel.type.label,
                  ),
                  const _DetailDivider(),
                  _InfoRow(
                    icon: Icons.scale_rounded,
                    label: 'Poids',
                    value: _parcel.formattedWeight,
                    mono: true,
                  ),
                  const _DetailDivider(),
                  _InfoRow(
                    icon: Icons.person_pin_rounded,
                    label: 'Destinataire',
                    value: _parcel.receiverName.isEmpty
                        ? 'Non renseigné'
                        : _parcel.receiverName,
                  ),
                  const _DetailDivider(),
                  _InfoRow(
                    icon: Icons.call_rounded,
                    label: 'Téléphone',
                    value: _parcel.receiverPhone.isEmpty
                        ? 'Non renseigné'
                        : _parcel.receiverPhone,
                    mono: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const ProcolisSectionHeader(title: 'Suivi'),
            ProcolisCard(
              padding: const EdgeInsets.all(16),
              child: _DesignTimeline(
                parcel: _parcel,
                events: _events,
              ),
            ),
            const SizedBox(height: 16),
            if (_parcel.isDelivered) ...[
              ProcolisCard(
                padding: const EdgeInsets.all(14),
                onTap: _openDeliveryProof,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.green50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preuve de livraison',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Photo, signature et remarque',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_canConfirmDelivery) ...[
              FilledButton.icon(
                onPressed: _openConfirmDelivery,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Confirmer la livraison'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showReceipt,
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('Voir le reçu'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: AppTheme.amber50,
                      foregroundColor: AppTheme.amber700,
                      side: const BorderSide(color: AppTheme.amber400),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _parcel.isDelivered
                      ? ElevatedButton.icon(
                          onPressed: _openDeliveryProof,
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text('Preuve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _parcel.isFinished || _isUpdating
                              ? null
                              : _cancelParcel,
                          icon: _isUpdating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cancel_rounded),
                          label: const Text('Annuler'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.red500,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingHero extends StatelessWidget {
  final Parcel parcel;
  final String arrival;
  final String eta;
  final String price;

  const _TrackingHero({
    required this.parcel,
    required this.arrival,
    required this.eta,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.brandShadow(),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  parcel.trackingNumber,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _HeroStatusBadge(status: parcel.status),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _RouteEnd(
                  label: 'Départ',
                  city: parcel.departureGarageName,
                  alignEnd: false,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _RouteLine(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RouteEnd(
                  label: 'Arrivée',
                  city: arrival,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMeta(label: 'Distance', value: '240 km'),
              const SizedBox(width: 18),
              _HeroMeta(label: 'Reste', value: eta),
              const SizedBox(width: 18),
              Expanded(
                child: _HeroMeta(label: 'Prix', value: price),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteEnd extends StatelessWidget {
  final String label;
  final String city;
  final bool alignEnd;

  const _RouteEnd({
    required this.label,
    required this.city,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 2,
            color: Colors.white.withValues(alpha: 0.42),
          ),
          Positioned(
            left: 34,
            child: Container(
              padding: const EdgeInsets.all(2),
              color: Colors.transparent,
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.mono(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HeroStatusBadge extends StatelessWidget {
  final ParcelStatus status;

  const _HeroStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: status.color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ExpressTag extends StatelessWidget {
  const _ExpressTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.red50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flash_on_rounded, color: AppTheme.red500, size: 16),
          SizedBox(width: 5),
          Text(
            'EXPRESS',
            style: TextStyle(
              color: AppTheme.red500,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final String name;
  final String phone;
  final String garage;
  final VoidCallback onCall;
  final VoidCallback onChat;

  const _DriverCard({
    required this.name,
    required this.phone,
    required this.garage,
    required this.onCall,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return ProcolisCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryLight,
                child: Text(
                  initials.isEmpty ? 'PC' : initials,
                  style: const TextStyle(
                    color: AppTheme.teal700,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.green500,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$garage · 4,9 ★ · Camionnette',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SoftIconButton(
            icon: Icons.call_rounded,
            onTap: phone.isEmpty ? null : onCall,
          ),
          const SizedBox(width: 6),
          _SoftIconButton(icon: Icons.chat_rounded, onTap: onChat),
        ],
      ),
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SoftIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryLight,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            icon,
            color: onTap == null ? AppTheme.slate400 : AppTheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: mono
                  ? AppTheme.mono(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    )
                  : const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }
}

class _DesignTimeline extends StatelessWidget {
  final Parcel parcel;
  final List<ParcelEvent> events;

  const _DesignTimeline({
    required this.parcel,
    required this.events,
  });

  List<_TimelineStep> get _steps {
    if (events.isNotEmpty) {
      final sorted = [...events]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return sorted
          .map(
            (event) => _TimelineStep(
              title: event.status.label,
              subtitle: event.description,
              date: _formatEventDate(event.timestamp),
              done: true,
              color: event.status.color,
            ),
          )
          .toList();
    }

    // Fallback visuel calé sur le Stepper de la maquette quand l'API ne
    // renvoie pas encore d'événements de suivi pour le colis.
    final all = [
      (ParcelStatus.pending, 'Colis créé', parcel.createdAt),
      (ParcelStatus.confirmed, 'Chauffeur assigné', parcel.pickupDate),
      (ParcelStatus.inTransit, 'En route vers la destination', null),
      (ParcelStatus.delivered, 'Remis au destinataire', parcel.deliveryDate),
    ];
    final currentIndex = all.indexWhere((item) => item.$1 == parcel.status);
    final resolvedIndex = currentIndex < 0 ? 0 : currentIndex;

    return [
      for (var i = 0; i < all.length; i++)
        _TimelineStep(
          title: all[i].$1.label,
          subtitle: all[i].$2,
          date: all[i].$3 == null ? '' : _formatEventDate(all[i].$3!),
          done: i <= resolvedIndex,
          color: all[i].$1.color,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineTile(
            step: steps[i],
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }

  static String _formatEventDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final String date;
  final bool done;
  final Color color;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.done,
    required this.color,
  });
}

class _TimelineTile extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;

  const _TimelineTile({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = step.done ? step.color : AppTheme.slate300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: step.done ? color : AppTheme.cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: step.done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 48,
                  color: color.withValues(alpha: 0.32),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (step.date.isNotEmpty)
                      Text(
                        step.date,
                        style: AppTheme.mono(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ParcelChatScreen extends StatefulWidget {
  final Parcel parcel;
  final String driverName;
  final String driverPhone;

  const ParcelChatScreen({
    super.key,
    required this.parcel,
    required this.driverName,
    required this.driverPhone,
  });

  @override
  State<ParcelChatScreen> createState() => _ParcelChatScreenState();
}

class _ParcelChatScreenState extends State<ParcelChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Bonjour, je suis en route vers le point de départ.',
      time: '09:34',
      mine: false,
    ),
    const _ChatMessage(
      text: 'Parfait, le colis est prêt.',
      time: '09:36',
      mine: true,
    ),
    const _ChatMessage(
      audioLen: '0:08',
      time: '09:38',
      mine: false,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _callDriver() async {
    if (widget.driverPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: widget.driverPhone);
    await launchUrl(uri);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          time: _formatNow(),
          mine: true,
        ),
      );
      _messageController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _ChatAvatar(name: widget.driverName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.driverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'En ligne',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _SoftIconButton(
              icon: Icons.call_rounded,
              onTap: widget.driverPhone.isEmpty ? null : _callDriver,
            ),
          ),
        ],
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: Column(
        children: [
          _PinnedParcelChip(parcel: widget.parcel),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              itemCount: _messages.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Aujourd’hui',
                        style: TextStyle(
                          color: AppTheme.slate400,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                return _ChatBubble(message: _messages[index - 1]);
              },
            ),
          ),
          _MessageComposer(
            controller: _messageController,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String? text;
  final String? audioLen;
  final String time;
  final bool mine;

  const _ChatMessage({
    this.text,
    this.audioLen,
    required this.time,
    required this.mine,
  });
}

class _ChatAvatar extends StatelessWidget {
  final String name;

  const _ChatAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.primaryLight,
          child: Text(
            initials.isEmpty ? 'PC' : initials,
            style: const TextStyle(
              color: AppTheme.teal700,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: 1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppTheme.green500,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _PinnedParcelChip extends StatelessWidget {
  final Parcel parcel;

  const _PinnedParcelChip({required this.parcel});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryLight,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.teal100)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.inventory_2_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  parcel.trackingNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    color: AppTheme.teal700,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _MiniStatusBadge(status: parcel.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatusBadge extends StatelessWidget {
  final ParcelStatus status;

  const _MiniStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: status.color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final bubbleColor = mine ? AppTheme.primary : AppTheme.cardColor;
    final textColor = mine ? Colors.white : AppTheme.slate700;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          boxShadow: AppTheme.softShadow(alpha: 0.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.audioLen != null)
              _AudioMessage(
                mine: mine,
                audioLen: message.audioLen!,
              )
            else
              Text(
                message.text ?? '',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: AppTheme.mono(
                color: textColor.withValues(alpha: 0.62),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioMessage extends StatelessWidget {
  final bool mine;
  final String audioLen;

  const _AudioMessage({required this.mine, required this.audioLen});

  @override
  Widget build(BuildContext context) {
    final color = mine ? Colors.white : AppTheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_circle_rounded, color: color, size: 24),
        const SizedBox(width: 8),
        _MiniWaveform(color: color),
        const SizedBox(width: 8),
        Text(
          audioLen,
          style: AppTheme.mono(
            color: color.withValues(alpha: 0.82),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MiniWaveform extends StatelessWidget {
  final Color color;

  const _MiniWaveform({required this.color});

  @override
  Widget build(BuildContext context) {
    const heights = [10.0, 16.0, 12.0, 20.0, 14.0, 18.0];
    return Row(
      children: heights
          .map(
            (height) => Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MessageComposer extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageComposer({
    required this.controller,
    required this.onSend,
  });

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncTextState);
  }

  @override
  void didUpdateWidget(covariant _MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_syncTextState);
    widget.controller.addListener(_syncTextState);
    _syncTextState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTextState);
    super.dispose();
  }

  void _syncTextState() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText == _hasText) return;
    setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          border: Border(top: BorderSide(color: AppTheme.slate200)),
        ),
        child: Row(
          children: [
            _ComposerIconButton(
              icon: Icons.add_rounded,
              background: Colors.transparent,
              foreground: AppTheme.slate600,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        minLines: 1,
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => widget.onSend(),
                        decoration: const InputDecoration(
                          hintText: 'Votre message…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.mic_rounded,
                      color: AppTheme.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ComposerIconButton(
              icon: Icons.send_rounded,
              background: _hasText ? AppTheme.primary : AppTheme.slate200,
              foreground: _hasText ? Colors.white : AppTheme.slate400,
              onTap: _hasText ? widget.onSend : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  const _ComposerIconButton({
    required this.icon,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: foreground, size: 22),
        ),
      ),
    );
  }
}
