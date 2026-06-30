// lib/models/notification.dart
import 'package:flutter/material.dart';

enum NotificationType {
  bidCreated,
  bidAccepted,
  bidRejected,
  parcelStatus,
  parcelCreated,
  driverAssigned,
  deliveryConfirmed,
  message,
  system,
  info,
}

extension NotificationTypeExtension on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.bidCreated:
        return 'bid_created';
      case NotificationType.bidAccepted:
        return 'bid_accepted';
      case NotificationType.bidRejected:
        return 'bid_rejected';
      case NotificationType.parcelStatus:
        return 'parcel_status';
      case NotificationType.parcelCreated:
        return 'parcel_created';
      case NotificationType.driverAssigned:
        return 'driver_assigned';
      case NotificationType.deliveryConfirmed:
        return 'delivery_confirmed';
      case NotificationType.message:
        return 'message';
      case NotificationType.system:
        return 'system';
      case NotificationType.info:
        return 'info';
    }
  }

  String get label {
    switch (this) {
      case NotificationType.bidCreated:
        return '💰 Nouvelle offre';
      case NotificationType.bidAccepted:
        return '✅ Offre acceptée';
      case NotificationType.bidRejected:
        return '❌ Offre refusée';
      case NotificationType.parcelStatus:
        return '📦 Mise à jour colis';
      case NotificationType.parcelCreated:
        return '📦 Nouveau colis';
      case NotificationType.driverAssigned:
        return '🚚 Chauffeur assigné';
      case NotificationType.deliveryConfirmed:
        return '✅ Livraison confirmée';
      case NotificationType.message:
        return '💬 Nouveau message';
      case NotificationType.system:
        return '⚙️ Système';
      default:
        return '🔔 Notification';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.bidCreated:
        return Icons.gavel;
      case NotificationType.bidAccepted:
        return Icons.check_circle;
      case NotificationType.bidRejected:
        return Icons.cancel;
      case NotificationType.parcelStatus:
        return Icons.local_shipping;
      case NotificationType.parcelCreated:
        return Icons.inventory;
      case NotificationType.driverAssigned:
        return Icons.delivery_dining;
      case NotificationType.deliveryConfirmed:
        return Icons.task_alt;
      case NotificationType.message:
        return Icons.message;
      case NotificationType.system:
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.bidCreated:
        return Colors.purple;
      case NotificationType.bidAccepted:
        return Colors.green;
      case NotificationType.bidRejected:
        return Colors.red;
      case NotificationType.parcelStatus:
        return Colors.blue;
      case NotificationType.parcelCreated:
        return Colors.teal;
      case NotificationType.driverAssigned:
        return Colors.orange;
      case NotificationType.deliveryConfirmed:
        return Colors.green;
      case NotificationType.message:
        return Colors.indigo;
      case NotificationType.system:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

// ✅ CORRECTION: Extension sur String pour parser NotificationType
extension NotificationTypeParser on String {
  NotificationType toNotificationType() {
    switch (this) {
      case 'bid_created':
        return NotificationType.bidCreated;
      case 'bid_accepted':
        return NotificationType.bidAccepted;
      case 'bid_rejected':
        return NotificationType.bidRejected;
      case 'parcel_status':
        return NotificationType.parcelStatus;
      case 'parcel_created':
        return NotificationType.parcelCreated;
      case 'driver_assigned':
        return NotificationType.driverAssigned;
      case 'delivery_confirmed':
        return NotificationType.deliveryConfirmed;
      case 'message':
        return NotificationType.message;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.info;
    }
  }
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

extension NotificationPriorityExtension on NotificationPriority {
  String get value {
    switch (this) {
      case NotificationPriority.low:
        return 'low';
      case NotificationPriority.normal:
        return 'normal';
      case NotificationPriority.high:
        return 'high';
      case NotificationPriority.urgent:
        return 'urgent';
    }
  }
}

// ✅ CORRECTION: Extension sur String pour parser NotificationPriority
extension NotificationPriorityParser on String {
  NotificationPriority toNotificationPriority() {
    switch (this) {
      case 'low':
        return NotificationPriority.low;
      case 'normal':
        return NotificationPriority.normal;
      case 'high':
        return NotificationPriority.high;
      case 'urgent':
        return NotificationPriority.urgent;
      default:
        return NotificationPriority.normal;
    }
  }
}

class Notification {
  final String id;
  final String userId;
  final String? parcelId;
  final String? bidId;
  final String? senderId;
  final String? senderName;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final NotificationPriority priority;
  final DateTime createdAt;
  final DateTime? readAt;

  Notification({
    required this.id,
    required this.userId,
    this.parcelId,
    this.bidId,
    this.senderId,
    this.senderName,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.isRead = false,
    this.priority = NotificationPriority.normal,
    required this.createdAt,
    this.readAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      parcelId: json['parcel_id']?.toString() ?? json['parcelId']?.toString(),
      bidId: json['bid_id']?.toString() ?? json['bidId']?.toString(),
      senderId: json['sender_id']?.toString() ?? json['senderId']?.toString(),
      senderName: json['sender_name']?.toString() ?? json['senderName']?.toString(),
      // ✅ CORRECTION: Utilisation de toNotificationType() sur String
      type: json['type'] != null
          ? json['type'].toString().toNotificationType()
          : NotificationType.info,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {},
      isRead: json['is_read'] == true || json['isRead'] == true,
      // ✅ CORRECTION: Utilisation de toNotificationPriority() sur String
      priority: json['priority'] != null
          ? json['priority'].toString().toNotificationPriority()
          : NotificationPriority.normal,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'].toString())
              : DateTime.now()),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'].toString())
          : (json['readAt'] != null
              ? DateTime.parse(json['readAt'].toString())
              : null),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'parcel_id': parcelId,
    'bid_id': bidId,
    'sender_id': senderId,
    'sender_name': senderName,
    'type': type.value,
    'title': title,
    'body': body,
    'data': data,
    'is_read': isRead,
    'priority': priority.value,
    'created_at': createdAt.toIso8601String(),
    'read_at': readAt?.toIso8601String(),
  };

  // Propriétés calculées
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

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
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a $months mois';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Il y a $years an${years > 1 ? 's' : ''}';
    }
  }

  String get formattedTime {
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDateTime {
    return '$formattedDate à $formattedTime';
  }

  bool get isUrgent => priority == NotificationPriority.urgent;
  bool get isHighPriority =>
      priority == NotificationPriority.high ||
      priority == NotificationPriority.urgent;

  Notification copyWith({
    String? id,
    String? userId,
    String? parcelId,
    String? bidId,
    String? senderId,
    String? senderName,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    NotificationPriority? priority,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      parcelId: parcelId ?? this.parcelId,
      bidId: bidId ?? this.bidId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  Notification markAsRead() {
    return copyWith(isRead: true, readAt: DateTime.now());
  }
}

// Extension pour les listes de notifications
extension NotificationListExtension on List<Notification> {
  List<Notification> get unread => where((n) => !n.isRead).toList();
  List<Notification> get read => where((n) => n.isRead).toList();
  List<Notification> get urgent => where((n) => n.isUrgent).toList();
  List<Notification> get highPriority =>
      where((n) => n.isHighPriority).toList();

  List<Notification> filterByType(NotificationType type) {
    return where((n) => n.type == type).toList();
  }

  List<Notification> filterByParcel(String parcelId) {
    return where((n) => n.parcelId == parcelId).toList();
  }

  Map<String, List<Notification>> groupByDate() {
    final result = <String, List<Notification>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final notification in this) {
      final date = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      String key;
      if (date == today) {
        key = "Aujourd'hui";
      } else if (date == yesterday) {
        key = 'Hier';
      } else {
        key = '${date.day}/${date.month}/${date.year}';
      }

      result.putIfAbsent(key, () => []).add(notification);
    }

    return result;
  }
}