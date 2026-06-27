// lib/screens/dashboard/notifications/notifications_screen.dart

// ignore_for_file: unused_local_variable, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/screens/parcel/free_parcels_screen.dart';
import 'package:procolis/screens/parcel/parcel_detail_screen.dart';
import 'package:procolis/services/api_service.dart';

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
  List<Map<String, dynamic>> _notifications = [];

  // Couleurs du thème bleu/blanc
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color backgroundColor = Color(0xFFF5F8FA);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF546E7A);

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _apiService.getNotifications();
      
      if (mounted) {
        setState(() {
          _notifications = notifications.map((n) => {
            'id': n['id']?.toString() ?? '',
            'title': n['title']?.toString() ?? 'Notification',
            'body': n['body']?.toString() ?? '',
            'type': n['type']?.toString() ?? 'info',
            'isRead': n['isRead'] == true || n['is_read'] == true,
            'createdAt': n['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
            'icon': _getNotificationIcon(n['type']?.toString() ?? 'info'),
            'color': _getNotificationColor(n['type']?.toString() ?? 'info'),
            'data': n['data'] is Map ? Map<String, dynamic>.from(n['data']) : {},
            'parcelId': n['parcelId']?.toString() ?? n['parcel_id']?.toString(),
            'bidId': n['bidId']?.toString() ?? n['bid_id']?.toString(),
            'senderId': n['senderId']?.toString() ?? n['sender_id']?.toString(),
            'senderName': n['senderName']?.toString() ?? n['sender_name']?.toString(),
            'priority': n['priority']?.toString() ?? 'normal',
          }).toList();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement notifications: $e');
      _loadMockNotifications();
    }
  }

  void _loadMockNotifications() {
    setState(() {
      _notifications = [
        {
          'id': '1',
          'title': '🚚 Connecté en tant que chauffeur',
          'body': 'Vous êtes maintenant connecté à l\'espace chauffeur PRO COLIS',
          'type': 'system',
          'isRead': false,
          'createdAt': DateTime.now().subtract(Duration(minutes: 5)).toIso8601String(),
          'icon': Icons.notifications,
          'color': primaryBlue,
          'data': {},
          'parcelId': null,
          'bidId': null,
        },
        {
          'id': '2',
          'title': '✅ Offre acceptée',
          'body': 'Votre offre de 1237 FCFA a été acceptée par Client pour le colis',
          'type': 'bid_accepted',
          'isRead': false,
          'createdAt': DateTime.now().subtract(Duration(minutes: 15)).toIso8601String(),
          'icon': Icons.check_circle,
          'color': Colors.green,
          'data': {},
          'parcelId': 'parcel123',
          'bidId': null,
        },
        {
          'id': '3',
          'title': '📦 Nouveau colis disponible',
          'body': 'Un nouveau colis est disponible dans votre secteur',
          'type': 'parcel_created',
          'isRead': true,
          'createdAt': DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
          'icon': Icons.inventory,
          'color': primaryBlue,
          'data': {},
          'parcelId': 'parcel456',
          'bidId': null,
        },
      ];
      _isLoading = false;
    });
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'bid_created':
        return Icons.gavel;
      case 'bid_accepted':
        return Icons.check_circle;
      case 'bid_rejected':
        return Icons.cancel;
      case 'parcel_status':
        return Icons.local_shipping;
      case 'parcel_created':
        return Icons.inventory;
      case 'driver_assigned':
        return Icons.delivery_dining;
      case 'delivery_confirmed':
        return Icons.task_alt;
      case 'message':
        return Icons.message;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'bid_created':
        return primaryBlue;
      case 'bid_accepted':
        return Colors.green;
      case 'bid_rejected':
        return Colors.red;
      case 'parcel_status':
        return primaryBlue;
      case 'parcel_created':
        return primaryBlue;
      case 'driver_assigned':
        return Colors.orange;
      case 'delivery_confirmed':
        return Colors.green;
      case 'message':
        return primaryBlue;
      case 'system':
        return Colors.grey;
      default:
        return primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['isRead'] == false).length;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: textPrimary,
          ),
        ),
        backgroundColor: cardColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Tout marquer comme lu',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            )
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return _NotificationCard(
                      notification: notification,
                      onTap: _onNotificationTap,
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: lightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 48,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune notification',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous serez notifié des mises à jour de vos colis',
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    try {
      await _apiService.markAllNotificationsAsRead();
      setState(() {
        for (var notification in _notifications) {
          notification['isRead'] = true;
        }
      });
      if (widget.onNotificationsRead != null) {
        widget.onNotificationsRead!();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Toutes les notifications ont été marquées comme lues'),
            backgroundColor: primaryBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur marquer toutes comme lues: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _apiService.markNotificationAsRead(notificationId);
    } catch (e) {
      debugPrint('❌ Erreur marquer notification comme lue: $e');
    }
  }

  void _onNotificationTap(BuildContext context, Map<String, dynamic> notification) {
    // Marquer comme lu localement
    if (notification['isRead'] == false) {
      setState(() {
        notification['isRead'] = true;
      });
      _markAsRead(notification['id']);
      
      if (widget.onNotificationsRead != null) {
        widget.onNotificationsRead!();
      }
    }

    final type = notification['type']?.toString() ?? '';
    final parcelId = notification['parcelId']?.toString();

    switch (type) {
      case 'bid_created':
      case 'bid_accepted':
      case 'bid_rejected':
        if (parcelId != null && parcelId.isNotEmpty) {
          _navigateToParcelBids(context, parcelId);
        } else {
          _navigateToFreeParcels(context);
        }
        break;
      case 'parcel_status':
      case 'parcel_created':
      case 'driver_assigned':
      case 'delivery_confirmed':
        if (parcelId != null && parcelId.isNotEmpty) {
          _navigateToParcelDetail(context, parcelId);
        } else {
          _navigateToFreeParcels(context);
        }
        break;
      case 'message':
        _navigateToMessages(context);
        break;
      default:
        if (parcelId != null && parcelId.isNotEmpty) {
          _navigateToParcelDetail(context, parcelId);
        } else {
          _navigateToFreeParcels(context);
        }
        break;
    }
  }

  void _navigateToParcelDetail(BuildContext context, String parcelId) async {
    try {
      final parcel = await _apiService.getParcelById(parcelId);
      
      if (parcel != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParcelDetailScreen(parcel: parcel),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Colis non trouvé'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement du colis: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _navigateToParcelBids(BuildContext context, String parcelId) async {
    try {
      final parcel = await _apiService.getParcelById(parcelId);
      
      if (parcel != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParcelDetailScreen(parcel: parcel),
          ),
        );
      } else if (context.mounted) {
        _navigateToFreeParcels(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _navigateToFreeParcels(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FreeParcelsScreen(),
      ),
    );
  }

  void _navigateToMessages(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Messages - Fonctionnalité à venir'),
        duration: const Duration(seconds: 2),
        backgroundColor: primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final void Function(BuildContext, Map<String, dynamic>) onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  // Couleurs du thème bleu/blanc
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF546E7A);

  @override
  Widget build(BuildContext context) {
    final isRead = notification['isRead'] == true;
    final color = notification['color'] as Color;
    final icon = notification['icon'] as IconData;

    return GestureDetector(
      onTap: () => onTap(context, notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? cardColor : lightBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? Colors.grey.shade200 : primaryBlue.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'],
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                            fontSize: 14,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['body'],
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(notification['createdAt']),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Récemment';
    
    try {
      DateTime date;
      if (dateValue is DateTime) {
        date = dateValue;
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Récemment';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'À l\'instant';
          }
          return 'Il y a ${difference.inMinutes} min';
        }
        return 'Il y a ${difference.inHours} h';
      } else if (difference.inDays == 1) {
        return 'Hier';
      } else if (difference.inDays < 7) {
        return 'Il y a ${difference.inDays} jours';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return 'Il y a $weeks semaine${weeks > 1 ? 's' : ''}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Récemment';
    }
  }
}