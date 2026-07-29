// lib/screens/dashboard/notifications/notifications_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:procolis/theme/fonts.dart';

import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/pc_components.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNotificationsRead;

  const NotificationsScreen({super.key, this.onNotificationsRead});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  List<_NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _apiService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = data.map(_NotificationItem.fromApi).toList();
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Erreur chargement notifications: $error');
      if (mounted) {
        setState(() {
          _notifications = [];
          _error = 'Impossible de charger les notifications.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final success = await _apiService.markAllNotificationsAsRead();
      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de marquer les notifications comme lues'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
      setState(() {
        _notifications = [
          for (final notification in _notifications)
            notification.copyWith(isRead: true),
        ];
      });
      widget.onNotificationsRead?.call();
    } catch (error, stackTrace) {
      debugPrint(
        'Erreur markAllNotificationsAsRead: $error\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de marquer les notifications comme lues'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(_NotificationItem notification) async {
    if (notification.isRead) return;

    setState(() {
      _notifications = [
        for (final item in _notifications)
          item.id == notification.id ? item.copyWith(isRead: true) : item,
      ];
    });
    widget.onNotificationsRead?.call();

    try {
      final success = await _apiService.markNotificationAsRead(notification.id);
      if (!success) {
        debugPrint(
          'Notification ${notification.id}: lecture non confirmée par l’API',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Erreur markNotificationAsRead: $error\n$stackTrace',
      );
    }
  }

  void _openNotification(_NotificationItem notification) {
    // Le marquage reste optimiste pour que l'ouverture soit instantanée ; la
    // requête réseau continue sans bloquer l'affichage du contenu détaillé.
    if (!notification.isRead) {
      unawaited(_markAsRead(notification));
    }
    final displayedNotification = notification.copyWith(isRead: true);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.cardColor,
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => _NotificationDetailSheet(
        notification: displayedNotification,
        onOpenRelated: displayedNotification.relatedRoute == null
            ? null
            : () {
                final route = displayedNotification.relatedRoute;
                Navigator.of(sheetContext).pop();
                if (mounted && route != null) context.push(route);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        _notifications.where((notification) => !notification.isRead).length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
        actions: [
          IconButton(
            onPressed: unreadCount == 0 ? null : _markAllAsRead,
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Tout marquer comme lu',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _loadNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
                    children: [
                      PcEmptyState(
                        icon: Icons.error_outline_rounded,
                        tone: PcTone.red,
                        title: 'Erreur de chargement',
                        message: _error,
                        action: PcButton(
                          'Réessayer',
                          icon: Icons.refresh_rounded,
                          size: PcButtonSize.sm,
                          onPressed: _loadNotifications,
                        ),
                      ),
                    ],
                  )
                : _notifications.isEmpty
                    ? const _EmptyNotifications()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return _NotificationTile(
                            notification: notification,
                            onTap: () => _openNotification(notification),
                          );
                        },
                      ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final _NotificationItem notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Material(
      color: unread ? AppTheme.teal50 : AppTheme.cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.slate200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pastille non-lu (6px) à gauche.
              Padding(
                padding: const EdgeInsets.only(top: 15, right: 6),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: unread ? AppTheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: notification.tone.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  notification.icon,
                  color: notification.tone.foreground,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.manrope(
                        color: AppTheme.slate500,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Text(
                          notification.when,
                          style: AppFonts.manrope(
                            color: AppTheme.slate400,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Voir le détail',
                          style: AppFonts.manrope(
                            color: AppTheme.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 17,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 120),
      children: const [
        PcEmptyState(
          icon: Icons.notifications_off_rounded,
          tone: PcTone.primary,
          title: 'Aucune notification',
          message:
              'Vous serez notifié des offres, statuts et confirmations de livraison.',
        ),
      ],
    );
  }
}

class _NotificationItem {
  final String id;
  final IconData icon;
  final _NotificationTone tone;
  final String title;
  final String body;
  final String when;
  final String type;
  final String priority;
  final String? senderName;
  final String? parcelId;
  final String? bidId;
  final String? advertisementId;
  final DateTime? createdAt;
  final Map<String, dynamic> data;
  final bool isRead;

  const _NotificationItem({
    required this.id,
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.when,
    required this.type,
    required this.priority,
    required this.senderName,
    required this.parcelId,
    required this.bidId,
    required this.advertisementId,
    required this.createdAt,
    required this.data,
    required this.isRead,
  });

  factory _NotificationItem.fromApi(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'info';
    final rawData = json['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    final createdAt = _parseDate(json['createdAt'] ?? json['created_at']);
    return _NotificationItem(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      icon: _iconFor(type),
      tone: _toneFor(type),
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? json['message']?.toString() ?? '',
      when: _relativeTime(createdAt),
      type: type,
      priority: json['priority']?.toString() ?? 'normal',
      senderName:
          json['senderName']?.toString() ?? json['sender_name']?.toString(),
      parcelId: json['parcelId']?.toString() ??
          json['parcel_id']?.toString() ??
          data['parcelId']?.toString(),
      bidId: json['bidId']?.toString() ??
          json['bid_id']?.toString() ??
          data['bidId']?.toString(),
      advertisementId: data['advertisementId']?.toString(),
      createdAt: createdAt,
      data: data,
      isRead: json['isRead'] == true || json['is_read'] == true,
    );
  }

  _NotificationItem copyWith({bool? isRead}) {
    return _NotificationItem(
      id: id,
      icon: icon,
      tone: tone,
      title: title,
      body: body,
      when: when,
      type: type,
      priority: priority,
      senderName: senderName,
      parcelId: parcelId,
      bidId: bidId,
      advertisementId: advertisementId,
      createdAt: createdAt,
      data: data,
      isRead: isRead ?? this.isRead,
    );
  }

  static IconData _iconFor(String type) {
    if (type.contains('payment') ||
        type.contains('wallet') ||
        type.contains('commission')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (type.contains('message')) return Icons.chat_bubble_rounded;
    if (type.contains('delivery') || type.contains('delivered')) {
      return Icons.task_alt_rounded;
    }
    if (type.contains('parcel') || type.contains('driver_assigned')) {
      return Icons.local_shipping_rounded;
    }
    if (type.contains('bid') || type.contains('offer')) {
      return Icons.gavel_rounded;
    }
    return Icons.notifications_rounded;
  }

  static _NotificationTone _toneFor(String type) {
    if (type.contains('rejected') ||
        type.contains('cancelled') ||
        type.contains('failed')) {
      return const _NotificationTone.red();
    }
    if (type.contains('accepted') ||
        type.contains('confirmed') ||
        type.contains('delivered')) {
      return const _NotificationTone.green();
    }
    if (type.contains('payment') ||
        type.contains('wallet') ||
        type.contains('commission')) {
      return const _NotificationTone.amber();
    }
    return const _NotificationTone.primary();
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  static String _relativeTime(DateTime? parsed) {
    if (parsed == null) return 'maintenant';

    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    return '${diff.inDays} j';
  }

  String get typeLabel {
    const labels = {
      'bid_created': 'Nouvelle offre',
      'bid_accepted': 'Offre acceptée',
      'bid_rejected': 'Offre refusée',
      'parcel_status': 'Suivi du colis',
      'driver_assigned': 'Chauffeur assigné',
      'delivery_confirmed': 'Livraison confirmée',
      'message': 'Nouveau message',
      'payment': 'Paiement',
      'ad_offer_created': 'Offre sur annonce',
      'ad_offer_accepted': 'Offre acceptée',
      'ad_offer_rejected': 'Offre refusée',
    };
    return labels[type] ?? _humanizeKey(type);
  }

  String get priorityLabel {
    switch (priority) {
      case 'urgent':
        return 'Urgente';
      case 'high':
        return 'Importante';
      case 'low':
        return 'Faible';
      default:
        return 'Normale';
    }
  }

  String get fullDate => createdAt == null
      ? 'Date non disponible'
      : DateFormat("EEEE d MMMM yyyy 'à' HH:mm", 'fr_FR').format(createdAt!);

  String? get relatedRoute {
    if (parcelId != null && parcelId!.isNotEmpty) {
      return '/parcel/${Uri.encodeComponent(parcelId!)}';
    }
    if (advertisementId != null && advertisementId!.isNotEmpty) {
      return '/advertisement/${Uri.encodeComponent(advertisementId!)}';
    }
    return null;
  }

  String? get relatedActionLabel {
    if (parcelId != null && parcelId!.isNotEmpty) return 'Voir le colis';
    if (advertisementId != null && advertisementId!.isNotEmpty) {
      return 'Voir l’annonce';
    }
    return null;
  }

  List<_NotificationDetail> get details {
    final details = <_NotificationDetail>[
      _NotificationDetail(
        icon: Icons.schedule_rounded,
        label: 'Reçue le',
        value: fullDate,
      ),
      if (senderName != null && senderName!.trim().isNotEmpty)
        _NotificationDetail(
          icon: Icons.person_outline_rounded,
          label: 'Expéditeur',
          value: senderName!.trim(),
        ),
    ];

    // Les producteurs de notifications enrichissent librement le champ JSON
    // `data`. Cette normalisation rend chaque information lisible sans perdre
    // les références nécessaires au support ou au suivi.
    final mergedData = <String, dynamic>{
      if (parcelId != null && !data.containsKey('parcelId'))
        'parcelId': parcelId,
      if (bidId != null && !data.containsKey('bidId')) 'bidId': bidId,
      ...data,
    };
    for (final entry in mergedData.entries) {
      if (entry.value == null || entry.value.toString().trim().isEmpty)
        continue;
      details.add(
        _NotificationDetail(
          icon: _iconForDetail(entry.key),
          label: _labelForDetail(entry.key),
          value: _formatDetailValue(entry.key, entry.value),
        ),
      );
    }
    return details;
  }

  static IconData _iconForDetail(String key) {
    final normalized = key.toLowerCase();
    if (normalized.contains('amount') ||
        normalized.contains('price') ||
        normalized.contains('earning') ||
        normalized.contains('commission')) {
      return Icons.payments_outlined;
    }
    if (normalized.contains('status')) return Icons.flag_outlined;
    if (normalized.contains('tracking')) return Icons.qr_code_rounded;
    if (normalized.contains('parcel')) return Icons.inventory_2_outlined;
    if (normalized.contains('driver')) return Icons.person_outline_rounded;
    if (normalized.contains('reason')) return Icons.info_outline_rounded;
    return Icons.tag_rounded;
  }

  static String _labelForDetail(String key) {
    const labels = {
      'trackingNumber': 'Numéro de suivi',
      'parcelId': 'Référence colis',
      'bidId': 'Référence offre',
      'advertisementId': 'Référence annonce',
      'offerId': 'Référence proposition',
      'paymentId': 'Référence paiement',
      'messageId': 'Référence message',
      'driverId': 'Référence chauffeur',
      'driverName': 'Chauffeur',
      'status': 'Statut',
      'amount': 'Montant',
      'price': 'Prix proposé',
      'earning': 'Gain chauffeur',
      'commission': 'Commission',
      'gross': 'Montant brut',
      'reason': 'Motif',
      'delivered': 'Colis livré',
    };
    return labels[key] ?? _humanizeKey(key);
  }

  static String _formatDetailValue(String key, Object value) {
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }

    const moneyKeys = {
      'amount',
      'price',
      'earning',
      'commission',
      'gross',
    };
    if (moneyKeys.contains(key)) {
      final amount = num.tryParse(value.toString());
      if (amount != null) {
        return '${NumberFormat.decimalPattern('fr_FR').format(amount)} FCFA';
      }
    }

    const statuses = {
      'pending': 'En attente',
      'confirmed': 'Confirmé',
      'accepted': 'Accepté',
      'rejected': 'Refusé',
      'cancelled': 'Annulé',
      'picked_up': 'Ramassé',
      'in_transit': 'En transit',
      'arrived': 'Arrivé',
      'out_for_delivery': 'En livraison',
      'delivered': 'Livré',
      'completed': 'Terminé',
      'failed': 'Échoué',
    };
    if (key == 'status') return statuses[value.toString()] ?? value.toString();
    return value.toString();
  }

  static String _humanizeKey(String value) {
    final words = value
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .trim();
    if (words.isEmpty) return 'Information';
    return '${words[0].toUpperCase()}${words.substring(1).toLowerCase()}';
  }
}

class _NotificationDetailSheet extends StatelessWidget {
  final _NotificationItem notification;
  final VoidCallback? onOpenRelated;

  const _NotificationDetailSheet({
    required this.notification,
    this.onOpenRelated,
  });

  @override
  Widget build(BuildContext context) {
    final details = notification.details;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: notification.tone.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  notification.icon,
                  color: notification.tone.foreground,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _DetailChip(
                          label: notification.typeLabel,
                          foreground: notification.tone.foreground,
                          background: notification.tone.background,
                        ),
                        const _DetailChip(
                          label: 'Lu',
                          foreground: AppTheme.green700,
                          background: AppTheme.green50,
                          icon: Icons.done_all_rounded,
                        ),
                        if (notification.priority != 'normal')
                          _DetailChip(
                            label: notification.priorityLabel,
                            foreground: notification.priority == 'urgent'
                                ? AppTheme.red500
                                : AppTheme.amber700,
                            background: notification.priority == 'urgent'
                                ? AppTheme.red50
                                : AppTheme.amber50,
                            icon: Icons.priority_high_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      notification.title,
                      style: AppFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Fermer',
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppTheme.slate500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'MESSAGE',
            style: AppFonts.manrope(
              color: AppTheme.slate400,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(17, 15, 17, 16),
            decoration: BoxDecoration(
              color: AppTheme.slate50,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border(
                left: BorderSide(
                  color: notification.tone.foreground,
                  width: 4,
                ),
              ),
            ),
            child: SelectionArea(
              child: Text(
                notification.body.isEmpty
                    ? 'Aucun contenu supplémentaire.'
                    : notification.body,
                style: AppFonts.manrope(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'INFORMATIONS',
            style: AppFonts.manrope(
              color: AppTheme.slate400,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: Column(
              children: [
                for (var index = 0; index < details.length; index++) ...[
                  _NotificationDetailRow(
                    detail: details[index],
                  ),
                  if (index < details.length - 1)
                    const Divider(
                      height: 1,
                      indent: 48,
                      color: AppTheme.slate100,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (onOpenRelated != null && notification.relatedActionLabel != null)
            PcButton(
              notification.relatedActionLabel!,
              icon: notification.parcelId != null
                  ? Icons.inventory_2_outlined
                  : Icons.route_outlined,
              size: PcButtonSize.lg,
              block: true,
              onPressed: onOpenRelated,
            )
          else
            PcButton(
              'Fermer',
              icon: Icons.close_rounded,
              variant: PcButtonVariant.secondary,
              size: PcButtonSize.lg,
              block: true,
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  const _DetailChip({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppFonts.manrope(
              color: foreground,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationDetail {
  final IconData icon;
  final String label;
  final String value;

  const _NotificationDetail({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _NotificationDetailRow extends StatelessWidget {
  final _NotificationDetail detail;

  const _NotificationDetailRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.slate50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(detail.icon, size: 15, color: AppTheme.slate500),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              detail.label,
              style: AppFonts.manrope(
                color: AppTheme.slate500,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SelectionArea(
              child: Text(
                detail.value,
                textAlign: TextAlign.right,
                style: AppFonts.manrope(
                  color: AppTheme.textPrimary,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTone {
  final Color foreground;
  final Color background;

  const _NotificationTone({
    required this.foreground,
    required this.background,
  });

  const _NotificationTone.primary()
      : foreground = AppTheme.primary,
        background = AppTheme.primaryLight;

  const _NotificationTone.green()
      : foreground = AppTheme.green700,
        background = AppTheme.green50;

  const _NotificationTone.amber()
      : foreground = AppTheme.amber700,
        background = AppTheme.amber50;

  const _NotificationTone.red()
      : foreground = AppTheme.red500,
        background = AppTheme.red50;
}
