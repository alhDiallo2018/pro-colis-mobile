// lib/providers/notification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/models/notification.dart';
import 'package:procolis/services/api_service.dart';

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});

class NotificationState {
  final List<Notification> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    List<Notification>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  int get total => notifications.length;
  List<Notification> get unread =>
      notifications.where((n) => !n.isRead).toList();
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final ApiService _apiService = ApiService();

  NotificationNotifier() : super(NotificationState());

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final notificationsData = await _apiService.getNotifications(limit: 50);
      final notifications =
          notificationsData.map((n) => Notification.fromJson(n)).toList();
      final unreadCount = await _apiService.getUnreadNotificationsCount();
      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
        unreadCount: unreadCount,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final success = await _apiService.markNotificationAsRead(notificationId);
    if (success) {
      final notifications = state.notifications.map((n) {
        if (n.id == notificationId) return n.markAsRead();
        return n;
      }).toList();
      state = state.copyWith(
        notifications: notifications,
        unreadCount: (state.unreadCount - 1).clamp(0, 99999),
      );
    }
  }

  Future<void> markAllAsRead() async {
    final success = await _apiService.markAllNotificationsAsRead();
    if (success) {
      final notifications =
          state.notifications.map((n) => n.markAsRead()).toList();
      state = state.copyWith(
        notifications: notifications,
        unreadCount: 0,
      );
    }
  }

  Future<void> refreshNotifications() async {
    await loadNotifications();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}
