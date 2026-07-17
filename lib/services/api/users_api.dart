import '../../models/user.dart';
import 'client.dart';

class UsersApi {
  final ApiClient client;
  UsersApi(this.client);

  Future<Map<String, dynamic>> updateProfile(String role, Map<String, dynamic> d) async {
    try {
      final endpoint = switch (role) {
        'driver' => '/driver/profile',
        'admin' => '/garage-admin/profile',
        'super_admin' => '/super-admin/profile',
        _ => '/client/profile',
      };
      final res = await client.dio.put(endpoint, data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changePin(String current, String newPin) async {
    try {
      final res = await client.dio.put('/users/pin', data: {
        'currentPin': current,
        'newPin': newPin,
      });
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
