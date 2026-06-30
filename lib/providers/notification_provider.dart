// lib/providers/notification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/models/notification.dart';
import 'package:procolis/services/api_service.dart';

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});

class NotificationState {
  final List<Notification> notifications;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int unreadCount;

  NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    List<Notification>? notifications,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? unreadCount,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  int get total => notifications.length;
  List<Notification> get unread => notifications.where((n) => !n.isRead).toList();
  List<Notification> get read => notifications.where((n) => n.isRead).toList();
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final ApiService _apiService = ApiService();
  int _currentOffset = 0;
  static const int _limit = 20;

  NotificationNotifier() : super(NotificationState());

  Future<void> loadNotifications({bool refresh = false}) async {
    if (refresh) {
      _currentOffset = 0;
      state = state.copyWith(notifications: [], hasMore: true);
    }

    if (!state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final notificationsData = await _apiService.getNotifications(
        limit: _limit,
        offset: _currentOffset,
      );

      final notifications = notificationsData
          .map((n) => Notification.fromJson(n))
          .toList();

      final hasMore = notifications.length == _limit;
      final allNotifications = refresh 
          ? notifications 
          : [...state.notifications, ...notifications];

      // Charger le nombre de non lues
      final unreadCount = await _apiService.getUnreadNotificationsCount();

      state = state.copyWith(
        notifications: allNotifications,
        isLoading: false,
        hasMore: hasMore,
        unreadCount: unreadCount,
      );

      _currentOffset += notifications.length;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final success = await _apiService.markNotificationAsRead(notificationId);
    if (success) {
      final notifications = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.markAsRead();
        }
        return n;
      }).toList();

      state = state.copyWith(
        notifications: notifications,
        unreadCount: state.unreadCount - 1,
      );
    }
  }

  Future<void> markAllAsRead() async {
    final success = await _apiService.markAllNotificationsAsRead();
    if (success) {
      final notifications = state.notifications.map((n) => n.markAsRead()).toList();
      state = state.copyWith(
        notifications: notifications,
        unreadCount: 0,
      );
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final success = await _apiService.deleteNotification(notificationId);
    if (success) {
      final notification = state.notifications.firstWhere((n) => n.id == notificationId);
      final notifications = state.notifications.where((n) => n.id != notificationId).toList();
      final unreadCount = notification.isRead ? state.unreadCount : state.unreadCount - 1;
      
      state = state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount > 0 ? unreadCount : 0,
      );
    }
  }

  Future<void> deleteAllNotifications() async {
    final success = await _apiService.deleteAllNotifications();
    if (success) {
      state = state.copyWith(
        notifications: [],
        unreadCount: 0,
      );
    }
  }

  Future<void> refreshNotifications() async {
    await loadNotifications(refresh: true);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}