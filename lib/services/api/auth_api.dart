import '../../models/user.dart';
import 'client.dart';

class AuthApi {
  final ApiClient client;
  AuthApi(this.client);

  Future<Map<String, dynamic>> loginWithPin(String pin, String identifier) async {
    try {
      final res = await client.dio.post('/auth/login-with-pin', data: {
        'identifier': identifier,
        'pin': pin,
      });
      final data = client.handle(res);
      if (data['accessToken'] != null) {
        await client.storage.write(key: 'token', value: data['accessToken'].toString());
      }
      if (data['refreshToken'] != null) {
        await client.storage.write(key: 'refresh_token', value: data['refreshToken'].toString());
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    try {
      final res = await client.dio.post('/auth/register', data: payload);
      final data = client.handle(res);
      final at = data['accessToken']?.toString();
      if (at != null) await client.storage.write(key: 'token', value: at);
      final rt = data['refreshToken']?.toString();
      if (rt != null) await client.storage.write(key: 'refresh_token', value: rt);
      return data;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<User> getCurrentUser() async {
    final res = await client.dio.get('/auth/me');
    final data = client.handle(res);
    if (data['user'] != null) return User.fromJson(data['user']);
    throw Exception('Utilisateur non trouvé');
  }

  Future<String?> getToken() async => client.storage.read(key: 'token');

  Future<void> setToken(String token) async =>
      client.storage.write(key: 'token', value: token);

  Future<void> clearToken() async {
    await client.storage.delete(key: 'token');
    await client.storage.delete(key: 'refresh_token');
  }
}
