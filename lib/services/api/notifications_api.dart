import 'client.dart';

class NotificationsApi {
  final ApiClient client;
  NotificationsApi(this.client);

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 20}) async {
    try {
      final res = await client.dio.get('/notifications',
          queryParameters: {'limit': limit});
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final res = await client.dio.get('/notifications/unread-count');
      final data = client.handle(res);
      return client.toInt(data['unreadCount']);
    } catch (e) {
      return 0;
    }
  }

  Future<bool> markRead(String id) async {
    try {
      final res = await client.dio.patch('/notifications/$id/read');
      return client.handle(res)['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAllRead() async {
    try {
      final res = await client.dio.post('/notifications/read-all');
      return client.handle(res)['success'] == true;
    } catch (e) {
      return false;
    }
  }
}
