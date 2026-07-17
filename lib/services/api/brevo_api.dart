import 'client.dart';

class BrevoApi {
  final ApiClient client;
  BrevoApi(this.client);

  Future<Map<String, dynamic>> sendEmail(Map<String, dynamic> params) async {
    try {
      final res = await client.dio.post('/notifications/email/send', data: params);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendSms(Map<String, dynamic> params) async {
    try {
      final res = await client.dio.post('/notifications/sms/send', data: params);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> getConfig() async {
    try {
      final res = await client.dio.get('/admin/notifications/brevo-config');
      final data = client.handle(res);
      return data['config'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateConfig(Map<String, dynamic> config) async {
    try {
      final res = await client.dio.put('/admin/notifications/brevo-config', data: config);
      final data = client.handle(res);
      if (data['config'] != null) return data['config'];
      return data;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> testConnection(String email) async {
    try {
      final res = await client.dio.post('/admin/notifications/brevo-test',
          data: {'email': email});
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendBulkEmail(Map<String, dynamic> data) async {
    try {
      final res = await client.dio.post('/notifications/email/send-bulk', data: data);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
