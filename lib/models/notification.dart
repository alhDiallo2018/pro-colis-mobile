// lib/models/notification.dart
import 'package:flutter/material.dart';

/// Vocabulaire réellement persisté par l'API.
///
/// Les métadonnées visuelles sont regroupées ici pour que toute nouvelle valeur
/// de transport soit ajoutée une seule fois, sans multiplier les `switch`
/// divergents entre les écrans.
enum NotificationType {
  // Offres et enchères.
  bidCreated('bid_created', 'Nouvelle offre', Icons.gavel, Colors.purple),
  bidAccepted(
      'bid_accepted', 'Offre acceptée', Icons.check_circle, Colors.green),
  adOffer('ad_offer', 'Nouvelle offre', Icons.local_offer, Colors.purple),
  adOfferAccepted(
      'ad_offer_accepted', 'Offre acceptée', Icons.check_circle, Colors.green),
  adOfferRejected(
      'ad_offer_rejected', 'Offre refusée', Icons.cancel, Colors.red),

  // Colis et livraisons.
  parcelDelivered(
      'parcel_delivered', 'Colis livré', Icons.inventory_2, Colors.green),
  driverAssigned('driver_assigned', 'Chauffeur assigné', Icons.delivery_dining,
      Colors.orange),
  deliveryCompleted(
      'delivery_completed', 'Livraison terminée', Icons.task_alt, Colors.green),
  deliveryPaid('delivery_paid', 'Livraison payée', Icons.paid, Colors.green),

  // Paiements.
  paymentConfirmed(
      'payment_confirmed', 'Paiement confirmé', Icons.verified, Colors.green),
  paymentCash(
      'payment_cash', 'Paiement en espèces', Icons.payments, Colors.teal),

  // Messages, assistance et sécurité.
  message('message', 'Nouveau message', Icons.message, Colors.indigo),
  supportReply(
      'support_reply', 'Réponse du support', Icons.support_agent, Colors.blue),
  pinReset('pin_reset', 'Code PIN réinitialisé', Icons.lock_reset, Colors.blue),

  // Portefeuille, commissions et score.
  deposit('deposit', 'Dépôt', Icons.account_balance_wallet, Colors.green),
  commission('commission', 'Commission', Icons.percent, Colors.orange),
  commissionPaid(
      'commission_paid', 'Commission payée', Icons.paid, Colors.green),
  commissionDeduction('commission_deduction', 'Commission prélevée',
      Icons.remove_circle, Colors.orange),
  commitmentFee('commitment_fee', 'Frais d’engagement', Icons.receipt_long,
      Colors.orange),
  commitmentRefund('commitment_refund', 'Frais remboursés',
      Icons.currency_exchange, Colors.green),
  purchase('purchase', 'Achat', Icons.shopping_bag, Colors.orange),
  refund('refund', 'Remboursement', Icons.currency_exchange, Colors.green),
  scoreCredited('score_credited', 'Points crédités', Icons.stars, Colors.amber),
  walletRecharged('wallet_recharged', 'Portefeuille rechargé', Icons.add_card,
      Colors.green),
  walletDebited(
      'wallet_debited', 'Portefeuille débité', Icons.money_off, Colors.orange),

  // Retraits.
  withdrawal('withdrawal', 'Retrait', Icons.account_balance, Colors.blue),
  withdrawalRequested(
      'withdrawal_requested', 'Retrait demandé', Icons.schedule, Colors.orange),
  withdrawalCompleted('withdrawal_completed', 'Retrait effectué',
      Icons.check_circle, Colors.green),
  withdrawalFailed(
      'withdrawal_failed', 'Retrait échoué', Icons.error, Colors.red),
  withdrawalCancelled(
      'withdrawal_cancelled', 'Retrait annulé', Icons.cancel, Colors.red),

  // Actions administratives.
  adminCredit(
      'admin_credit', 'Crédit administrateur', Icons.add_circle, Colors.green),
  adminDebit(
      'admin_debit', 'Débit administrateur', Icons.remove_circle, Colors.red),
  adminDriverCredited('admin_driver_credited', 'Chauffeur crédité',
      Icons.account_balance_wallet, Colors.green),
  adminPaymentConfirmed('admin_payment_confirmed', 'Paiement validé',
      Icons.verified_user, Colors.green),

  // Valeurs historiques encore présentes dans certains caches mobiles.
  bidRejected('bid_rejected', 'Offre refusée', Icons.cancel, Colors.red),
  parcelStatus(
      'parcel_status', 'Mise à jour colis', Icons.local_shipping, Colors.blue),
  parcelCreated(
      'parcel_created', 'Nouveau colis', Icons.inventory, Colors.teal),
  deliveryConfirmed('delivery_confirmed', 'Livraison confirmée', Icons.task_alt,
      Colors.green),
  system('system', 'Système', Icons.settings, Colors.grey),
  info('info', 'Notification', Icons.notifications, Colors.grey);

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const NotificationType(this.value, this.label, this.icon, this.color);

  static NotificationType fromString(String value) {
    final normalized = value.trim().toLowerCase();
    return NotificationType.values.firstWhere(
      (type) => type.value == normalized,
      orElse: () => NotificationType.info,
    );
  }
}

extension NotificationTypeParser on String {
  NotificationType toNotificationType() => NotificationType.fromString(this);
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
      senderName:
          json['sender_name']?.toString() ?? json['senderName']?.toString(),
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
        'userId': userId,
        'parcelId': parcelId,
        'bidId': bidId,
        'senderId': senderId,
        'senderName': senderName,
        'type': type.value,
        'title': title,
        'body': body,
        'data': data,
        'isRead': isRead,
        'priority': priority.value,
        'createdAt': createdAt.toIso8601String(),
        'readAt': readAt?.toIso8601String(),
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
