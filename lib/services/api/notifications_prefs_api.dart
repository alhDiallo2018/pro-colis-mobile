import 'client.dart';

class NotificationsPreferencesApi {
  final ApiClient client;
  NotificationsPreferencesApi(this.client);

  Future<List<Map<String, dynamic>>> getPreferences() async {
    try {
      final res = await client.dio.get('/notifications/preferences');
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['preferences'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<void> updatePreferences(List<Map<String, dynamic>> prefs) async {
    await client.dio.put('/notifications/preferences', data: {'preferences': prefs});
  }
}
