// lib/screens/dashboard/notifications/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/procolis_design_system.dart';

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
  List<_NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
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
          _notifications = _NotificationItem.mock();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _apiService.markAllNotificationsAsRead();
    } catch (error) {
      debugPrint('Erreur markAllNotificationsAsRead: $error');
    }

    if (!mounted) return;
    setState(() {
      _notifications = [
        for (final notification in _notifications)
          notification.copyWith(isRead: true),
      ];
    });
    widget.onNotificationsRead?.call();
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
      await _apiService.markNotificationAsRead(notification.id);
    } catch (error) {
      debugPrint('Erreur markNotificationAsRead: $error');
    }
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
                        onTap: () => _markAsRead(notification),
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
    return Stack(
      children: [
        ProcolisCard(
          color: notification.isRead ? AppTheme.cardColor : AppTheme.teal50,
          padding: EdgeInsets.zero,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
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
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  notification.when,
                  style: const TextStyle(
                    color: AppTheme.slate400,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!notification.isRead)
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 90, 24, 120),
      children: [
        ProcolisCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_off_rounded,
                  color: AppTheme.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Aucune notification',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vous serez notifié des offres, statuts et confirmations de livraison.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
  final bool isRead;

  const _NotificationItem({
    required this.id,
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.when,
    required this.isRead,
  });

  factory _NotificationItem.fromApi(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'info';
    return _NotificationItem(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      icon: _iconFor(type),
      tone: _toneFor(type),
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? json['message']?.toString() ?? '',
      when: _relativeTime(json['createdAt'] ?? json['created_at']),
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
      isRead: isRead ?? this.isRead,
    );
  }

  static List<_NotificationItem> mock() {
    return const [
      _NotificationItem(
        id: 'n1',
        icon: Icons.sell_rounded,
        tone: _NotificationTone.primary(),
        title: 'Nouvelle offre reçue',
        body: 'Koffi A. propose 11 000 FCFA pour PC-2M9X-7740.',
        when: '8 min',
        isRead: false,
      ),
      _NotificationItem(
        id: 'n2',
        icon: Icons.local_shipping_rounded,
        tone: _NotificationTone.green(),
        title: 'Colis en transit',
        body: 'PC-7F3K-2291 part vers Bouaké.',
        when: '1 h',
        isRead: false,
      ),
      _NotificationItem(
        id: 'n3',
        icon: Icons.account_balance_wallet_rounded,
        tone: _NotificationTone.amber(),
        title: 'Points crédités',
        body: '+150 pts pour votre dernière livraison.',
        when: '3 h',
        isRead: true,
      ),
      _NotificationItem(
        id: 'n4',
        icon: Icons.task_alt_rounded,
        tone: _NotificationTone.green(),
        title: 'Colis livré',
        body: 'PC-5J1B-3382 a été livré à San-Pédro.',
        when: 'hier',
        isRead: true,
      ),
      _NotificationItem(
        id: 'n5',
        icon: Icons.verified_rounded,
        tone: _NotificationTone.primary(),
        title: 'Compte vérifié',
        body: 'Votre identité a été confirmée. Bienvenue !',
        when: '2 j',
        isRead: true,
      ),
    ];
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'bid_created':
        return Icons.sell_rounded;
      case 'bid_accepted':
        return Icons.gavel_rounded;
      case 'parcel_status':
      case 'driver_assigned':
        return Icons.local_shipping_rounded;
      case 'delivery_confirmed':
        return Icons.task_alt_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'payment':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  static _NotificationTone _toneFor(String type) {
    switch (type) {
      case 'delivery_confirmed':
      case 'bid_accepted':
        return const _NotificationTone.green();
      case 'payment':
        return const _NotificationTone.amber();
      case 'bid_rejected':
        return const _NotificationTone.red();
      default:
        return const _NotificationTone.primary();
    }
  }

  static String _relativeTime(dynamic raw) {
    final parsed = raw == null ? null : DateTime.tryParse(raw.toString());
    if (parsed == null) return 'maintenant';

    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    return '${diff.inDays} j';
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
